//
//  DashboardView.swift
//  Carburante
//
//  Resumo: número-herói (consumo médio) + grade de métricas neutra + card
//  "Último abastecimento" (padrão Saúde — disciplina, não decoração). A ação
//  nº 1 — abastecer — fica a um toque pelo "+" na toolbar (padrão Saúde/Wallet);
//  estado de manutenção só aparece como aviso quando vencido (silêncio = ok).
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    @State private var selectedID: PersistentIdentifier?
    @State private var showingFuelLog = false
    @State private var showingAddMoto = false

    /// Moto exibida: a selecionada, ou a primeira disponível.
    private var motorcycle: Motorcycle? {
        if let id = selectedID, let m = motorcycles.first(where: { $0.persistentModelID == id }) {
            return m
        }
        return motorcycles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let moto = motorcycle {
                    dashboard(for: moto)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Resumo")
            .toolbar {
                if let moto = motorcycle {
                    ToolbarItem(placement: .topBarTrailing) {
                        bikeControl(for: moto)
                    }
                }
            }
            .sheet(isPresented: $showingFuelLog) {
                if let moto = motorcycle {
                    FuelLogFormView(motorcycle: moto)
                }
            }
            .sheet(isPresented: $showingAddMoto) {
                MotorcycleFormView()
            }
            .onChange(of: selectedID) { Haptics.selection() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nenhuma moto", systemImage: "motorcycle")
        } description: {
            Text("Cadastre sua moto para acompanhar consumo e manutenção.")
        } actions: {
            Button("Cadastrar moto") { showingAddMoto = true }
                .buttonStyle(.borderedProminent)
        }
    }

    /// Controle "duplo" no topo-direito (padrão app Bolsa: busca | •••):
    /// à esquerda, a ação nº1 (abastecer) a UM toque; à direita, o menu de
    /// contexto da moto (trocar / adicionar). Os dois zonas dividem uma só
    /// cápsula, separadas por um divisor.
    private func bikeControl(for moto: Motorcycle) -> some View {
        HStack(spacing: 0) {
            // Zona 1 — ação direta: abastecer.
            Button {
                showingFuelLog = true
            } label: {
                Image(systemName: "fuelpump.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 20)

            // Zona 2 — menu de contexto: trocar / adicionar moto. Só o modelo
            // (compacto); nome completo no menu.
            Menu {
                Picker("Moto", selection: Binding(
                    get: { motorcycle?.persistentModelID },
                    set: { selectedID = $0 }
                )) {
                    ForEach(motorcycles) { m in
                        Text(m.displayName).tag(Optional(m.persistentModelID))
                    }
                }

                Divider()

                Button {
                    showingAddMoto = true
                } label: {
                    Label("Adicionar moto", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "motorcycle")
                    Text(moto.model)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func dashboard(for moto: Motorcycle) -> some View {
        let summary = moto.consumptionSummary
        let status = moto.oilChangeStatus()
        // Segmentos full-to-full, mais antigo → mais novo (para o mini-gráfico do card).
        let segments = ConsumptionCalculator
            .segments(from: moto.fuelLogs.map(\.asFuelEntry))
            .sorted { $0.endDate < $1.endDate }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if summary.segmentCount > 0 {
                    NavigationLink {
                        ConsumptionChartView(motorcycle: moto)
                    } label: {
                        consumptionCard(summary, segments: segments)
                    }
                    .buttonStyle(.plain)
                } else {
                    consumptionCard(summary, segments: [])
                }

                if let status, status.isOverdue {
                    overdueWarning
                }

                metricsGrid(summary, moto: moto)

                if let status {
                    sectionTitle("Próxima manutenção")
                    maintenanceCard(status)
                }

                sectionTitle("Último abastecimento")
                lastFuelLogCard(moto)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Blocos

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Aviso de manutenção só quando há algo a fazer (padrão Apple: estado "ok"
    /// é silêncio, não banner). Texto secundário, sem faixa colorida de fundo.
    private var overdueWarning: some View {
        Label("Troca de óleo vencida", systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Card de Consumo no padrão Saúde "Energia Ativa": cabeçalho com ícone +
    /// chevron, **frase-manchete** que interpreta o dado (a alma do card Saúde),
    /// e um gráfico de barras (km/l por segmento) com a linha de média
    /// atravessando. Card inteiro toca → tela Consumo cheia. Com < 2 segmentos
    /// não há gráfico (anti-Apple), só a manchete/dica.
    @ViewBuilder
    private func consumptionCard(_ summary: ConsumptionSummary, segments: [ConsumptionSegment]) -> some View {
        let hasChart = segments.count >= 2
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                // Cabeçalho do card (estilo Saúde): ícone + título + chevron.
                HStack(spacing: 6) {
                    Image(systemName: "fuelpump.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text("Consumo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    if !segments.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Manchete que conta a história (padrão Saúde): frase grande em
                // negrito, com o número km/l destacado no meio do texto.
                consumptionHeadline(summary.averageKmPerLiter, segments: segments)

                if hasChart {
                    Divider()
                    consumptionMiniChart(segments, average: summary.averageKmPerLiter)
                }
            }
        }
    }

    /// Frase-manchete do card (estilo "Você queimou uma média de 161 cal/dia…").
    private func consumptionHeadline(_ average: Double?, segments: [ConsumptionSegment]) -> some View {
        Group {
            if let average {
                let value = average.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale))
                Text("Sua moto faz em média ")
                    + Text(value).fontWeight(.bold).monospacedDigit()
                    + Text(" km/l").fontWeight(.bold)
                    + Text(headlinePeriodSuffix(segments))
            } else {
                Text("Registre dois abastecimentos com tanque cheio para medir o consumo.")
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Sufixo temporal da manchete ("nos últimos meses" / "neste período").
    private func headlinePeriodSuffix(_ segments: [ConsumptionSegment]) -> String {
        guard let first = segments.first?.endDate, let last = segments.last?.endDate else { return "." }
        let months = Calendar.current.dateComponents([.month], from: first, to: last).month ?? 0
        return months >= 1 ? " nos últimos meses." : "."
    }

    /// Mini-gráfico do card: barras uniformes e juntas (km/l por segmento), uma
    /// por posição (não por data real) — igual ao "Energia Ativa" do Saúde, onde
    /// as barras têm espaçamento igual. A linha de média (a manchete) atravessa.
    /// Eixo X rotula os meses dos segmentos. Sem eixo Y (o herói dá a escala).
    private func consumptionMiniChart(_ segments: [ConsumptionSegment], average: Double?) -> some View {
        // Rótulo de mês por posição: só mostra quando o mês muda (evita repetir).
        let monthLabels: [Int: String] = {
            var out: [Int: String] = [:]
            var lastMonth = -1
            let cal = Calendar.current
            for (i, seg) in segments.enumerated() {
                let m = cal.component(.month, from: seg.endDate)
                if m != lastMonth {
                    out[i] = seg.endDate.formatted(.dateTime.month(.abbreviated).locale(AppFormat.locale))
                    lastMonth = m
                }
            }
            return out
        }()

        // Topo do eixo Y: um respiro acima da maior barra/média (baseline = 0,
        // senão barras quase iguais viram slivers invisíveis).
        let maxY = (segments.map(\.kmPerLiter) + [average ?? 0]).max() ?? 1
        return Chart {
            // Barras neutras em posição uniforme; a média é a manchete (Saúde).
            // X categórico (String do índice) → espaçamento igual, não escala por data.
            ForEach(Array(segments.enumerated()), id: \.offset) { index, seg in
                BarMark(
                    x: .value("Segmento", String(index)),
                    y: .value("km/l", seg.kmPerLiter),
                    width: .ratio(0.62)
                )
                .foregroundStyle(Color(.systemGray3))
                .cornerRadius(3)
            }
            if let average {
                RuleMark(y: .value("Média", average))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(.tint)
            }
        }
        .chartYScale(domain: 0...(maxY * 1.15))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: monthLabels.keys.sorted().map(String.init)) { value in
                AxisValueLabel {
                    if let s = value.as(String.self), let i = Int(s), let label = monthLabels[i] {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 120)
    }

    private func metricsGrid(_ summary: ConsumptionSummary, moto: Motorcycle) -> some View {
        // Ícones neutros (.secondary): cor reservada a sinal real, não decoração.
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(label: "Custo por km",
                       value: summary.costPerKm.map(AppFormat.currency) ?? "—",
                       systemImage: "brazilianrealsign.circle")
            MetricTile(label: "Distância medida",
                       value: AppFormat.km(summary.totalDistance),
                       systemImage: "ruler")
            MetricTile(label: "Hodômetro",
                       value: AppFormat.km(moto.currentOdometer),
                       systemImage: "gauge.with.dots.needle.bottom.50percent")
            MetricTile(label: "Abastecimentos",
                       value: moto.fuelLogs.count.formatted(),
                       systemImage: "fuelpump")
        }
    }

    private func maintenanceCard(_ status: OilChangeStatus) -> some View {
        GroupedCard {
            VStack(spacing: 10) {
                LabeledContent("Próxima troca de óleo") {
                    Text(AppFormat.km(status.dueMileage)).monospacedDigit()
                }
                Divider()
                if status.isOverdue {
                    LabeledContent("Situação") {
                        Text("Vencida").foregroundStyle(.orange).fontWeight(.semibold)
                    }
                } else {
                    LabeledContent("Faltam") {
                        Text(AppFormat.km(status.kmRemaining)).monospacedDigit()
                    }
                }
                Divider()
                LabeledContent("Prevista para") {
                    Text(AppFormat.date(status.dueDate))
                }
            }
        }
    }

    @ViewBuilder
    private func lastFuelLogCard(_ moto: Motorcycle) -> some View {
        if let last = moto.latestFuelLog {
            NavigationLink {
                FuelLogListView(motorcycle: moto)
            } label: {
                GroupedCard {
                    HStack(spacing: 12) {
                        IconTile(systemName: "fuelpump.fill", tint: .green, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppFormat.dateTime(last.date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let place = last.placeLabel {
                                Text(place)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(AppFormat.km(last.odometer))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppFormat.currency(last.totalCost))
                                .font(.headline)
                                .monospacedDigit()
                            Text(AppFormat.liters(last.liters))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            // Estado vazio acionável: no onboarding (sem registros), a ação nº1
            // ganha proeminência aqui — depois do 1º registro some, restando só
            // o "+" no toolbar (calma para o uso recorrente).
            Button {
                showingFuelLog = true
            } label: {
                GroupedCard {
                    HStack(spacing: 12) {
                        IconTile(systemName: "fuelpump.fill", tint: .green, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Registrar primeiro abastecimento")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Toque para começar a acompanhar o consumo.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Motorcycle.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let moto = Motorcycle(make: "Honda", model: "CB 500", year: 2022,
                          country: "Brasil", currentOdometer: 21_800)
    container.mainContext.insert(moto)

    // 6 cheios → 5 segmentos full-to-full → gráfico do card Consumo aparece.
    let base = Date()
    let day = 86_400.0
    let cheios: [(Double, Double, Double, Double)] = [   // (kmAtrás, odômetro, litros, custo)
        (150, 20_000, 12.0, 72),
        (120, 20_420, 11.5, 69),
        (90,  20_870, 12.2, 73),
        (60,  21_290, 11.8, 71),
        (30,  21_540, 12.5, 75),
        (0,   21_800, 11.9, 72),
    ]
    for (daysAgo, odo, liters, cost) in cheios {
        let log = FuelLog(date: base.addingTimeInterval(-daysAgo * day),
                          odometer: odo, liters: liters, totalCost: cost,
                          fuelType: .gasolinaComum, isFullTank: true, motorcycle: moto)
        container.mainContext.insert(log)
    }

    return DashboardView()
        .modelContainer(container)
}
