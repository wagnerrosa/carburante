//
//  CostSummary.swift
//  Carburante
//
//  Custos completos da moto (Premium — PLAN/premium-mvp.md §2). O resto do app
//  soma só a gasolina; aqui entram gasolina + manutenção + outras despesas
//  (IPVA, seguro, pedágio… — `Expense`, Custos v2): total por período, custo
//  real por km, gasto por tipo, mês a mês e o ritmo do ano.
//  Funções puras (recebem `now`/`calendar`) → testáveis. Tela: `CostsView`.
//
//  Registro histórico entra (é continuidade, como o consumo — ver
//  `EventProvenance`). km do período = odômetro interpolado entre leituras
//  (`ConsumptionCalculator.spreadDistance`), a mesma conta do Resumo.
//

import Foundation

/// Um gasto com valor e rótulo de tela — uma manutenção ("Troca de óleo",
/// "Pneu traseiro"…) ou uma outra despesa ("IPVA", "Seguro"…). Os sem valor
/// não entram nos custos.
struct CostItem {
    let date: Date
    let amount: Double
    let label: String
}

struct CostSummary: Equatable {
    struct TypeTotal: Equatable {
        let label: String
        let amount: Double
    }

    let fuel: Double
    let maintenance: Double
    /// Outras despesas (IPVA, seguro, pedágio…).
    let other: Double
    /// km rodados no período.
    let distance: Double
    /// Manutenção por tipo, maior valor primeiro.
    let maintenanceByType: [TypeTotal]
    /// Outras despesas por categoria, maior valor primeiro.
    let otherByCategory: [TypeTotal]

    var total: Double { fuel + maintenance + other }
    /// Custo real por km (tudo o que a moto custou). nil sem km no período.
    var costPerKm: Double? { distance > 0 ? total / distance : nil }
    /// Só gasolina — o mesmo número do Resumo, para comparar.
    var fuelCostPerKm: Double? { distance > 0 ? fuel / distance : nil }

    static let empty = CostSummary(fuel: 0, maintenance: 0, other: 0, distance: 0,
                                   maintenanceByType: [], otherByCategory: [])
}

/// Um mês do gráfico: gasolina, manutenção e outras despesas separadas (barras
/// empilhadas).
struct MonthCost: Equatable {
    let month: Date
    let fuel: Double
    let maintenance: Double
    var other: Double = 0
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
    static func summary(fuel: [FuelEntry], maintenance: [CostItem], other: [CostItem] = [],
                        in interval: DateInterval) -> CostSummary {
        let fuelTotal = fuel.filter { inside(interval, $0.date) }.reduce(0) { $0 + $1.totalCost }
        let maintenanceTypes = totalsByLabel(maintenance, in: interval)
        let otherCategories = totalsByLabel(other, in: interval)
        let distance = ConsumptionCalculator.spreadDistance(from: fuel, into: [interval]).first ?? 0
        return CostSummary(fuel: fuelTotal,
                           maintenance: maintenanceTypes.reduce(0) { $0 + $1.amount },
                           other: otherCategories.reduce(0) { $0 + $1.amount },
                           distance: distance,
                           maintenanceByType: maintenanceTypes,
                           otherByCategory: otherCategories)
    }

