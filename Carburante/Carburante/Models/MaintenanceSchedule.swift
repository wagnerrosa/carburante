//
//  MaintenanceSchedule.swift
//  Carburante
//
//  Regra simples de "próxima manutenção" para o dashboard. Lógica pura,
//  testável. MVP foca na troca de óleo (item mais recorrente): a partir
//  da última troca, sugere a próxima por km OU por tempo, o que vier antes.
//
//  Intervalos padrão (não pedidos ao usuário no MVP — simplicidade):
//  3.000 km ou 180 dias. Ajustável por moto/fabricante no futuro.
//

import Foundation

struct OilChangeStatus: Equatable {
    /// km do hodômetro previsto para a próxima troca.
    let dueMileage: Double
    /// data prevista para a próxima troca.
    let dueDate: Date
    /// km restantes (negativo = atrasado) com base no hodômetro atual.
    let kmRemaining: Double
    /// já passou do ponto (por km ou por data)?
    let isOverdue: Bool

    /// km já rodados no intervalo atual (rumo aos 3.000). Saturado em ≥ 0.
    var kmIntoInterval: Double {
        max(MaintenanceSchedule.oilIntervalKm - kmRemaining, 0)
    }

    /// Progresso 0…1 rumo à próxima troca (para o anel do Fitness). Satura em 1
    /// quando vencido — o anel cheio + a cor já comunicam o estouro.
    var progress: Double {
        min(kmIntoInterval / MaintenanceSchedule.oilIntervalKm, 1)
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
            currentMileage: currentOdometer,
            now: now
        )
    }
}

enum MaintenanceSchedule {
    static let oilIntervalKm: Double = 3_000
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
        currentMileage: Double,
        now: Date
    ) -> OilChangeStatus? {
        guard let lastDate = lastOilDate, let lastKm = lastOilMileage else { return nil }

        let dueMileage = lastKm + oilIntervalKm
        let dueDate = Calendar.current.date(byAdding: .day, value: oilIntervalDays, to: lastDate) ?? lastDate
        let kmRemaining = dueMileage - currentMileage
        let overdue = kmRemaining <= 0 || now >= dueDate

        return OilChangeStatus(
            dueMileage: dueMileage,
            dueDate: dueDate,
            kmRemaining: kmRemaining,
            isOverdue: overdue
        )
    }
}
