//
//  ConsumptionCalculator.swift
//  Carburante
//
//  Núcleo do produto: cálculo de consumo. Lógica pura, sem UI, sem SwiftData
//  — recebe valores simples, totalmente testável por XCTest.
//
//  Método full-to-full: consumo só é confiável entre dois abastecimentos com
//  tanque cheio. Litros de abastecimentos parciais entre dois cheios são
//  somados ao segmento. O primeiro registro é só uma âncora (sem consumo).
//

import Foundation

/// Entrada mínima para o cálculo — desacopla a lógica do modelo SwiftData.
struct FuelEntry {
    let odometer: Double
    let liters: Double
    let totalCost: Double
    let isFullTank: Bool
    let date: Date
}

/// Consumo de um segmento entre dois tanques cheios consecutivos.
struct ConsumptionSegment: Equatable {
    /// km rodados no segmento (odômetro do cheio final − odômetro do cheio inicial).
    let distance: Double
    /// litros consumidos no segmento (soma dos abastecimentos após o cheio inicial até o cheio final).
    let liters: Double
    /// custo dos litros do segmento.
    let cost: Double
    /// data do cheio que fecha o segmento (eixo X dos gráficos / filtro de período).
    let endDate: Date
    /// odômetro do cheio que fecha o segmento — casa o segmento ao `FuelLog`
    /// correspondente (pílula de km/l no histórico).
    let endOdometer: Double

    /// km por litro.
    var kmPerLiter: Double { liters > 0 ? distance / liters : 0 }
}

/// Uma barra do mini-gráfico de distância (km rodados num período — semana).
/// `monthLabel` não-nil marca a 1ª barra de um mês-âncora → vira rótulo no eixo
/// X (ex.: "jan."), no estilo Fitness que rotula só alguns pontos.
struct DistanceBar: Equatable {
    /// Início do período (semana) que a barra cobre.
    let start: Date
    /// km rodados na semana (delta de odômetro).
    let distance: Double
    /// Rótulo de mês quando esta barra abre um mês-âncora; nil caso contrário.
    let monthLabel: String?
}

/// Resumo agregado para uma moto.
struct ConsumptionSummary: Equatable {
    let averageKmPerLiter: Double?
    let totalDistance: Double
    let totalLitersInSegments: Double
    let totalCostInSegments: Double
    let segmentCount: Int

    /// custo por km, com base nos segmentos medidos.
    var costPerKm: Double? {
        guard totalDistance > 0 else { return nil }
        return totalCostInSegments / totalDistance
    }
}

/// Recordes pessoais (PRs) de uma moto — o único do app, reflexo privado,
/// nunca ranking. Cada campo é nil quando não há dado suficiente → empty state.
/// Mesma fonte (`segments`) do resto do app: recorde nunca diverge do gráfico.
struct GarageRecords: Equatable {
    /// Melhor km/l de sempre (maior entre os segmentos full-to-full).
    let bestKmPerLiter: Double?
    /// Maior trecho cheio-a-cheio (km do segmento mais longo).
    let longestSegment: Double?
    /// Litro mais barato pago (menor preço/litro entre abastecimentos com litros > 0).
    let cheapestPricePerLiter: Double?
}

extension FuelLog {
    var asFuelEntry: FuelEntry {
        FuelEntry(odometer: odometer, liters: liters, totalCost: totalCost, isFullTank: isFullTank, date: date)
    }
}

extension Motorcycle {
    /// Resumo de consumo da moto a partir dos seus abastecimentos.
    var consumptionSummary: ConsumptionSummary {
        ConsumptionCalculator.summary(from: fuelLogs.map(\.asFuelEntry))
    }

    /// Quantos abastecimentos cheios faltam até o 1º km/l aparecer (0/1/2).
    /// Base das mensagens que explicam o método full-to-full ao usuário.
    var fullTanksUntilConsumption: Int {
        ConsumptionCalculator.fullTanksUntilFirstReading(from: fuelLogs.map(\.asFuelEntry))
    }

