//
//  ConsumptionChartView.swift
//  Carburante
//
//  Tela "Consumo" (padrão Saúde "Mostrar todos os dados"): barras de km/l por
//  segmento full-to-full + linha de média + scrub (arrastar o dedo destaca um
//  segmento) + seletor de período. Mora fora do Resumo para mantê-lo calmo;
//  alcançada tocando no número-herói. Swift Charts nativo, sem libs.
//

import SwiftUI
import SwiftData
import Charts

struct ConsumptionChartView: View {
    @Bindable var motorcycle: Motorcycle

    @State private var period: Period = .all
    /// Índice (String) da posição sob o dedo durante o scrub — o eixo X é
    /// categórico por posição. nil = sem seleção → mostra a média.
    @State private var rawSelection: String?

    /// Segmentos full-to-full, mais antigo → mais novo.
    private var allSegments: [ConsumptionSegment] {
        ConsumptionCalculator.segments(from: motorcycle.activeFuelLogs.map(\.asFuelEntry))
            .sorted { $0.endDate < $1.endDate }
    }

    private var bars: [Bar] {
        let cutoff = period.cutoff
        let filtered = cutoff.map { c in allSegments.filter { $0.endDate >= c } } ?? allSegments
        return filtered.enumerated().map { Bar(id: $0.offset, date: $0.element.endDate,
                                               value: $0.element.kmPerLiter,
                                               distance: $0.element.distance,
                                               liters: $0.element.liters) }
    }

    /// Média ponderada (distância ÷ litros) dos segmentos exibidos — mesma
    /// metodologia do `ConsumptionCalculator`, não a média simples das barras.
    private var average: Double? {
        let liters = bars.reduce(0) { $0 + $1.liters }
        let distance = bars.reduce(0) { $0 + $1.distance }
        return liters > 0 ? distance / liters : nil
    }

    /// Barra destacada pelo scrub (a da posição sob o dedo).
    private var selectedBar: Bar? {
        guard let raw = rawSelection, let i = Int(raw) else { return nil }
        return bars.first { $0.id == i }
    }

