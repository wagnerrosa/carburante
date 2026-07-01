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
    /// Dispara a navegação para a tela Consumo (tap no card de consumo ou comparação).
    @State private var showingConsumption = false
    /// Navega para a manutenção a partir do checklist de ativação.
    @State private var showingMaintenance = false
    /// IDs das motos cujo checklist de ativação foi dispensado pelo usuário,
    /// como CSV de UUIDs (AppStorage não guarda Set). Dismiss é POR MOTO: fechar
    /// numa moto não esconde nas outras, e cada moto nova reaparece com o guia.
    @AppStorage("activationChecklistDismissedIDs") private var dismissedChecklistIDsCSV: String = ""

    private var dismissedChecklistIDs: Set<String> {
        Set(dismissedChecklistIDsCSV.split(separator: ",").map(String.init))
    }

    private func dismissChecklist(for moto: Motorcycle) {
        var ids = dismissedChecklistIDs
        ids.insert(moto.id.uuidString)
        dismissedChecklistIDsCSV = ids.sorted().joined(separator: ",")
    }

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
            .onAppear { trackDashboard() }
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
            .onChange(of: activeMotorcycleID) { _, newID in
                Haptics.selection()
                // Só conta como troca real quando há mais de uma moto (ignora o
                // set inicial / cadastro da 1ª). Categoria da moto-destino revela
                // que tipo de uso o multi-moto alterna.
                guard motorcycles.count > 1 else { return }
                let to = motorcycles.first { $0.id.uuidString == newID }
                Analytics.motorcycleSwitched(bikeCount: motorcycles.count,
                                             toCategory: to?.category)
            }
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
            Button {
                showingAddMoto = true
            } label: {
                Label("Cadastrar moto", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
        let statuses = moto.maintenanceStatuses()
        // Segmentos full-to-full, mais antigo → mais novo (para o mini-gráfico do card).
        let segments = ConsumptionCalculator
            .segments(from: moto.fuelLogs.map(\.asFuelEntry))
            .sorted { $0.endDate < $1.endDate }

        let reference = moto.categoryReferenceKmPerLiter
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let steps = activationSteps(for: moto) {
                    ActivationChecklist(steps: steps) {
                        withAnimation { dismissChecklist(for: moto) }
                    }
                }

                if summary.segmentCount > 0 {
                    Button { showingConsumption = true } label: {
                        consumptionCard(summary, segments: segments, moto: moto)
                    }
                    .buttonStyle(.plain)
                } else {
                    consumptionCard(summary, segments: [], moto: moto)
                }

                metricsGrid(summary, moto: moto)

                // Comparação com a categoria abaixo da grade de métricas (bloco
                // próprio, descoberta clara). Só quando há referência e consumo
                // medido. Tap → tela Consumo cheia.
                if let reference, summary.segmentCount > 0 {
                    Button { showingConsumption = true } label: {
                        categoryComparisonCard(summary, reference: reference)
                    }
                    .buttonStyle(.plain)
                }

                if let next = statuses.first {
                    sectionTitle("Próxima manutenção")
                    maintenanceCard(next, moto: moto)
                    // Card-herói = item mais urgente. Se ≥2 itens precisam de
                    // atenção, uma linha discreta leva ao restante (sem empilhar
                    // cards — dashboard calmo, disclosure progressivo).
                    let attention = statuses.filter(MaintenanceReminder.isAttention).count
                    if attention >= 2 {
                        moreMaintenanceLine(attention - 1, moto: moto)
                    }
                }

                sectionTitle("Último abastecimento")
                lastFuelLogCard(moto)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $showingConsumption) {
            ConsumptionChartView(motorcycle: moto)
        }
        .navigationDestination(isPresented: $showingMaintenance) {
            MaintenanceListView(motorcycle: moto)
        }
    }

    /// Já emitiu consumption_waiting_shown nesta exibição da tela? (1×/sessão).
    @State private var trackedWaiting = false

    /// Analytics do Resumo: ativação (1×/passo/moto) + estado de espera do
    /// consumo (full-to-full). Sem dado sensível — só bools e a contagem 1|2.
    private func trackDashboard() {
        guard let moto = motorcycle else { return }
        ActivationTracker.sync(
            bikeID: moto.id,
            fuel: !moto.fuelLogs.isEmpty,
            maintenance: !moto.maintenanceLogs.isEmpty,
            consumption: moto.consumptionSummary.segmentCount > 0
        )
        let remaining = moto.fullTanksUntilConsumption
        if remaining > 0, !trackedWaiting {
            trackedWaiting = true
            Analytics.consumptionWaitingShown(tanksRemaining: remaining)
        }
    }

    // MARK: - Checklist de ativação (primeiros passos)

    /// Passos do checklist derivados dos dados reais da moto, ou nil quando não
    /// deve aparecer (dispensado, ou todos concluídos → some sozinho). Cada passo
    /// pendente leva à ação que o conclui. Fonte de verdade: PLAN/onboarding.md.
    private func activationSteps(for moto: Motorcycle) -> [ActivationStep]? {
        guard !dismissedChecklistIDs.contains(moto.id.uuidString) else { return nil }

        let hasFuel = !moto.fuelLogs.isEmpty
        let hasMaintenance = !moto.maintenanceLogs.isEmpty
        let hasConsumption = moto.consumptionSummary.segmentCount > 0

        // 1ª moto cadastrada = a mais antiga (query ordena createdAt desc → last).
        // Só ela mostra o passo "Cadastre sua primeira moto"; motos seguintes já
        // existem, então o checklist começa no abastecimento.
        let isFirstBike = motorcycles.last?.id == moto.id

        var steps: [ActivationStep] = []
        if isFirstBike {
            // Já existe moto para chegar aqui → passo sempre concluído.
            steps.append(ActivationStep(title: "Cadastre sua primeira moto", isDone: true, action: nil))
        }
        steps.append(contentsOf: [
            ActivationStep(title: "Registre seu primeiro abastecimento",
                           isDone: hasFuel,
                           action: { showingFuelLog = true }),
            ActivationStep(title: "Registre uma manutenção",
                           isDone: hasMaintenance,
                           action: { showingMaintenance = true }),
            // Consumo aparece sozinho (não é uma ação direta) → leva à tela Consumo
            // só depois de existir, para o usuário ver o resultado.
            ActivationStep(title: "Veja seu primeiro consumo",
                           isDone: hasConsumption,
                           action: hasConsumption ? { showingConsumption = true } : nil),
        ])
        // Todos concluídos → some.
        return steps.allSatisfy(\.isDone) ? nil : steps
    }

    // MARK: - Card de comparação com a categoria

    /// Card de comparação com a categoria no padrão Saúde "Energia Ativa":
    /// cabeçalho ícone+título+chevron, **manchete interpretativa** (a frase do
    /// delta é o herói), divisor, e duas barras GROSSAS empilhadas — número grande
    /// acima de cada uma, rótulo embutido DENTRO da barra (ano no print do Saúde),
    /// preenchimento proporcional à escala comum. Tap → tela Consumo cheia.
    private func categoryComparisonCard(_ summary: ConsumptionSummary, reference: Double) -> some View {
        let mine = summary.averageKmPerLiter
        let delta = mine.map { ($0 - reference) / reference }
        let scale = max(mine ?? 0, reference)
        let themeColor = motorcycle?.themeColor ?? BrandTheme.default
        return GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                // Cabeçalho (estilo Saúde): ícone + título + chevron, na cor do tema.
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text("Comparação com a categoria")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                // Manchete que interpreta o dado (a alma do card Saúde).
                if let delta {
                    comparisonHeadline(delta)
                }

                Divider()

                // Barras grossas com rótulo embutido — sua moto (tema) e a média
                // da categoria (cinza), na MESMA escala.
                VStack(alignment: .leading, spacing: 14) {
                    categoryBar(label: "Sua moto", value: mine, scale: scale,
                                fill: themeColor, embeddedLabelColor: .white)
                    categoryBar(label: "Média da categoria", value: reference, scale: scale,
                                fill: Color(.systemGray4), embeddedLabelColor: .primary)
                }

                Text("Estimativa da categoria. Em breve: seu histórico e outros pilotos da mesma moto.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Manchete grande do card (estilo "Você está queimando menos calorias…").
    private func comparisonHeadline(_ delta: Double) -> some View {
        let pct = abs(delta * 100).formatted(.number.precision(.fractionLength(0)).locale(AppFormat.locale))
        let text: String = {
            if delta > 0.05 {
                return "Sua moto faz \(pct)% a mais que a média da categoria."
            } else if delta < -0.05 {
                return "Sua moto faz \(pct)% a menos que a média da categoria."
            } else {
                return "Sua moto está na média da categoria."
            }
        }()
        return Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Uma barra do card no padrão "Energia Ativa": número grande (title) acima,
    /// e barra grossa preenchida proporcionalmente com o rótulo embutido à esquerda
    /// (dentro da parte preenchida quando há espaço; o ano no print do Saúde).
    private func categoryBar(label: String, value: Double?, scale: Double, fill: Color, embeddedLabelColor: Color) -> some View {
        let frac = scale > 0 ? (value ?? 0) / scale : 0
        return VStack(alignment: .leading, spacing: 2) {
            // Número grande SEM bold, fonte SF padrão (não rounded) — igual ao
            // Saúde, que usa peso regular nos big numbers.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value.map { $0.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale)) } ?? "—")
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("km/l")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let w = max(geo.size.width * frac, frac > 0 ? 40 : 0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray6))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fill)
                        .frame(width: w)
                        .overlay(alignment: .leading) {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(embeddedLabelColor)
                                .lineLimit(1)
                                .padding(.leading, 10)
                        }
                }
            }
            .frame(height: 26)
        }
    }

    // MARK: - Blocos

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Quantos segmentos um gráfico precisa para parecer "cheio" (padrão Saúde:
    /// nunca 2-3 barras tortas). Abaixo disso o card mostra só a manchete + número
    /// — o visual calmo que o usuário aprovou (sem gráfico ralo).
    private static let minBarsForChart = 6
    /// Teto de barras no mini-gráfico do card: só os segmentos mais recentes
    /// (tendência atual). Acima disso fica apertado e os rótulos de mês cortam.
    /// A tela Consumo cheia (período + scrub) mostra o histórico completo.
    private static let maxBarsInCard = 6
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
    private func consumptionCard(_ summary: ConsumptionSummary, segments: [ConsumptionSegment], moto: Motorcycle) -> some View {
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
                consumptionHeadline(summary.averageKmPerLiter, segments: segments,
                                    tanksUntilReading: moto.fullTanksUntilConsumption)

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
    /// Sem consumo medido ainda, a frase explica QUANTOS cheios faltam (contagem
    /// dinâmica) — o usuário nunca fica sem saber por que ainda não há km/l.
    private func consumptionHeadline(_ average: Double?, segments: [ConsumptionSegment],
                                     tanksUntilReading: Int) -> some View {
        Group {
            if let average {
                let value = average.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale))
                Text("Sua moto faz em média ")
                    + Text(value).fontWeight(.bold).monospacedDigit()
                    + Text(" km/l").fontWeight(.bold)
                    + Text(headlinePeriodSuffix(segments))
            } else if tanksUntilReading <= 1 {
                Text("Falta ") + Text("1 abastecimento cheio").fontWeight(.bold)
                    + Text(" para medir o consumo da sua moto.")
            } else {
                Text("Registre ") + Text("2 abastecimentos com tanque cheio").fontWeight(.bold)
                    + Text(" para medir o consumo da sua moto.")
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
        // Com muitos segmentos os meses ficam grudados (ex.: "out.nov.dez.jan."),
        // então desbasta para no máximo `maxLabels` rótulos uniformemente espaçados.
        let monthLabels: [Int: String] = {
            // 1) candidatos = 1º segmento de cada mês.
            var candidates: [(index: Int, label: String)] = []
            var lastMonth = -1
            let cal = Calendar.current
            for (i, seg) in segments.enumerated() {
                let m = cal.component(.month, from: seg.endDate)
                if m != lastMonth {
                    candidates.append((i, seg.endDate.formatted(.dateTime.month(.abbreviated).locale(AppFormat.locale))))
                    lastMonth = m
                }
            }
            // 2) desbaste: mantém ~maxLabels, pulando candidatos uniformemente.
            let maxLabels = 6
            let stride = max(1, Int(ceil(Double(candidates.count) / Double(maxLabels))))
            var out: [Int: String] = [:]
            for (n, c) in candidates.enumerated() where n % stride == 0 {
                out[c.index] = c.label
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
            // `collisionResolution: .disabled` + `.fixedSize()` impedem o Charts de
            // espremer o rótulo na banda estreita da barra (era o corte "a..."/"o...").
            // `centered` alinha o texto sob a barra do mês.
            AxisMarks(preset: .aligned, values: monthLabels.keys.sorted().map(String.init)) { value in
                AxisValueLabel(centered: true, collisionResolution: .disabled) {
                    if let s = value.as(String.self), let i = Int(s), let label = monthLabels[i] {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color(.secondaryLabel))
                            .fixedSize()
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
        // Folga à direita p/ o último rótulo de mês não cortar na borda do card
        // (com collisionResolution desligada o texto transborda a banda da barra).
        .padding(.trailing, 12)
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

    /// Cor semântica aparece apenas quando há atenção necessária. Em dia, o
    /// indicador segue o tema da moto; perto do prazo fica laranja e, vencido,
    /// vermelho.
    private func maintenanceColor(_ status: MaintenanceStatus, moto: Motorcycle) -> Color {
        if status.isOverdue { return .red }
        return status.progress >= 0.8 ? .orange : moto.themeColor
    }

    /// Card compacto do tipo mais urgente: status/prazo como apoio; a barra de
    /// progresso (km ou tempo, o que estiver mais perto) é o elemento principal.
    private func maintenanceCard(_ status: MaintenanceStatus, moto: Motorcycle) -> some View {
        let color = maintenanceColor(status, moto: moto)

        return NavigationLink {
            MaintenanceListView(motorcycle: moto)
        } label: {
            GroupedCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: status.type.icon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(color)
                        Text(status.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(maintenanceStatusTitle(status))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(status.isOverdue ? color : .primary)
                                .monospacedDigit()
                            let due = maintenanceDueText(status)
                            if !due.isEmpty {
                                Text(due)
                                    .font(.caption)
                                    .foregroundStyle(status.isOverdue ? color : .secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        let trailing = maintenanceTrailingText(status)
                        if status.isOverdue, !trailing.isEmpty {
                            Text(trailing)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color)
                                .monospacedDigit()
                        }
                    }

                    VStack(spacing: 6) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.quaternaryLabel))
                                Capsule()
                                    .fill(color)
                                    .frame(width: proxy.size.width * status.progress)
                            }
                        }
                        .frame(height: 6)
                        .accessibilityHidden(true)

                        maintenanceAnchors(status)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
        .accessibilityValue(maintenanceAccessibilityValue(status))
        .accessibilityHint("Abre o histórico de manutenções")
    }

    /// Linha discreta de "mais N itens precisam de atenção" sob o card-herói.
    private func moreMaintenanceLine(_ count: Int, moto: Motorcycle) -> some View {
        NavigationLink {
            MaintenanceListView(motorcycle: moto)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(count == 1
                     ? "Mais 1 item precisa de atenção"
                     : "Mais \(count) itens precisam de atenção")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    /// Âncoras da barra: por km quando o tipo tem eixo km; senão por data.
    @ViewBuilder
    private func maintenanceAnchors(_ status: MaintenanceStatus) -> some View {
        if let due = status.dueMileage {
            HStack {
                Text("Última \(AppFormat.km(status.lastMileage))")
                Spacer()
                Text("Próxima \(AppFormat.km(due))")
            }
        } else if let due = status.dueDate {
            HStack {
                Text("Última \(AppFormat.date(status.lastDate))")
                Spacer()
                Text("Próxima \(AppFormat.date(due))")
            }
        }
    }

    private func maintenanceAccessibilityValue(_ status: MaintenanceStatus) -> String {
        [maintenanceStatusTitle(status), maintenanceDueText(status)]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    /// Linha principal (negrito) e apoio: compartilhadas com a lista (`MaintenanceStatus`).
    private func maintenanceStatusTitle(_ status: MaintenanceStatus) -> String { status.remainingShort }
    private func maintenanceDueText(_ status: MaintenanceStatus) -> String { status.dueDescription }

    /// Ênfase à direita quando vencida (km além ou dias em atraso).
    private func maintenanceTrailingText(_ status: MaintenanceStatus) -> String {
        if let km = status.kmRemaining, km < 0 {
            return "\(AppFormat.km(abs(km))) além"
        }
        if let date = status.dueDate, status.isOverdue {
            let days = overdueDays(since: date)
            if days == 0 { return "Prazo hoje" }
            return days == 1 ? "1 dia em atraso" : "\(days) dias em atraso"
        }
        return ""
    }

    private func overdueDays(since dueDate: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0, 0)
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
                            Text("O consumo aparece após 2 abastecimentos com tanque cheio.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