    /// Recordes pessoais (PRs) da moto — para a seção Recordes da Garagem.
    var records: GarageRecords {
        ConsumptionCalculator.records(from: fuelLogs.map(\.asFuelEntry))
    }

    /// Km rodados desde o cadastro (leitura manual de referência). Base do
    /// progresso por categoria nas medalhas — reflete uso real, não só os
    /// trechos full-to-full. Nunca negativo.
    var distanceSinceBaseline: Double {
        max(0, currentOdometer - odometerBaseline)
    }

    // MARK: - Totais vitalícios (Garagem)

    /// Litros abastecidos na vida da moto (soma simples, independe de tanque cheio).
    var totalLitersEver: Double { fuelLogs.reduce(0) { $0 + $1.liters } }

    /// Gasto total na vida da moto (soma simples).
    var totalCostEver: Double { fuelLogs.reduce(0) { $0 + $1.totalCost } }

    /// Quantos abastecimentos a moto tem registrados.
    var fuelLogCount: Int { fuelLogs.count }

    /// Abastecimento mais recente por data.
    var latestFuelLog: FuelLog? {
        fuelLogs.max { $0.date < $1.date }
    }

    // MARK: - Métricas do Resumo (gasto / preço por litro)

    /// Gasto somado por mês para a sparkline (últimos 6 meses, com zeros).
    func monthlyExpenseSeries(now: Date = Date()) -> [(month: Date, total: Double)] {
        ConsumptionCalculator.monthlyExpense(from: fuelLogs.map(\.asFuelEntry), now: now)
    }

    /// Gasto do mês-civil atual.
    func expenseThisMonth(now: Date = Date()) -> Double {
        monthlyExpenseSeries(now: now).last?.total ?? 0
    }

    /// Preço por litro de cada abastecimento (série da sparkline).
    var pricePerLiterSeries: [Double] {
        ConsumptionCalculator.pricePerLiterSeries(from: fuelLogs.map(\.asFuelEntry))
    }

    /// Preço médio por litro = gasto total ÷ litros totais (ponderado pelo
    /// volume, não média simples dos preços). nil sem litros.
    var averagePricePerLiter: Double? {
        let liters = fuelLogs.reduce(0) { $0 + $1.liters }
        let cost = fuelLogs.reduce(0) { $0 + $1.totalCost }
        return liters > 0 ? cost / liters : nil
    }

    /// Custo por km de cada segmento (série da sparkline do tile Custo/km).
    var costPerKmSeries: [Double] {
        ConsumptionCalculator.costPerKmSeries(from: fuelLogs.map(\.asFuelEntry))
    }

    /// km rodados por mês.
    func monthlyDistanceSeries(now: Date = Date()) -> [(month: Date, distance: Double)] {
        ConsumptionCalculator.monthlyDistance(from: fuelLogs.map(\.asFuelEntry), now: now)
    }

    /// km rodados por semana (barras densas do tile "Rodados", estilo Fitness).
    func weeklyDistanceSeries(now: Date = Date()) -> [DistanceBar] {
        ConsumptionCalculator.weeklyDistance(from: fuelLogs.map(\.asFuelEntry), now: now)
    }

    /// km rodados no mês-civil atual (número grande do tile).
    func distanceThisMonth(now: Date = Date()) -> Double {
        monthlyDistanceSeries(now: now).last?.distance ?? 0
    }
}

