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
    /// Data sob o dedo durante o scrub (nil = sem seleção → mostra a média).
    @State private var rawSelection: Date?

    /// Segmentos full-to-full, mais antigo → mais novo.
    private var allSegments: [ConsumptionSegment] {
        ConsumptionCalculator.segments(from: motorcycle.fuelLogs.map(\.asFuelEntry))
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

    /// Barra destacada pelo scrub (a mais próxima da data sob o dedo).
    private var selectedBar: Bar? {
        guard let raw = rawSelection else { return nil }
        return bars.min { abs($0.date.timeIntervalSince(raw)) < abs($1.date.timeIntervalSince(raw)) }
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
            Text(showingSelection ? "Consumo do segmento" : "Média do período")
                .font(.subheadline.weight(.medium))
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
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: selectedBar?.id)
    }

    private var subtitle: String {
        if let sel = selectedBar {
            return "\(AppFormat.date(sel.date)) · \(AppFormat.km(sel.distance))"
        }
        let count = bars.count
        return "\(count) \(count == 1 ? "segmento medido" : "segmentos medidos")"
    }

    // MARK: - Gráfico

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Data", bar.date, unit: .day),
                    y: .value("km/l", bar.value),
                    width: .fixed(18)
                )
                .foregroundStyle(selectedBar == nil || selectedBar?.id == bar.id
                                 ? Color.accentColor.gradient
                                 : Color.accentColor.opacity(0.25).gradient)
                .cornerRadius(5)
            }

            if let average {
                RuleMark(y: .value("Média", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Média \(average.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale)))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXSelection(value: $rawSelection)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(0)).locale(AppFormat.locale)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(AppFormat.locale))
            }
        }
        .frame(height: 240)
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
