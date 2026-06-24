//
//  MaintenanceSchedule.swift
//  Carburante
//
//  Regra genérica de "próxima manutenção" por TIPO. Lógica pura e testável.
//  Cada tipo tem dois eixos de intervalo — km e tempo (meses) — e vence pelo
//  que ocorrer primeiro. Intervalos personalizáveis por manutenção; registros
//  sem valor caem no padrão do tipo (`MaintenanceType.defaultInterval*`).
//
//  Ver PLAN/manutencao-programada.md.
//

import Foundation

/// Status calculado da próxima manutenção de um tipo. Valor puro (Sendable):
/// já traz tudo computado (sem dependência de `now`) para o struct ser estável,
/// comparável e fácil de testar.
struct MaintenanceStatus: Equatable, Identifiable {
    let type: MaintenanceType
    /// Intervalo por km em vigor (nil → não acompanhado por km).
    let intervalKm: Double?
    /// Intervalo por tempo em meses em vigor (nil → não acompanhado por tempo).
    let intervalMonths: Int?
    /// km/data da última manutenção deste tipo (âncora do cálculo).
    let lastMileage: Double
    let lastDate: Date
    /// km do hodômetro previsto para a próxima (nil quando sem eixo km).
    let dueMileage: Double?
    /// data prevista para a próxima (nil quando sem eixo tempo).
    let dueDate: Date?
    /// km restantes (negativo = além do previsto); nil quando sem eixo km.
    let kmRemaining: Double?
    /// dias restantes (negativo = atrasado); nil quando sem eixo tempo.
    let daysRemaining: Int?
    /// Progresso 0…1 rumo ao vencimento = MAIOR fração entre km e tempo (o eixo
    /// vinculante, o que está mais perto de vencer). Indicador honesto de urgência.
    let progress: Double
    /// Já passou do ponto por QUALQUER eixo acompanhado.
    let isOverdue: Bool

    var id: String { type.rawValue }

    /// km já rodados no intervalo atual (≥0); nil quando sem eixo km.
    var kmIntoInterval: Double? {
        guard let intervalKm, let kmRemaining else { return nil }
        return max(intervalKm - kmRemaining, 0)
    }

    // MARK: Apresentação (compartilhada entre Resumo e lista de Manutenções)

    /// Texto curto do que falta, pelo eixo mais próximo de vencer.
    /// Ex.: "Faltam 1.500 km", "Faltam 12 dias", "Vencida".
    var remainingShort: String {
        if isOverdue { return "Vencida" }
        if let km = kmRemaining { return "Faltam \(AppFormat.km(max(km, 0)))" }
        if let days = daysRemaining {
            if days <= 0 { return "Vence hoje" }
            return days == 1 ? "Falta 1 dia" : "Faltam \(days) dias"
        }
        return "Em dia"
    }

    /// Texto de prazo da próxima (por data quando há eixo tempo; senão por km).
    /// Ex.: "Prevista para 12/12/2026", "Próxima em 21.000 km".
    var dueDescription: String {
        if let date = dueDate {
            return isOverdue ? "Prazo: \(AppFormat.date(date))" : "Prevista para \(AppFormat.date(date))"
        }
        if let due = dueMileage { return "Próxima em \(AppFormat.km(due))" }
        return ""
    }
}