extension Array where Element == Motorcycle {
    /// Contexto de medalhas da FROTA inteira (ver `Badge.swift`). Deriva tudo dos
    /// dados já persistidos — nenhum estado de conquista é salvo. Categorias
    /// presentes = o que aparece; km por categoria = soma de `distanceSinceBaseline`.
    var badgeFleetContext: BadgeFleetContext {
        var present = Set<MotorcycleCategory>()
        var kmByCategory: [MotorcycleCategory: Double] = [:]
        var hasMaintenance = false
        var fullTanks = 0
        var beatsCategory = false

        for moto in self {
            if !moto.maintenanceLogs.isEmpty { hasMaintenance = true }
            fullTanks += moto.fuelLogs.filter(\.isFullTank).count
            // "Acima da média": melhor km/l medido supera a régua da categoria.
            // Régua nil (sem cilindrada/categoria) → não conta (degrada limpo).
            if let best = moto.records.bestKmPerLiter,
               let ref = moto.categoryReferenceKmPerLiter, best >= ref {
                beatsCategory = true
            }
            // categoryEnum nil → trata como `.other` (toda moto pertence a alguma
            // categoria visível; sem isso uma moto sem categoria não renderia badge).
            let cat = moto.categoryEnum ?? .other
            present.insert(cat)
            kmByCategory[cat, default: 0] += moto.distanceSinceBaseline
        }

        return BadgeFleetContext(
            hasMotorcycle: !isEmpty,
            hasMaintenanceLog: hasMaintenance,
            fullTankCount: fullTanks,
            beatsCategoryAverage: beatsCategory,
            presentCategories: present,
            kmByCategory: kmByCategory
        )
    }
}

enum ConsumptionCalculator {

    /// Quebra os abastecimentos em segmentos full-to-full.
    /// Entradas em qualquer ordem — são ordenadas por odômetro asc.
    static func segments(from entries: [FuelEntry]) -> [ConsumptionSegment] {
        let ordered = entries.sorted { $0.odometer < $1.odometer }
        guard ordered.count >= 2 else { return [] }

        var segments: [ConsumptionSegment] = []
        var anchor: FuelEntry?          // último cheio que abre um segmento
        var litersSinceAnchor = 0.0     // litros acumulados após a âncora
        var costSinceAnchor = 0.0

        for entry in ordered {
            if let start = anchor {
                // Tudo que entra depois da âncora conta para o segmento atual.
                litersSinceAnchor += entry.liters
                costSinceAnchor += entry.totalCost

                if entry.isFullTank {
                    let distance = entry.odometer - start.odometer
                    // Distância inválida (odômetro não avançou) → ignora o segmento,
                    // mas mantém este cheio como nova âncora.
                    if distance > 0 {
                        segments.append(ConsumptionSegment(
                            distance: distance,
                            liters: litersSinceAnchor,
                            cost: costSinceAnchor,
                            endDate: entry.date,
                            endOdometer: entry.odometer
                        ))
                    }
                    anchor = entry
                    litersSinceAnchor = 0
                    costSinceAnchor = 0
                }
            } else if entry.isFullTank {
                // Primeiro cheio = âncora inicial, sem consumo associado.
                anchor = entry
            }
            // Abastecimentos parciais antes do primeiro cheio são descartados
            // (não há âncora confiável para medir).
        }

        return segments
    }

    // MARK: - Séries para os mini-gráficos do Resumo
    //
    // Despesa e preço/litro valem por ABASTECIMENTO (não dependem de tanque
    // cheio, ao contrário do consumo). Funções puras, ordenam internamente,
    // recebem `now`/`calendar` por parâmetro → testáveis e determinísticas.