    var body: some View {
        Group {
            if allSegments.isEmpty {
                ContentUnavailableView {
                    Label("Sem dados de consumo", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("Registre dois abastecimentos com tanque cheio para ver a tendência de consumo.")
                }
            } else {
                content
            }
        }
        .navigationTitle("Consumo")
        .navigationBarTitleDisplayMode(.inline)
        // Gráfico e seletor usam o tema desta moto.
        .tint(motorcycle.themeColor)
        .onAppear(perform: trackView)
    }

    /// Analytics da tela de Consumo: comportamento (consumption_chart_viewed) +
    /// 1ª adoção da feature de gráfico e da comparação com a categoria.
    private func trackView() {
        let segs = allSegments
        let reference = motorcycle.categoryReferenceKmPerLiter
        let vsCategory: String
        if let ref = reference, let avg = average {
            vsCategory = avg >= ref ? "above" : "below"
        } else {
            vsCategory = "none"
        }
        Analytics.consumptionChartViewed(hasData: !segs.isEmpty, segmentCount: segs.count,
                                         vsCategory: vsCategory)
        if !segs.isEmpty, AdoptionTracker.markAndCheck(.consumptionChart) {
            Analytics.featureAdopted(.consumptionChart)
        }
        if reference != nil, AdoptionTracker.markAndCheck(.categoryComparison) {
            Analytics.featureAdopted(.categoryComparison)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Período", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                header
                chart

                if bars.count < 2 {
                    Text("Registre mais abastecimentos com tanque cheio para comparar a tendência ao longo do tempo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Card próprio para a comparação com a categoria (padrão Apple:
                // gráficos distintos em cards separados, não tudo num só).
                if let reference = motorcycle.categoryReferenceKmPerLiter {
                    categoryCard(reference)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Cabeçalho (herói que reage ao scrub)

    private var header: some View {
        let showingSelection = selectedBar != nil
        let value = selectedBar?.value ?? average
        return VStack(alignment: .leading, spacing: 2) {
            // Rótulo em CAPS pequeno (padrão Saúde tela cheia: "MÉDIA").
            Text(showingSelection ? "CONSUMO" : "MÉDIA")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value.map { $0.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale)) } ?? "—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/l")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: selectedBar?.id)
    }

    /// Subtítulo do herói: na seleção, data + distância do segmento; sem seleção,
    /// o intervalo de datas coberto (padrão Saúde: "13–19 de jun. de 2026").
    private var subtitle: String {
        if let sel = selectedBar {
            return "\(AppFormat.date(sel.date)) · \(AppFormat.km(sel.distance))"
        }
        guard let first = bars.first?.date, let last = bars.last?.date else {
            return "Sem dados"
        }
        return first == last
            ? AppFormat.date(last)
            : "\(AppFormat.date(first)) – \(AppFormat.date(last))"
    }

    // MARK: - Card de comparação com a categoria

    /// Card dedicado (padrão Apple: um gráfico por card) que compara a média real
    /// da moto com a estimativa da categoria, via duas barras horizontais de
    /// comprimento proporcional — verde (tema) = sua moto, cinza = categoria.
    /// Rotulado como ESTIMATIVA e antecipa as camadas futuras (histórico, peers).
    private func categoryCard(_ reference: Double) -> some View {
        let mine = average
        let delta = mine.map { ($0 - reference) / reference }
        // Escala comum às duas barras (a maior preenche ~100%).
        let scale = max(mine ?? 0, reference)
        return GroupedCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Comparação com a categoria")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                comparisonBar(label: "Sua moto", value: mine,
                              scale: scale, color: motorcycle.themeColor)
                comparisonBar(label: "Média da categoria", value: reference,
                              scale: scale, color: Color(.systemGray))

                if let delta {
                    comparisonHeadline(delta)
                }
                Text("Estimativa da categoria. Em breve: comparação com seu próprio histórico e com outros pilotos da mesma moto.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Uma linha do card: rótulo + valor à direita, e abaixo a barra horizontal
    /// proporcional (largura = value / scale). GeometryReader dá a largura útil.
    private func comparisonBar(label: String, value: Double?, scale: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.map { $0.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale)) } ?? "—")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("km/l")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                let frac = (scale > 0 ? (value ?? 0) / scale : 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(color)
                        .frame(width: max(geo.size.width * frac, frac > 0 ? 8 : 0))
                }
            }
            .frame(height: 10)
        }
    }

    /// Frase curta interpretando o delta vs categoria. Faixa de ±5% = "na média"
    /// (estimativa grosseira não justifica precisão maior).
    @ViewBuilder
    private func comparisonHeadline(_ delta: Double) -> some View {
        let pct = abs(delta * 100).formatted(.number.precision(.fractionLength(0)).locale(AppFormat.locale))
        let (text, color): (String, Color) = {
            if delta > 0.05 {
                return ("Sua moto faz \(pct)% a mais que a média da categoria.", .green)
            } else if delta < -0.05 {
                return ("Sua moto faz \(pct)% a menos que a média da categoria.", .orange)
            } else {
                return ("Sua moto está na média da categoria.", .secondary)
            }
        }()
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
    }

    // MARK: - Gráfico

    private var chart: some View {
        // Rótulo de mês por posição: só quando o mês muda (evita repetir no eixo X).
        let monthLabels: [Int: String] = {
            var out: [Int: String] = [:]
            var lastMonth = -1
            let cal = Calendar.current
            for (i, bar) in bars.enumerated() {
                let m = cal.component(.month, from: bar.date)
                if m != lastMonth {
                    out[i] = bar.date.formatted(.dateTime.month(.abbreviated).locale(AppFormat.locale))
                    lastMonth = m
                }
            }
            return out
        }()

        return Chart {
            // X categórico por posição (espaçamento uniforme, como o Saúde) — não
            // escala temporal real (datas irregulares deixariam barras desencontradas).
            // Barras grossas, cor SÓLIDA do tema; sem linha de média (a média fica no
            // cabeçalho, como na tela cheia do Saúde). Scrub esmaece as não-selecionadas.
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                BarMark(
                    x: .value("Segmento", String(index)),
                    y: .value("km/l", bar.value),
                    width: .ratio(0.6)
                )
                .foregroundStyle(motorcycle.themeColor
                    .opacity(selectedBar == nil || selectedBar?.id == bar.id ? 1 : 0.3))
                .cornerRadius(4)
            }
        }
        .chartXSelection(value: $rawSelection)
        // Grid + eixo Y à direita (padrão Saúde tela cheia): linhas horizontais com
        // rótulos km/l à direita.
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(0)).locale(AppFormat.locale)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Verticais sutis separando as posições + rótulo de mês quando muda.
        .chartXAxis {
            AxisMarks(values: Array(bars.indices).map(String.init)) { value in
                AxisGridLine().foregroundStyle(Color(.systemGray5))
                if let s = value.as(String.self), let i = Int(s), let label = monthLabels[i] {
                    AxisValueLabel {
                        Text(label).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 260)
        // Scrub sem retorno tátil parecia "morto" ao arrastar entre barras.
        .sensoryFeedback(.selection, trigger: selectedBar?.id)
    }

    /// Uma barra do gráfico (segmento + posição).
    private struct Bar: Identifiable {
        let id: Int
        let date: Date
        let value: Double
        let distance: Double
        let liters: Double
    }

    /// Período exibido no gráfico.
    enum Period: String, CaseIterable, Identifiable {
        case sixMonths = "6M"
        case year = "1A"
        case all = "Tudo"

        var id: String { rawValue }

        /// Data-corte: segmentos com `endDate` ≥ corte entram. nil = sem corte.
        var cutoff: Date? {
            let months: Int
            switch self {
            case .sixMonths: months = 6
            case .year: months = 12
            case .all: return nil
            }
            return Calendar.current.date(byAdding: .month, value: -months, to: Date())
        }
    }
}
