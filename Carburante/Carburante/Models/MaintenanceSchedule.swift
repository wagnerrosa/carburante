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