    /// Gasto somado por mês-civil, dos `monthCount` meses até `now` (inclusive),
    /// na ordem mais antigo → mais novo. Meses sem abastecimento entram com 0
    /// (série contínua → sparkline sem buracos). O `Date` é o 1º dia do mês.
    static func monthlyExpense(
        from entries: [FuelEntry],
        monthCount: Int = 6,
        now: Date,
        calendar: Calendar = .current
    ) -> [(month: Date, total: Double)] {
        guard monthCount > 0 else { return [] }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        // Eixo de meses: thisMonth, mês anterior, … (monthCount posições).
        let months: [Date] = (0..<monthCount).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }
        // Soma os gastos no balde do mês correspondente.
        var totals: [Date: Double] = Dictionary(uniqueKeysWithValues: months.map { ($0, 0) })
        for e in entries {
            guard let m = calendar.dateInterval(of: .month, for: e.date)?.start,
                  totals[m] != nil else { continue }
            totals[m, default: 0] += e.totalCost
        }
        return months.map { (month: $0, total: totals[$0] ?? 0) }
    }

    /// km rodados por mês-civil, dos `monthCount` meses até `now` (inclusive),
    /// mais antigo → mais novo. Como o odômetro é cumulativo, os km de um mês =
    /// (maior odômetro lido nesse mês) − (último odômetro conhecido antes dele).
    /// Mês sem abastecimento → 0 (nenhuma leitura nova). Para a sparkline de
    /// barras "rodados por mês".
    static func monthlyDistance(
        from entries: [FuelEntry],
        monthCount: Int = 6,
        now: Date,
        calendar: Calendar = .current
    ) -> [(month: Date, distance: Double)] {
        guard monthCount > 0 else { return [] }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let months: [Date] = (0..<monthCount).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }
        guard let firstMonth = months.first else { return [] }

        let ordered = entries.sorted { $0.odometer < $1.odometer }
        // Maior odômetro lido em cada mês da janela.
        var maxByMonth: [Date: Double] = [:]
        // Baseline = último odômetro ANTES da janela (para o 1º mês ter referência).
        var baseline: Double?
        for e in ordered {
            guard let m = calendar.dateInterval(of: .month, for: e.date)?.start else { continue }
            if m < firstMonth {
                baseline = e.odometer            // ordenado por odômetro → fica o maior
            } else if maxByMonth[m] != nil || months.contains(m) {
                maxByMonth[m] = max(maxByMonth[m] ?? 0, e.odometer)
            }
        }

        // Caminha os meses acumulando: cada mês fecha no seu maior odômetro;
        // meses vazios herdam o anterior (delta 0).
        var prev = baseline
        return months.map { month in
            let end = maxByMonth[month] ?? prev
            let dist: Double = {
                guard let end, let p = prev else { return 0 }
                return max(end - p, 0)
            }()
            if let end { prev = end }
            return (month: month, distance: dist)
        }
    }

    /// km rodados por SEMANA, das `weekCount` semanas até `now` (inclusive),
    /// mais antigo → mais novo. Mesma lógica de delta de odômetro do
    /// `monthlyDistance`, mas em baldes semanais → barras densas (estilo
    /// Fitness). Cada barra ganha `monthLabel` na 1ª semana de um mês novo, para
    /// rotular o eixo X só em pontos-âncora. `locale` formata o rótulo do mês.
    static func weeklyDistance(
        from entries: [FuelEntry],
        weekCount: Int = 26,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = AppFormat.locale
    ) -> [DistanceBar] {
        guard weekCount > 0 else { return [] }
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weeks: [Date] = (0..<weekCount).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek)
        }
        guard let firstWeek = weeks.first else { return [] }

        let ordered = entries.sorted { $0.odometer < $1.odometer }
        // Maior odômetro lido em cada semana da janela + baseline antes dela.
        var maxByWeek: [Date: Double] = [:]
        var baseline: Double?
        let weekSet = Set(weeks)
        for e in ordered {
            guard let w = calendar.dateInterval(of: .weekOfYear, for: e.date)?.start else { continue }
            if w < firstWeek {
                baseline = e.odometer
            } else if weekSet.contains(w) {
                maxByWeek[w] = max(maxByWeek[w] ?? 0, e.odometer)
            }
        }

        var prev = baseline
        // Inicia no mês da 1ª semana → a 1ª barra NÃO é rotulada (senão dois meses
        // colam na borda esquerda, ex.: "dez"+"jan"="djan"). Rótulo só nas
        // transições de mês dentro da janela — como o Fitness rotula só alguns X.
        var lastMonth = weeks.first.map { calendar.component(.month, from: $0) } ?? -1
        return weeks.map { week in
            let end = maxByWeek[week] ?? prev
            let dist: Double = {
                guard let end, let p = prev else { return 0 }
                return max(end - p, 0)
            }()
            if let end { prev = end }
            let month = calendar.component(.month, from: week)
            let label: String? = month != lastMonth
                ? week.formatted(.dateTime.month(.abbreviated).locale(locale))
                : nil
            lastMonth = month
            return DistanceBar(start: week, distance: dist, monthLabel: label)
        }
    }

    /// Preço por litro de cada abastecimento (mais antigo → mais novo), só os
    /// com litros > 0. Para a sparkline de tendência de preço.
    static func pricePerLiterSeries(from entries: [FuelEntry]) -> [Double] {
        entries
            .sorted { $0.date < $1.date }
            .compactMap { $0.liters > 0 ? $0.totalCost / $0.liters : nil }
    }

    /// Custo por km de cada segmento full-to-full (mais antigo → mais novo).
    /// Para a sparkline do tile "Custo por km".
    static func costPerKmSeries(from entries: [FuelEntry]) -> [Double] {
        segments(from: entries)
            .sorted { $0.endDate < $1.endDate }
            .compactMap { $0.distance > 0 ? $0.cost / $0.distance : nil }
    }

    /// Quantos abastecimentos COM TANQUE CHEIO ainda faltam até existir a
    /// primeira leitura de consumo (km/l). O método full-to-full exige dois
    /// cheios com avanço de odômetro entre eles para fechar um segmento:
    ///
    ///   - já há ≥1 segmento medível → 0 (o consumo já aparece);
    ///   - 0 cheios registrados      → 2 (precisa de dois);
    ///   - 1 cheio (a âncora)        → 1 (falta o cheio que fecha o 1º segmento);
    ///   - 2+ cheios mas o odômetro não avançou entre eles (segmento inválido,
    ///     ex.: leitura repetida)    → 1 (ainda falta um cheio válido).
    ///
    /// Abastecimentos parciais NÃO contam (não fecham segmento) — por isso a
    /// contagem olha só os cheios, e cai para o `segments()` para detectar o
    /// caso de odômetro que não avançou. Mesma fonte de verdade do gráfico, para
    /// a mensagem nunca divergir do que está desenhado.
    static func fullTanksUntilFirstReading(from entries: [FuelEntry]) -> Int {
        // Já existe consumo medido → nada falta.
        if !segments(from: entries).isEmpty { return 0 }

        let fullTanks = entries.filter(\.isFullTank).count
        // 0 cheios → faltam 2; 1+ cheios sem segmento ainda → falta 1.
        return fullTanks == 0 ? 2 : 1
    }

    /// Recordes pessoais (PRs) — melhor km/l, maior trecho, litro mais barato.
    /// km/l e trecho saem dos segmentos full-to-full (mesma fonte do gráfico);
    /// preço/litro olha cada abastecimento (não depende de tanque cheio). Cada
    /// recorde é nil quando não há dado para ele → empty state na Garagem.
    static func records(from entries: [FuelEntry]) -> GarageRecords {
        let segs = segments(from: entries)
        let bestKmPerLiter = segs.map(\.kmPerLiter).filter { $0 > 0 }.max()
        let longestSegment = segs.map(\.distance).max()
        let cheapest = entries
            .compactMap { $0.liters > 0 ? $0.totalCost / $0.liters : nil }
            .min()
        return GarageRecords(
            bestKmPerLiter: bestKmPerLiter,
            longestSegment: longestSegment,
            cheapestPricePerLiter: cheapest
        )
    }

    /// Resumo agregado. `averageKmPerLiter` é nil quando não há segmento medível.
    static func summary(from entries: [FuelEntry]) -> ConsumptionSummary {
        let segs = segments(from: entries)
        let totalDistance = segs.reduce(0) { $0 + $1.distance }
        let totalLiters = segs.reduce(0) { $0 + $1.liters }
        let totalCost = segs.reduce(0) { $0 + $1.cost }
        let average: Double? = totalLiters > 0 ? totalDistance / totalLiters : nil

        return ConsumptionSummary(
            averageKmPerLiter: average,
            totalDistance: totalDistance,
            totalLitersInSegments: totalLiters,
            totalCostInSegments: totalCost,
            segmentCount: segs.count
        )
    }
}
