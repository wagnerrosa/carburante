//
//  CostsView.swift
//  Carburante
//
//  Tela "Custos" (Premium — PLAN/premium-mvp.md §2): quanto a moto custou de
//  verdade, gasolina + manutenção. Mesmo padrão da tela de Consumo (Saúde
//  "Mostrar todos os dados"): seletor de período, número-herói, gráfico e
//  cards. Alcançada pelo tile "Gasto este mês" do Resumo e pelo perfil da
//  moto. Cálculo em `CostCalculator`.
//
//  Sem Premium: o mês fica visível (o gasto do mês já é grátis no Resumo) e o
//  resto aparece coberto, com o caminho para a assinatura — "mostra o que tem,
//  cobra o detalhe".
//

import SwiftUI
import Charts

struct CostsView: View {
    @Bindable var motorcycle: Motorcycle
    @State private var period: Period = .year
    @State private var showPaywall = false
    @Environment(\.dynamicTypeSize) private var typeSize

    enum Period: String, CaseIterable, Identifiable {
        case month = "Mês"
        case year = "Ano"
        case all = "Tudo"
        var id: Self { self }
    }

    private let calendar = Calendar.current
    private var now: Date { Date() }

    private var fuel: [FuelEntry] { motorcycle.consumptionEntries }
    private var maintenance: [MaintenanceCost] { motorcycle.maintenanceCosts }

    private var isPremium: Bool { PremiumService.shared.isPremium }

    /// Sem Premium, só o mês.
    private var shownPeriod: Period { isPremium ? period : .month }

    private var hasAnyCost: Bool {
        fuel.contains { $0.totalCost > 0 } || !maintenance.isEmpty
    }

    private var interval: DateInterval? {
        switch shownPeriod {
        case .month: calendar.dateInterval(of: .month, for: now)
        case .year: calendar.dateInterval(of: .year, for: now)
        case .all: CostCalculator.allTimeInterval(fuel: fuel, maintenance: maintenance, now: now)
        }
    }

    private var summary: CostSummary {
        interval.map { CostCalculator.summary(fuel: fuel, maintenance: maintenance, in: $0) } ?? .empty
    }