enum MaintenanceSchedule {
    /// Calcula o status da próxima manutenção de um tipo.
    /// - Retorna nil quando não há manutenção registrada (sem âncora) OU quando
    ///   nenhum dos dois eixos está configurado (nada a prever).
    static func status(
        for type: MaintenanceType,
        lastDate: Date?,
        lastMileage: Double?,
        intervalKm: Double?,
        intervalMonths: Int?,
        currentMileage: Double,
        now: Date,
        calendar: Calendar = .current
    ) -> MaintenanceStatus? {
        guard let lastDate, let lastMileage else { return nil }
        let hasKm = (intervalKm ?? 0) > 0
        let hasTime = (intervalMonths ?? 0) > 0
        guard hasKm || hasTime else { return nil }

        // Eixo km.
        var dueMileage: Double?
        var kmRemaining: Double?
        var kmFraction = 0.0
        if hasKm, let intervalKm {
            let due = lastMileage + intervalKm
            dueMileage = due
            let remaining = due - currentMileage
            kmRemaining = remaining
            kmFraction = min(max(intervalKm - remaining, 0) / intervalKm, 1)
        }

        // Eixo tempo (calendário em meses, exato).
        var dueDate: Date?
        var daysRemaining: Int?
        var timeFraction = 0.0
        if hasTime, let intervalMonths {
            let due = calendar.date(byAdding: .month, value: intervalMonths, to: lastDate) ?? lastDate
            dueDate = due
            daysRemaining = calendar.dateComponents([.day], from: now, to: due).day
            let totalDays = Double(calendar.dateComponents([.day], from: lastDate, to: due).day ?? 0)
            let elapsed = Double(calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0)
            timeFraction = totalDays > 0 ? min(max(elapsed, 0) / totalDays, 1) : 0
        }

        let overdueByKm = hasKm && (kmRemaining ?? 0) <= 0
        let overdueByTime = hasTime && (dueDate.map { now >= $0 } ?? false)

        return MaintenanceStatus(
            type: type,
            intervalKm: hasKm ? intervalKm : nil,
            intervalMonths: hasTime ? intervalMonths : nil,
            lastMileage: lastMileage,
            lastDate: lastDate,
            dueMileage: dueMileage,
            dueDate: dueDate,
            kmRemaining: kmRemaining,
            daysRemaining: daysRemaining,
            progress: max(kmFraction, timeFraction),
            isOverdue: overdueByKm || overdueByTime
        )
    }
}

extension Motorcycle {
    /// Última manutenção registrada de um tipo (por data).
    func lastService(of type: MaintenanceType) -> MaintenanceLog? {
        maintenanceLogs.filter { $0.type == type }.max { $0.date < $1.date }
    }

    /// km rodados desde a última manutenção do tipo (≥0). Nil se nunca registrada.
    func kmSinceLastService(of type: MaintenanceType) -> Double? {
        guard let last = lastService(of: type) else { return nil }
        return max(currentOdometer - last.mileage, 0)
    }

    /// Meses desde a última manutenção do tipo. Nil se nunca registrada.
    func monthsSinceLastService(
        of type: MaintenanceType, now: Date = Date(), calendar: Calendar = .current
    ) -> Int? {
        guard let last = lastService(of: type) else { return nil }
        return calendar.dateComponents([.month], from: last.date, to: now).month
    }

    /// Status da próxima manutenção de um tipo, considerando o hodômetro atual.
    func maintenanceStatus(for type: MaintenanceType, now: Date = Date()) -> MaintenanceStatus? {
        let last = lastService(of: type)
        return MaintenanceSchedule.status(
            for: type,
            lastDate: last?.date,
            lastMileage: last?.mileage,
            intervalKm: last?.effectiveIntervalKm,
            intervalMonths: last?.effectiveIntervalMonths,
            currentMileage: currentOdometer,
            now: now
        )
    }

    /// Status de TODOS os tipos AGENDÁVEIS com ≥1 manutenção, ordenados por
    /// urgência (vencidos primeiro; depois maior progresso). `.revisao` fica de
    /// fora (`isSchedulable == false`): é ação de registro, não meta — os itens
    /// que ela reinicia já aparecem aqui por conta própria. Chokepoint único:
    /// alimenta Programadas, o herói do Resumo e os lembretes.
    func maintenanceStatuses(now: Date = Date()) -> [MaintenanceStatus] {
        MaintenanceType.allCases
            .filter { $0.isSchedulable }
            .compactMap { maintenanceStatus(for: $0, now: now) }
            .sorted {
                if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
                return $0.progress > $1.progress
            }
    }

    /// A manutenção mais urgente entre todos os tipos (o card-herói do Resumo).
    func nextDueMaintenance(now: Date = Date()) -> MaintenanceStatus? {
        maintenanceStatuses(now: now).first
    }
}

