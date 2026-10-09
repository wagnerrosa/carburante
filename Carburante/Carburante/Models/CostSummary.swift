//
//  CostSummary.swift
//  Carburante
//
//  Custos completos da moto (Premium — PLAN/premium-mvp.md §2). O resto do app
//  soma só a gasolina; aqui entram gasolina + manutenção: total por período,
//  custo real por km, manutenção por tipo, mês a mês e o ritmo do ano.
//  Funções puras (recebem `now`/`calendar`) → testáveis. Tela: `CostsView`.
//
//  Registro histórico entra (é continuidade, como o consumo — ver
//  `EventProvenance`). km do período = odômetro interpolado entre leituras
//  (`ConsumptionCalculator.spreadDistance`), a mesma conta do Resumo.
//

import Foundation

/// Uma manutenção com valor (as sem valor não entram nos custos).
struct MaintenanceCost {
    let date: Date
    let amount: Double
    /// Rótulo de tela do tipo ("Troca de óleo", "Pneu traseiro"…).
    let label: String
}

struct CostSummary: Equatable {
    struct TypeTotal: Equatable {
        let label: String
        let amount: Double
    }

    let fuel: Double
    let maintenance: Double
    /// km rodados no período.
    let distance: Double
    /// Manutenção por tipo, maior valor primeiro.
    let maintenanceByType: [TypeTotal]

    var total: Double { fuel + maintenance }
    /// Custo real por km (gasolina + manutenção). nil sem km no período.
    var costPerKm: Double? { distance > 0 ? total / distance : nil }
    /// Só gasolina — o mesmo número do Resumo, para comparar.
    var fuelCostPerKm: Double? { distance > 0 ? fuel / distance : nil }

    static let empty = CostSummary(fuel: 0, maintenance: 0, distance: 0, maintenanceByType: [])
}

/// Um mês do gráfico: gasolina e manutenção separadas (barras empilhadas).
struct MonthCost: Equatable {
    let month: Date
    let fuel: Double
    let maintenance: Double
}

/// Ritmo do ano corrente: projeção e comparação com o mesmo período do ano
/// anterior. Cada parte é nil quando não há base para ela.
struct YearPace: Equatable {
    let soFar: Double
    /// Total do ano no ritmo atual. nil antes de 30 dias do ano ou sem gasto.
    let projection: Double?
    /// Total do ano anterior até o mesmo dia. nil sem gasto naquele período ou
    /// sem registro desde o começo dele (comparação injusta).
    let previousSamePeriod: Double?

    /// Variação contra o ano anterior (0,12 = 12% a mais).
    var change: Double? {
        previousSamePeriod.map { (soFar - $0) / $0 }
    }
}

enum CostCalculator {

    /// Totais de um período. Intervalo semiaberto: [início, fim).
    static func summary(fuel: [FuelEntry], maintenance: [MaintenanceCost],
                        in interval: DateInterval) -> CostSummary {
        let fuelTotal = fuel.filter { inside(interval, $0.date) }.reduce(0) { $0 + $1.totalCost }
        var byType: [String: Double] = [:]
        for m in maintenance where inside(interval, m.date) {
            byType[m.label, default: 0] += m.amount
        }
        let types = byType
            .map { CostSummary.TypeTotal(label: $0.key, amount: $0.value) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.label < $1.label }
        let distance = ConsumptionCalculator.spreadDistance(from: fuel, into: [interval]).first ?? 0
        return CostSummary(fuel: fuelTotal,
                           maintenance: types.reduce(0) { $0 + $1.amount },
                           distance: distance,
                           maintenanceByType: types)
    }