    /// Gasolina, manutenção e outras despesas por mês-civil, dos `monthCount`
    /// meses até `now` (inclusive), mais antigo → mais novo. Meses vazios entram
    /// com 0.
    static func monthly(fuel: [FuelEntry], maintenance: [CostItem], other: [CostItem] = [],
                        monthCount: Int = 12, now: Date,
                        calendar: Calendar = .current) -> [MonthCost] {
        guard monthCount > 0 else { return [] }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let months: [Date] = (0..<monthCount).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }
        var fuelBy = Dictionary(uniqueKeysWithValues: months.map { ($0, 0.0) })
        var maintenanceBy = fuelBy
        var otherBy = fuelBy
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
        for c in other {
            guard let m = calendar.dateInterval(of: .month, for: c.date)?.start,
                  otherBy[m] != nil else { continue }
            otherBy[m, default: 0] += c.amount
        }
        return months.map {
            MonthCost(month: $0, fuel: fuelBy[$0] ?? 0, maintenance: maintenanceBy[$0] ?? 0,
                      other: otherBy[$0] ?? 0)
        }
    }

    /// Ritmo do ano corrente até `now`.
    ///
    /// A projeção é linear: uma despesa anual (IPVA, seguro) paga no começo do
    /// ano infla a projeção até o ano andar. Aceito — o número diz "no ritmo
    /// atual", e o card mostra o realizado ao lado.
    static func yearPace(fuel: [FuelEntry], maintenance: [CostItem], other: [CostItem] = [],
                         now: Date, calendar: Calendar = .current) -> YearPace {
        guard let year = calendar.dateInterval(of: .year, for: now) else {
            return YearPace(soFar: 0, projection: nil, previousSamePeriod: nil)
        }
        let soFar = summary(fuel: fuel, maintenance: maintenance, other: other,
                            in: DateInterval(start: year.start, end: max(now, year.start))).total
        let elapsed = now.timeIntervalSince(year.start)
        let projection: Double? = elapsed >= 30 * 86_400 && soFar > 0
            ? soFar * year.duration / elapsed
            : nil

        // Só compara se já havia registro desde o começo do período anterior
        // (31 dias de folga): moto cadastrada no fim do ano passado daria
        // "+1.234%" contra meio mês de dados — número que não diz nada.
        var previous: Double?
        let firstRecord = firstDate(fuel: fuel, maintenance: maintenance, other: other)
        if let prevStart = calendar.date(byAdding: .year, value: -1, to: year.start),
           let prevEnd = calendar.date(byAdding: .year, value: -1, to: now), prevEnd >= prevStart,
           let firstRecord, firstRecord <= prevStart.addingTimeInterval(31 * 86_400) {
            let total = summary(fuel: fuel, maintenance: maintenance, other: other,
                                in: DateInterval(start: prevStart, end: prevEnd)).total
            previous = total > 0 ? total : nil
        }
        return YearPace(soFar: soFar, projection: projection, previousSamePeriod: previous)
    }

    /// Do primeiro registro com valor até `now` (período "Tudo"). nil sem registro.
    static func allTimeInterval(fuel: [FuelEntry], maintenance: [CostItem], other: [CostItem] = [],
                                now: Date) -> DateInterval? {
        guard let first = firstDate(fuel: fuel, maintenance: maintenance, other: other) else { return nil }
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

    /// Soma por rótulo dentro do período, maior valor primeiro (empate: A→Z).
    private static func totalsByLabel(_ items: [CostItem], in interval: DateInterval) -> [CostSummary.TypeTotal] {
        var byLabel: [String: Double] = [:]
        for item in items where inside(interval, item.date) {
            byLabel[item.label, default: 0] += item.amount
        }
        return byLabel
            .map { CostSummary.TypeTotal(label: $0.key, amount: $0.value) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.label < $1.label }
    }

    private static func firstDate(fuel: [FuelEntry], maintenance: [CostItem], other: [CostItem]) -> Date? {
        (fuel.map(\.date) + maintenance.map(\.date) + other.map(\.date)).min()
    }

    private static func inside(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}

extension Motorcycle {
    /// Manutenções com valor, no formato dos custos completos. Chave de tipo
    /// desconhecida (build mais novo) sai crua, nunca vira "Outro".
    var maintenanceCosts: [CostItem] {
        activeMaintenanceLogs.filter { $0.cost > 0 }.map {
            CostItem(date: $0.date, amount: $0.cost,
                     label: MaintenanceType(rawValue: $0.typeRaw) != nil ? $0.displayName : $0.typeRaw)
        }
    }

    /// Outras despesas no formato dos custos completos, por categoria. Chave
    /// desconhecida sai crua, nunca vira "Outra".
    var otherCosts: [CostItem] {
        activeExpenses.filter { $0.amount > 0 }.map {
            CostItem(date: $0.date, amount: $0.amount, label: $0.categoryLabel)
        }
    }

    /// Tudo o que a moto já custou: gasolina + manutenção + outras despesas.
    var totalSpentEver: Double {
        totalCostEver
            + maintenanceCosts.reduce(0) { $0 + $1.amount }
            + otherCosts.reduce(0) { $0 + $1.amount }
    }
}