/// Um lembrete planejado de manutenção (valor puro, Sendable). O
/// `NotificationService` traduz isto em `UNNotificationRequest`.
struct MaintenancePlan: Equatable {
    /// Sufixo estável do identificador (dedupe no reagendamento).
    let idSuffix: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Planeja os lembretes de manutenção. Pura e testável.
///
/// Dois eixos:
/// - DATA (determinística): aviso de aproximação (7 dias antes) + no prazo. Um
///   por tipo, naturalmente espaçados.
/// - KM (reativa): como não dá para prever quando o piloto rodará os km, ao
///   atingir ≥80% (ou vencer) agenda para a manhã seguinte. A coalescência
///   (`reactivePlan`) junta múltiplos itens em UMA notificação → anti-spam.
enum MaintenanceReminder {
    static let identifierPrefix = "maint-"
    /// Prefixo legado (lembretes só-óleo da versão anterior) — cancelado uma vez
    /// na migração para não deixar notificação órfã.
    static let legacyOilPrefix = "oil-change-"
    static let preWarningDays = 7
    static let approachingProgress = 0.8

    /// Item "em atenção" = vencido ou ≥80% do intervalo (por qualquer eixo).
    static func isAttention(_ status: MaintenanceStatus) -> Bool {
        status.isOverdue || status.progress >= approachingProgress
    }

    /// Planos por DATA de um status (pré-aviso + no prazo). Vazio se vencido
    /// (datas passadas não se agendam) ou sem eixo tempo.
    static func datePlans(
        for status: MaintenanceStatus, now: Date, calendar: Calendar = .current
    ) -> [MaintenancePlan] {
        guard !status.isOverdue, let dueDate = status.dueDate else { return [] }
        let key = status.type.identifierKey
        var out: [MaintenancePlan] = []
        if let pre = calendar.date(byAdding: .day, value: -preWarningDays, to: dueDate), pre > now {
            out.append(MaintenancePlan(
                idSuffix: "\(key)-date-pre", fireDate: pre,
                title: "\(status.type.rawValue): se aproximando",
                body: "Prevista para \(AppFormat.date(dueDate))."))
        }
        if dueDate > now {
            out.append(MaintenancePlan(
                idSuffix: "\(key)-date-due", fireDate: dueDate,
                title: "\(status.type.rawValue): prevista para hoje",
                body: dueBody(status)))
        }
        return out
    }

    /// Plano REATIVO (eixo km) coalescido: nil se ninguém em atenção; específico
    /// se exatamente 1; resumo único se ≥2 (anti-spam). Pura → testável.
    static func reactivePlan(attention: [MaintenanceStatus], morning: Date) -> MaintenancePlan? {
        guard !attention.isEmpty else { return nil }
        if attention.count == 1 {
            let s = attention[0]
            let title = s.isOverdue
                ? "\(s.type.rawValue): vencida"
                : "\(s.type.rawValue): próxima"
            let body: String
            if s.isOverdue {
                body = "Recomendada o quanto antes."
            } else if let km = s.kmRemaining {
                body = "Faltam \(AppFormat.km(max(km, 0)))."
            } else {
                body = "Revise em breve."
            }
            return MaintenancePlan(idSuffix: "\(s.type.identifierKey)-km",
                                   fireDate: morning, title: title, body: body)
        }
        return MaintenancePlan(
            idSuffix: "summary-km", fireDate: morning,
            title: "Manutenções pendentes",
            body: "\(attention.count) itens da sua moto precisam de atenção.")
    }

    /// Todos os planos para um conjunto de status (datas por tipo + 1 reativo
    /// coalescido). Reagendar a cada save mantém um só conjunto pendente.
    static func plans(
        for statuses: [MaintenanceStatus], now: Date, calendar: Calendar = .current
    ) -> [MaintenancePlan] {
        var out = statuses.flatMap { datePlans(for: $0, now: now, calendar: calendar) }
        let attention = statuses.filter(isAttention)
        if let morning = nextMorning(after: now, calendar: calendar),
           let reactive = reactivePlan(attention: attention, morning: morning) {
            out.append(reactive)
        }
        return out
    }

    /// Próxima manhã (default 9h) após `now`.
    static func nextMorning(after now: Date, hour: Int = 9, calendar: Calendar = .current) -> Date? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)
    }

    private static func dueBody(_ status: MaintenanceStatus) -> String {
        switch (status.intervalKm, status.intervalMonths) {
        case let (km?, months?):
            return "Recomendada a cada \(AppFormat.km(km)) ou \(months) meses."
        case let (km?, nil):
            return "Recomendada a cada \(AppFormat.km(km))."
        case let (nil, months?):
            return "Recomendada a cada \(months) meses."
        default:
            return "Recomendada agora."
        }
    }
}