    /// Gasolina e manutenção por mês-civil, dos `monthCount` meses até `now`
    /// (inclusive), mais antigo → mais novo. Meses vazios entram com 0.
    static func monthly(fuel: [FuelEntry], maintenance: [MaintenanceCost],
                        monthCount: Int = 12, now: Date,
                        calendar: Calendar = .current) -> [MonthCost] {
        guard monthCount > 0 else { return [] }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let months: [Date] = (0..<monthCount).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }
        var fuelBy = Dictionary(uniqueKeysWithValues: months.map { ($0, 0.0) })
        var maintenanceBy = fuelBy
        for e in fuel {
            guard let m = calendar.dateInterval(of: .month, for: e.date)?.start,
                  fuelBy[m] != nil else { continue }
            fuelBy[m, default: 0] += e.totalCost
        }
        for c in maintenance {
            guard let m = calendar.dateInterval(of: .month, for: c.date)?.start,
                  maintenanceBy[m] != nil else { continue }
            maintenanceBy[m, default: 0] += c.amount
        }
        return months.map { MonthCost(month: $0, fuel: fuelBy[$0] ?? 0, maintenance: maintenanceBy[$0] ?? 0) }
    }

    /// Ritmo do ano corrente até `now`.
    static func yearPace(fuel: [FuelEntry], maintenance: [MaintenanceCost],
                         now: Date, calendar: Calendar = .current) -> YearPace {
        guard let year = calendar.dateInterval(of: .year, for: now) else {
            return YearPace(soFar: 0, projection: nil, previousSamePeriod: nil)
        }
        let soFar = summary(fuel: fuel, maintenance: maintenance,
                            in: DateInterval(start: year.start, end: max(now, year.start))).total
        let elapsed = now.timeIntervalSince(year.start)
        let projection: Double? = elapsed >= 30 * 86_400 && soFar > 0
            ? soFar * year.duration / elapsed
            : nil

        // Só compara se já havia registro desde o começo do período anterior
        // (31 dias de folga): moto cadastrada no fim do ano passado daria
        // "+1.234%" contra meio mês de dados — número que não diz nada.
        var previous: Double?
        let firstRecord = (fuel.map(\.date) + maintenance.map(\.date)).min()
        if let prevStart = calendar.date(byAdding: .year, value: -1, to: year.start),
           let prevEnd = calendar.date(byAdding: .year, value: -1, to: now), prevEnd >= prevStart,
           let firstRecord, firstRecord <= prevStart.addingTimeInterval(31 * 86_400) {
            let total = summary(fuel: fuel, maintenance: maintenance,
                                in: DateInterval(start: prevStart, end: prevEnd)).total
            previous = total > 0 ? total : nil
        }
        return YearPace(soFar: soFar, projection: projection, previousSamePeriod: previous)
    }

    /// Do primeiro registro com valor até `now` (período "Tudo"). nil sem registro.
    static func allTimeInterval(fuel: [FuelEntry], maintenance: [MaintenanceCost],
                                now: Date) -> DateInterval? {
        let first = (fuel.map(\.date) + maintenance.map(\.date)).min()
        guard let first else { return nil }
        // +1 s: o intervalo é semiaberto e o registro feito agora tem que entrar.
        return DateInterval(start: min(first, now), end: now.addingTimeInterval(1))
    }

    /// Média por mês-civil desde `start` (contando o mês de início e o atual).
    static func monthlyAverage(total: Double, since start: Date, now: Date,
                               calendar: Calendar = .current) -> Double {
        let from = calendar.dateInterval(of: .month, for: start)?.start ?? start
        let to = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let months = (calendar.dateComponents([.month], from: from, to: to).month ?? 0) + 1
        return total / Double(max(months, 1))
    }

    private static func inside(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}

extension Motorcycle {
    /// Manutenções com valor, no formato dos custos completos. Chave de tipo
    /// desconhecida (build mais novo) sai crua, nunca vira "Outro".
    var maintenanceCosts: [MaintenanceCost] {
        activeMaintenanceLogs.filter { $0.cost > 0 }.map {
            MaintenanceCost(date: $0.date, amount: $0.cost,
                            label: MaintenanceType(rawValue: $0.typeRaw) != nil ? $0.displayName : $0.typeRaw)
        }
    }
}