    var body: some View {
        Group {
            if hasAnyCost {
                content
            } else {
                ContentUnavailableView {
                    Label("Nenhum custo registrado", systemImage: "brazilianrealsign.circle")
                } description: {
                    Text("Os gastos com gasolina e manutenção aparecem aqui conforme você registra.")
                }
            }
        }
        .navigationTitle("Custos")
        .navigationBarTitleDisplayMode(.inline)
        .tint(motorcycle.themeColor)
        .onAppear {
            Analytics.costsViewed(hasMaintenanceCost: !maintenance.isEmpty)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView(reason: .costs)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isPremium {
                    Picker("Período", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                header
                if isPremium {
                    monthlyCard
                    perKmCard
                    if !summary.maintenanceByType.isEmpty {
                        byTypeCard
                    }
                    switch period {
                    case .year: yearCard
                    case .all: averageCard
                    case .month: EmptyView()
                    }
                } else {
                    lockedCards
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Herói

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TOTAL")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(AppFormat.currency(summary.total))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("Gasolina \(AppFormat.currency(summary.fuel)) · Manutenção \(AppFormat.currency(summary.maintenance))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(periodDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: period)
    }

    private var periodDescription: String {
        switch shownPeriod {
        case .month:
            return now.formatted(.dateTime.month(.wide).year().locale(AppFormat.locale))
        case .year:
            return String(calendar.component(.year, from: now))
        case .all:
            guard let start = interval?.start else { return "" }
            return "Desde " + start.formatted(.dateTime.month(.abbreviated).year().locale(AppFormat.locale))
        }
    }

    // MARK: - Sem Premium

    /// Os cards do Premium cobertos (os do próprio piloto, não um exemplo) e,
    /// por cima, o que eles mostram + o caminho para a assinatura. ZStack, não
    /// overlay: em tamanhos de acessibilidade o aviso pode ficar mais alto que
    /// os cards.
    private var lockedCards: some View {
        ZStack {
            VStack(spacing: 20) {
                monthlyCard
                perKmCard
            }
            .blur(radius: 10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            GroupedCard {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Custos completos")
                        .font(.headline)
                    Text("O ano todo, o custo real por km e para onde vai o dinheiro da manutenção.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Conhecer o Premium")
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
            // Recuado sobre os cards cobertos; em tamanhos de acessibilidade a
            // largura vai toda para o texto.
            .padding(.horizontal, typeSize.isAccessibilitySize ? 0 : 24)
        }
    }

    // MARK: - Mês a mês

    private var monthlyCard: some View {
        let months = CostCalculator.monthly(fuel: fuel, maintenance: maintenance, now: now)
        return GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Últimos 12 meses", systemImage: "chart.bar.fill")
                Chart {
                    ForEach(months, id: \.month) { m in
                        BarMark(x: .value("Mês", m.month, unit: .month),
                                y: .value("Valor", m.fuel))
                            .foregroundStyle(by: .value("Tipo", "Gasolina"))
                        BarMark(x: .value("Mês", m.month, unit: .month),
                                y: .value("Valor", m.maintenance))
                            .foregroundStyle(by: .value("Tipo", "Manutenção"))
                    }
                }
                .chartForegroundStyleScale([
                    "Gasolina": motorcycle.themeColor,
                    "Manutenção": Color(.systemGray3),
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.formatted(.number.notation(.compactName).locale(AppFormat.locale)))
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Custo por km

    private var perKmCard: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Custo por km", systemImage: "road.lanes")
                row("Real (gasolina + manutenção)", summary.costPerKm.map(AppFormat.currency) ?? "—", bold: true)
                Divider()
                row("Só gasolina", summary.fuelCostPerKm.map(AppFormat.currency) ?? "—")
                Divider()
                row("Rodados no período", AppFormat.km(summary.distance))
            }
        }
    }

    // MARK: - Manutenção por tipo

    private var byTypeCard: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Manutenção por tipo", systemImage: "wrench.and.screwdriver.fill")
                ForEach(Array(summary.maintenanceByType.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider() }
                    row(item.label, AppFormat.currency(item.amount))
                }
            }
        }
    }

    // MARK: - Ritmo do ano / média

    @ViewBuilder
    private var yearCard: some View {
        let pace = CostCalculator.yearPace(fuel: fuel, maintenance: maintenance, now: now)
        if pace.projection != nil || pace.previousSamePeriod != nil {
            // String, não interpolação no título: `LocalizedStringKey` formata o
            // ano como número ("2.025").
            let year = String(calendar.component(.year, from: now))
            let lastYear = String(calendar.component(.year, from: now) - 1)
            GroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    cardTitle("Ritmo do ano", systemImage: "calendar")
                    if let projection = pace.projection {
                        row("Projeção para \(year)", AppFormat.currency(projection))
                    }
                    if pace.projection != nil, pace.previousSamePeriod != nil { Divider() }
                    if let previous = pace.previousSamePeriod {
                        LabeledContent("Mesmo período de " + lastYear) {
                            HStack(spacing: 6) {
                                Text(AppFormat.currency(previous)).monospacedDigit()
                                if let change = pace.change {
                                    changeLabel(change)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var averageCard: some View {
        if let start = interval?.start {
            GroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    cardTitle("Média", systemImage: "equal.circle")
                    row("Por mês", AppFormat.currency(
                        CostCalculator.monthlyAverage(total: summary.total, since: start, now: now)))
                }
            }
        }
    }

    // MARK: - Peças

    private func cardTitle(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        LabeledContent(label) {
            Text(value)
                .monospacedDigit()
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(.primary)
        }
    }

    /// Variação neutra (PLAN/DESIGN.md §4): seta cinza + %, sem verde/vermelho —
    /// gastar mais não é "erro". Só a partir de 5%, como `ConsumptionTrend`.
    @ViewBuilder
    private func changeLabel(_ change: Double) -> some View {
        if abs(change) >= 0.05 {
            Label(abs(change).formatted(.percent.precision(.fractionLength(0)).locale(AppFormat.locale)),
                  systemImage: change > 0 ? "arrow.up" : "arrow.down")
                .labelStyle(.titleAndIcon)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
