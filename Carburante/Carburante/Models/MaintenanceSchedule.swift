//
//  MaintenanceSchedule.swift
//  Carburante
//
//  Regra simples de "próxima manutenção" para o dashboard. Lógica pura,
//  testável. MVP foca na troca de óleo (item mais recorrente): a partir
//  da última troca, sugere a próxima por km OU por tempo, o que vier antes.
//
//  Intervalo padrão: 3.000 km ou 180 dias. O intervalo em km pode ser
//  personalizado em cada troca; registros antigos usam o padrão.
//

import Foundation

struct OilChangeStatus: Equatable {
    /// Intervalo em km escolhido na última troca.
    let intervalKm: Double
    /// km do hodômetro previsto para a próxima troca.
    let dueMileage: Double
    /// data prevista para a próxima troca.
    let dueDate: Date
    /// km restantes (negativo = atrasado) com base no hodômetro atual.
    let kmRemaining: Double
    /// já passou do ponto (por km ou por data)?
    let isOverdue: Bool

    /// km já rodados no intervalo atual. Saturado em ≥ 0.
    var kmIntoInterval: Double {
        max(intervalKm - kmRemaining, 0)
    }

    /// Progresso de distância 0…1 rumo à próxima troca. Vencimento por data
    /// não altera essa proporção: a barra continua representando km rodados.
    var progress: Double {
        min(kmIntoInterval / intervalKm, 1)
    }
}

extension Motorcycle {
    /// Última troca de óleo registrada (por data).
    var latestOilChange: MaintenanceLog? {
        maintenanceLogs.filter { $0.type == .oleo }.max { $0.date < $1.date }
    }

    /// Status da próxima troca de óleo, considerando o hodômetro atual.
    func oilChangeStatus(now: Date = Date()) -> OilChangeStatus? {
        let last = latestOilChange
        return MaintenanceSchedule.oilChangeStatus(
            lastOilDate: last?.date,
            lastOilMileage: last?.mileage,
            intervalKm: last?.effectiveOilChangeIntervalKm ?? MaintenanceSchedule.defaultOilIntervalKm,
            currentMileage: currentOdometer,
            now: now
        )
    }
}

/// Um lembrete planejado de troca de óleo (valor puro, Sendable). O
/// `NotificationService` traduz isto em `UNNotificationRequest`.
struct OilReminderPlan: Equatable {
    /// Sufixo estável do identificador (dedupe no reagendamento).
    let idSuffix: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Planeja os lembretes de troca de óleo a partir do `OilChangeStatus`.
/// Duas dimensões: por DATA (determinística → agenda no prazo e antes dele) e
/// por KM (reativa → como não dá para prever quando o piloto rodará os km, ao
/// cruzar 80% agenda um lembrete para a próxima manhã). Pura e testável.
enum OilChangeReminder {
    static let identifierPrefix = "oil-change-"
    /// Antecedência do aviso "se aproximando" (por data).
    static let preWarningDays = 7
    /// Limiar de progresso (km) que dispara o aviso de aproximação.
    static let approachingProgress = 0.8

    static func plans(
        for status: OilChangeStatus?,
        now: Date,
        calendar: Calendar = .current
    ) -> [OilReminderPlan] {
        guard let status else { return [] }
        var out: [OilReminderPlan] = []

        // Por DATA — só enquanto não vencido (datas passadas não se agendam).
        if !status.isOverdue {
            if let pre = calendar.date(byAdding: .day, value: -preWarningDays, to: status.dueDate),
               pre > now {
                out.append(OilReminderPlan(
                    idSuffix: "date-pre", fireDate: pre,
                    title: "Troca de óleo se aproximando",
                    body: "Prevista para \(AppFormat.date(status.dueDate))."))
            }
            if status.dueDate > now {
                out.append(OilReminderPlan(
                    idSuffix: "date-due", fireDate: status.dueDate,
                    title: "Troca de óleo prevista para hoje",
                    body: "Recomendada a cada \(AppFormat.km(status.intervalKm)) ou \(MaintenanceSchedule.oilIntervalDays) dias."))
            }
        }

        // Por KM — reativo. Ao atingir ≥80% (ou vencido), agenda p/ a manhã
        // seguinte. O reagendamento a cada abastecimento mantém um só pendente.
        if status.progress >= approachingProgress || status.isOverdue {
            if let morning = nextMorning(after: now, calendar: calendar) {
                let title = status.isOverdue ? "Troca de óleo vencida" : "Troca de óleo próxima"
                let body = status.isOverdue
                    ? "Recomendada o quanto antes."
                    : "Faltam \(AppFormat.km(max(status.kmRemaining, 0)))."
                out.append(OilReminderPlan(idSuffix: "km", fireDate: morning, title: title, body: body))
            }
        }
        return out
    }

    /// Próxima manhã (default 9h) após `now`.
    static func nextMorning(after now: Date, hour: Int = 9, calendar: Calendar = .current) -> Date? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)
    }
}

enum MaintenanceSchedule {
    static let defaultOilIntervalKm: Double = 3_000
    static let oilIntervalDays: Int = 180

    /// Calcula o status da próxima troca de óleo.
    /// - Parameters:
    ///   - lastOilDate: data da última troca de óleo (nil se nunca).
    ///   - lastOilMileage: hodômetro na última troca (nil se nunca).
    ///   - currentMileage: hodômetro atual da moto.
    ///   - now: data de referência (injeção p/ teste).
    /// Retorna nil quando não há troca de óleo registrada (nada a prever).
    static func oilChangeStatus(
        lastOilDate: Date?,
        lastOilMileage: Double?,
        intervalKm: Double = defaultOilIntervalKm,
        currentMileage: Double,
        now: Date
    ) -> OilChangeStatus? {
        guard let lastDate = lastOilDate, let lastKm = lastOilMileage, intervalKm > 0 else { return nil }

        let dueMileage = lastKm + intervalKm
        let dueDate = Calendar.current.date(byAdding: .day, value: oilIntervalDays, to: lastDate) ?? lastDate
        let kmRemaining = dueMileage - currentMileage
        let overdue = kmRemaining <= 0 || now >= dueDate

        return OilChangeStatus(
            intervalKm: intervalKm,
            dueMileage: dueMileage,
            dueDate: dueDate,
            kmRemaining: kmRemaining,
            isOverdue: overdue
        )
    }
}
