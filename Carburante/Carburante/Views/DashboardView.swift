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
    /// Moto ativa, persistida entre sessões (UUID estável). Fonte única que
    /// também define o tema global — ver RootTabView.
    @AppStorage("activeMotorcycleID") private var activeMotorcycleID: String = ""
    @State private var showingFuelLog = false
    @State private var showingAddMoto = false

    /// Moto exibida: a ativa (persistida), ou a primeira disponível.
    private var motorcycle: Motorcycle? {
        if let m = motorcycles.first(where: { $0.id.uuidString == activeMotorcycleID }) {
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
            .onChange(of: activeMotorcycleID) { Haptics.selection() }
        }
        // Tema da moto ativa tinge a aba Resumo (CTA, controles, gráfico, links).
        .tint(motorcycle?.themeColor ?? BrandTheme.default)
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
                    get: { motorcycle?.id.uuidString ?? "" },
                    set: { activeMotorcycleID = $0 }
                )) {
                    ForEach(motorcycles) { m in
                        Text(m.displayName).tag(m.id.uuidString)
                    }
                }

                Divider()

                Button {
                    showingAddMoto = true
                } label: {
                    Label("Adicionar moto", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    if let logo = moto.logoAsset {
                        BrandLogoTile(assetName: logo, size: 22)
                    } else {
                        Image(systemName: "motorcycle")
                    }
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

    /// Quantos segmentos um gráfico precisa para parecer "cheio" (padrão Saúde:
    /// nunca 2-3 barras tortas). Abaixo disso o card mostra só a manchete + número
    /// — o visual calmo que o usuário aprovou (sem gráfico ralo).
    private static let minBarsForChart = 6
    /// Teto de barras no mini-gráfico do card: além disso fica apertado. A tela
    /// Consumo cheia (com período e scrub) mostra o histórico completo.
    private static let maxBarsInCard = 12
    /// Vão vazio à esquerda do gráfico onde cabe o rótulo de média + número, com
    /// folga até as barras (gap do padrão Saúde).
    private static let avgLabelGutter: CGFloat = 110

    /// Card de Consumo no padrão Saúde "Energia Ativa": cabeçalho com ícone +
    /// chevron, **frase-manchete** que interpreta o dado (a alma do card Saúde),
    /// e um gráfico de barras (km/l por segmento) com o rótulo de média à esquerda
    /// e a linha de média atravessando — igual ao print do Saúde. Card inteiro
    /// toca → tela Consumo cheia. Com < `minBarsForChart` segmentos não há gráfico
    /// (anti-Apple: barras tortas), só a manchete/dica.
    @ViewBuilder
    private func consumptionCard(_ summary: ConsumptionSummary, segments: [ConsumptionSegment]) -> some View {
        let hasChart = segments.count >= Self.minBarsForChart
        // Mostra só as barras mais recentes (as mais relevantes p/ tendência atual).
        let barSegments = Array(segments.suffix(Self.maxBarsInCard))
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
                    // Média das barras visíveis (não a global) — a linha tem de bater
                    // com o que está desenhado.
                    let visibleAverage = barsWeightedAverage(barSegments)
                    consumptionMiniChart(barSegments, average: visibleAverage)
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

    /// Média ponderada (distância ÷ litros) dos segmentos dados — mesma
    /// metodologia do `ConsumptionCalculator`, não a média simples das barras.
    private func barsWeightedAverage(_ segments: [ConsumptionSegment]) -> Double? {
        let liters = segments.reduce(0) { $0 + $1.liters }
        let distance = segments.reduce(0) { $0 + $1.distance }
        return liters > 0 ? distance / liters : nil
    }

    /// Mini-gráfico do card no padrão Saúde "Energia Ativa": barras (km/l por
    /// segmento) nascendo do chão (baseline 0, inteiras) + linha de média
    /// atravessando, e — sobreposto sobre a área vazia à esquerda — o rótulo de
    /// média ("Média de km/l" + número grande) com o número grudado **na linha**
    /// (igual ao Saúde: rótulo acima da linha, número logo abaixo). Eixo X rotula
    /// os meses. Sem eixo Y (o número dá a escala). Barras cinza, linha colorida.
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

        let avg = average ?? (segments.map(\.kmPerLiter).reduce(0, +) / Double(max(segments.count, 1)))
        // Baseline = 0 (barras inteiras, do chão — padrão Saúde). Topo: respiro
        // acima da maior barra/média. A linha de média cai naturalmente em avg/top.
        let top = ((segments.map(\.kmPerLiter) + [avg]).max() ?? 1) * 1.15

        let avgLabel = average.map {
            $0.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale))
        }

        return Chart {
            // Ordem do padrão Saúde: a linha de média (cor CHEIA, uniforme) é desenhada
            // PRIMEIRO → fica embaixo; as barras vêm DEPOIS, por cima dela, e são
            // semi-transparentes → onde a barra cruza a linha, a faixa colorida aparece
            // através da barra (a barra escurece, a linha não muda de cor). `.tint`
            // segue o tema da marca.
            if average != nil {
                RuleMark(y: .value("Média", avg))
                    .lineStyle(StrokeStyle(lineWidth: 5, lineCap: .round))
                    .foregroundStyle(.tint)
            }
            // X categórico (String do índice) → espaçamento igual, não escala por data.
            ForEach(Array(segments.enumerated()), id: \.offset) { index, seg in
                BarMark(
                    x: .value("Segmento", String(index)),
                    y: .value("km/l", seg.kmPerLiter),
                    width: .ratio(0.62)
                )
                .foregroundStyle(Color(.systemGray3).opacity(0.55))
                .cornerRadius(3)
            }
        }
        .chartYScale(domain: 0...top)
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
        // Rótulo de média no vão à esquerda, fora do plot. O plot é full-width (eixo
        // X alinha com as barras); o gutter vem do `.padding(.leading)` no Chart todo,
        // e o rótulo escapa para dentro dele com offset negativo. Número cravado na
        // altura da linha + linha estendida pelo vão = leitura do Saúde.
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let avgLabel, let plot = proxy.plotFrame {
                    let frame = geo[plot]
                    let lineY = frame.minY + (proxy.position(forY: avg) ?? 0)
                    // Distância do topo do bloco até a linha de média. A linha passa no
                    // vão entre "Média de" e o número, com respiro dos dois lados (igual
                    // Saúde): altura do rótulo (~16) + metade do espaço entre as linhas.
                    let labelH: CGFloat = 24

                    // Linha de média estendida pelo vão (RuleMark só cobre as barras).
                    // Capsule (pontas arredondadas) p/ casar com o lineCap .round do
                    // RuleMark. `.tint` = tema da marca.
                    Capsule()
                        .fill(.tint)
                        .frame(width: Self.avgLabelGutter, height: 5)
                        .position(x: frame.minX, y: lineY)
                        .offset(x: -Self.avgLabelGutter / 2)

                    // Espaço entre "Média de" e o número — a linha de média passa no
                    // meio dele, com respiro dos dois lados (padrão Saúde).
                    VStack(alignment: .leading, spacing: 10) {
                        // Rótulo "Média de" + número e unidade na MESMA linha ("30,6 km/l"),
                        // padrão Saúde "Média de Calorias / 161 cal". Rótulo e unidade na
                        // MESMA fonte (.subheadline secondary); número grande title rounded.
                        Text("Média de")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(avgLabel)
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text("km/l")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize()
                    // Topo do bloco acima da linha → o número fica cravado na linha de
                    // média; "Média de" acima (igual Saúde: linha entre rótulo e número).
                    .padding(.top, max(lineY - labelH, 0))
                    // Escapa para o vão à esquerda do plot (criado pelo padding abaixo).
                    .offset(x: -Self.avgLabelGutter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        // Cria o vão à esquerda empurrando o gráfico todo (plot + eixo juntos →
        // eixo X continua alinhado às barras, ao contrário de chartPlotStyle).
        .padding(.leading, Self.avgLabelGutter)
        .frame(height: 184)
    }

    private func metricsGrid(_ summary: ConsumptionSummary, moto: Motorcycle) -> some View {
        // Séries de tendência para as sparklines (estilo Fitness). Custo/km e
        // preço/L têm tendência útil; gasto/mês idem. Hodômetro só sobe → sem
        // sparkline (linha reta crescente não informa nada — anti-Fitness).
        let expense = moto.monthlyExpenseSeries()
        // Número = km do mês-civil atual; barras = km por SEMANA (densas, estilo
        // Fitness) com grid + rótulos de mês. Hodômetro absoluto saiu da grade
        // (estado da moto; segue no perfil e no card de último abastecimento).
        let distanceThisMonth = moto.distanceThisMonth()
        let weeklyBars = moto.weeklyDistanceSeries()
        // Sem ícones (padrão Fitness: mini-cards de estatística não usam ícone —
        // só número grande + rótulo + mini-gráfico).
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(label: "Custo por km",
                       value: summary.costPerKm.map(AppFormat.currency) ?? "—",
                       sparkline: moto.costPerKmSeries)
            MetricTile(label: "Gasto este mês",
                       value: AppFormat.currency(expense.last?.total ?? 0),
                       sparkline: expense.map(\.total))
            MetricTile(label: "Rodados este mês",
                       value: AppFormat.km(distanceThisMonth),
                       distanceBars: weeklyBars)
            MetricTile(label: "Preço médio/L",
                       value: moto.averagePricePerLiter.map(AppFormat.currency) ?? "—",
                       sparkline: moto.pricePerLiterSeries)
        }
    }

    /// Cor do anel de óleo por progresso (padrão semáforo do Fitness): verde
    /// folgado → laranja perto → vermelho vencido. Semântica (NÃO segue o tema
    /// da marca): é sinal de estado, não decoração.
    private func oilRingColor(_ status: OilChangeStatus) -> Color {
        if status.isOverdue { return .red }
        return status.progress >= 0.8 ? .orange : .green
    }

    /// Card de manutenção no estilo Activity Rings do Fitness: anel de progresso
    /// (km rodados rumo aos 3.000) à esquerda, com o nº de km no miolo, e o
    /// resumo (faltam / vencida + data prevista) à direita.
    private func maintenanceCard(_ status: OilChangeStatus) -> some View {
        let color = oilRingColor(status)
        return GroupedCard {
            HStack(spacing: 16) {
                Gauge(value: status.progress) {
                    EmptyView()
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Text(AppFormat.odometer(status.kmIntoInterval))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text("km")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(color)
                .scaleEffect(1.1)
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    if status.isOverdue {
                        Label("Troca de óleo vencida", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                    } else {
                        Text("Faltam \(AppFormat.km(status.kmRemaining))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("até a próxima troca de óleo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Prevista para \(AppFormat.date(status.dueDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
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
                        IconTile(systemName: "fuelpump.fill", size: 38)
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
                        IconTile(systemName: "fuelpump.fill", size: 38)
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

    // 7 cheios → 6 segmentos full-to-full → atinge o mínimo p/ o gráfico do card
    // Consumo aparecer (Self.minBarsForChart). km/l varia entre os segmentos.
    let base = Date()
    let day = 86_400.0
    let cheios: [(Double, Double, Double, Double)] = [   // (kmAtrás, odômetro, litros, custo)
        (180, 19_600, 11.0, 66),
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
