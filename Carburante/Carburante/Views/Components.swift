//
//  Components.swift
//  Carburante
//
//  Componentes nativos reaproveitados (Fase 11 — refinamento UI):
//  tile de ícone colorido (padrão Ajustes), mini-card de métrica (padrão
//  Esportes/Fitness) e card agrupado. Sem libs externas, sem sombras custom —
//  só hierarquia, SF Symbols e cores semânticas (cor = sinal, não decoração).
//

import SwiftUI
import Charts

/// Tile de ícone colorido à esquerda de uma linha (padrão Ajustes/Casa).
/// `tint` nil → usa a accent color do ambiente (o tema da marca) — para ícones
/// decorativos (abastecimento, navegação). Tipos de manutenção passam cor
/// própria (semântica: cor = qual serviço), que NÃO segue o tema.
struct IconTile: View {
    let systemName: String
    var tint: Color?
    var size: CGFloat = 29

    init(systemName: String, tint: Color? = nil, size: CGFloat = 29) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            // tint nil → accentColor (segue o `.tint()` do ambiente = tema da marca).
            .background(tint ?? Color.accentColor,
                        in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// Forma do `BrandLogoTile`. `.roundedRect` = ícone de app (padrão, usado nos
/// seletores/forms). `.circle` = medalha redonda (seção Conquistas), alinhada aos
/// demais círculos do app — ganha um brilho premium extra (arco superior).
enum BrandTileShape { case roundedRect, circle }

/// Tile com o logo da marca no estilo "ícone de app", com brilho glass.
///
/// Os assets em `Assets.xcassets/BrandLogos/` já são tiles full-bleed na cor
/// da marca (desenhados como ícone) — aqui só recortamos a forma e aplicamos a
/// camada de vidro: brilho especular no topo + leve reflexo lateral na diagonal +
/// hairline de borda + sombra suave. Sem libs externas.
///
/// `assetName` é o nome do imageset (ex.: "BrandLogos/honda"). Para marcas sem
/// logo, o chamador usa `IconTile` (ícone genérico + cor da marca).
struct BrandLogoTile: View {
    let assetName: String
    var size: CGFloat = 38
    /// Forma do recorte. Padrão = ícone de app; medalhas pedem `.circle`.
    var tileShape: BrandTileShape = .roundedRect

    private var corner: CGFloat { size * 0.24 }  // mesmo raio do IconTile

    /// Recorte usado em todas as camadas (clip + overlays). `AnyShape` conforma a
    /// `Shape` → serve para `.clipShape`/`.stroke`/`.fill` (um `some View` não).
    private var shape: AnyShape {
        switch tileShape {
        case .roundedRect: AnyShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        case .circle:      AnyShape(Circle())
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                // Reflexo diagonal de vidro: faixa clara descendo do topo-esquerdo.
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.45), location: 0.0),
                        .init(color: .white.opacity(0.12), location: 0.22),
                        .init(color: .clear,               location: 0.5),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
                .blendMode(.plusLighter)
            }
            .overlay {
                // Brilho especular fino na aresta superior (curva de luz do topo).
                shape
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: max(0.5, size * 0.018)
                    )
                    .blendMode(.plusLighter)
            }
            .overlay {
                // Toque premium SÓ no círculo: pequeno glint elíptico no quadrante
                // superior-esquerdo (vidro polido).
                if tileShape == .circle {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.55), .clear],
                                center: .init(x: 0.32, y: 0.24),
                                startRadius: 0,
                                endRadius: size * 0.42
                            )
                        )
                        .blendMode(.plusLighter)
                        .clipShape(Circle())
                }
            }
            .overlay {
                // Hairline de contorno (separa o tile do fundo claro do sistema).
                shape.stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: size * 0.05, y: size * 0.03)
            .accessibilityHidden(true)
    }
}

/// Mini-card de métrica para grade (padrão stat grid — Esportes/Fitness).
///
/// Sem ícone (padrão Fitness: número grande + rótulo + mini-gráfico). No rodapé,
/// um de dois gráficos (ou nenhum):
/// - `sparkline` ([Double]) → linha de tendência (preço, custo).
/// - `distanceBars` ([DistanceBar]) → barras densas com grid + rótulos de mês
///   no eixo X, no estilo do card de atividade do app Fitness.
/// A faixa do gráfico é reservada SEMPRE (mesmo vazia) → todos os tiles da grade
/// têm a mesma altura. Precisa de ≥ 2 pontos para desenhar.
struct MetricTile: View {
    let label: String
    let value: String
    var tint: Color = .secondary
    /// Série de tendência (linha). nil = sem linha.
    var sparkline: [Double]?
    /// Série de distância semanal (barras + grid + rótulos). nil = sem barras.
    var distanceBars: [DistanceBar]?

    /// Altura reservada para o gráfico. Inclui espaço para os rótulos de mês do
    /// eixo X das barras (Fitness rotula 00/06/12/18 abaixo do gráfico).
    private static let sparkHeight: CGFloat = 38

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Empurra o gráfico para o rodapé; reserva a faixa mesmo quando vazio
            // → grade uniforme (tiles sem gráfico não encolhem).
            Spacer(minLength: 6)
            Group {
                if let distanceBars, distanceBars.count >= 2 {
                    BarSparkline(bars: distanceBars)
                } else if let sparkline, sparkline.count >= 2 {
                    Sparkline(values: sparkline)
                } else {
                    Color.clear
                }
            }
            .frame(height: Self.sparkHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Sparkline no estilo app Fitness: linha fina de tendência + leve preenchimento
/// em gradiente abaixo dela, sem eixos nem rótulos. A cor segue o tema (`.tint`).
///
/// Baseline da escala = mínimo da série (não 0) — uma sparkline comunica
/// *variação*, não magnitude absoluta; ancorar no 0 achataria a curva. Quando
/// todos os valores são iguais, desenha uma linha reta no meio (sem divisão por
/// zero). Espaçamento horizontal igual entre pontos (índice como X).
struct Sparkline: View {
    let values: [Double]

    var body: some View {
        let lo = values.min() ?? 0
        let hi = values.max() ?? 0
        let span = hi - lo
        // Respiro no topo + respiro MAIOR embaixo: catmullRom dá overshoot
        // (a curva passa abaixo do menor ponto), e o domínio extra + .clipped()
        // garantem que o preenchimento não vaze para fora do tile.
        let topPad = max(span * 0.15, 0.0001)
        let botPad = max(span * 0.30, 0.0001)
        let domain = (lo - botPad)...(hi + topPad)

        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            // Preenchimento sutil sob a linha (toque Fitness).
            AreaMark(
                x: .value("i", index),
                y: .value("v", value)
            )
            .foregroundStyle(
                LinearGradient(
                    // Color.accentColor = mesma cor do `.tint` do ambiente (tema da
                    // marca); `.tint` literal não resolve dentro de [Color].
                    colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("i", index),
                y: .value("v", value)
            )
            .foregroundStyle(.tint)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        // Recorta qualquer overshoot da curva suave para dentro dos bounds do
        // tile (senão o preenchimento sangra para a seção de baixo).
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Mini-gráfico de barras no estilo do card de atividade do app Fitness:
/// hastes FINAS e densas (uma por semana), uniformes (uma só cor, sem destaque),
/// nascendo do chão (baseline 0), atrás delas um GRID vertical fino, e abaixo
/// RÓTULOS de mês só em pontos-âncora (como o Fitness rotula 00/06/12/18). Cor
/// do tema (`.tint`).
struct BarSparkline: View {
    let bars: [DistanceBar]

    var body: some View {
        let top = (bars.map(\.distance).max() ?? 1) * 1.15   // respiro acima da maior
        // Posições (índice) que recebem rótulo de mês no eixo X.
        let labeled: [Int: String] = Dictionary(
            uniqueKeysWithValues: bars.enumerated().compactMap { i, bar in
                bar.monthLabel.map { (i, $0) }
            }
        )

        Chart(Array(bars.enumerated()), id: \.offset) { index, bar in
            BarMark(
                x: .value("semana", String(index)),
                y: .value("km", bar.distance),
                width: .ratio(0.55)   // hastes finas, denso (muitas semanas)
            )
            .foregroundStyle(.tint)   // cor uniforme — Fitness não destaca barra
            .cornerRadius(1)
        }
        .chartYScale(domain: 0...max(top, 0.0001))
        .chartYAxis(.hidden)
        // Eixo X: grid vertical fino em TODA posição (textura do Fitness) +
        // rótulo de mês só nas âncoras.
        .chartXAxis {
            AxisMarks(values: bars.indices.map(String.init)) { value in
                AxisGridLine()
                    .foregroundStyle(Color(.quaternaryLabel).opacity(0.5))
                if let s = value.as(String.self), let i = Int(s), let label = labeled[i] {
                    AxisValueLabel {
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

/// Linha "ícone? + rótulo … valor" no estilo Garmin/Ajustes (`LabeledContent`
/// nativo). Recordes passam um SF Symbol + cor semântica (cor = qual recorde);
/// totais omitem o ícone (lista densa, sem ruído). Valor com `.monospacedDigit()`
/// para a coluna direita não dançar. Sem libs.
struct StatRow: View {
    let label: String
    let value: String
    /// SF Symbol opcional à esquerda (recordes). nil → linha densa (totais).
    var systemImage: String?
    /// Cor do ícone (semântica — não segue o tema). Ignorada quando sem ícone.
    var iconColor: Color = .secondary

    var body: some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.primary)
        } label: {
            if let systemImage {
                Label {
                    Text(label)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(iconColor)
                }
            } else {
                Text(label)
            }
        }
    }
}

/// Placeholder de medalha na Garagem — ícone + rótulo curto, sem hierarquia de
/// raridade ainda. Design completo (marca/cilindrada/Iron Butt/níveis) vive em
/// `PLAN/badges.md`. `unlocked` controla o realce; bloqueada fica esmaecida.
struct BadgePlaceholder: View {
    let systemImage: String
    let label: String
    var unlocked: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(unlocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 56, height: 56)
                .background(Color(.tertiarySystemGroupedBackground),
                            in: Circle())
            Text(label)
                .font(.caption2)
                .foregroundStyle(unlocked ? .secondary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .opacity(unlocked ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unlocked ? "\(label), conquistada" : "\(label), bloqueada")
    }
}

/// Badge com arte 3D (asset em `Badges/`), estilo Apple Fitness: colorido quando
/// conquistado, dessaturado + cadeado quando bloqueado. Ver PLAN/badges.md.
///
/// Variações de canto (`.bottomTrailing`):
/// - bloqueada → círculo com cadeado;
/// - desbloqueada + família multi-nível → círculo com o NÚMERO do nível (1/2/3),
///   para que níveis não pareçam todos iguais;
/// - `isComingSoon` (Iron Butt) → colorida sempre + selo "em breve" (ampulheta),
///   sem cadeado nem dessaturação — emblema especial de modalidade futura.
struct BadgeImageTile: View {
    /// Nome do asset dentro do namespace `Badges` (ex.: "scooter"), OU o caminho
    /// de um logo de marca (`BrandLogos/…`) quando `usesBrandLogo == true`.
    let assetName: String
    let label: String
    var unlocked: Bool = false
    /// `assetName` é um logo de marca → desenhar `BrandLogoTile` REDONDO (medalha).
    var usesBrandLogo: Bool = false
    /// Nível desta medalha (1/2/3). Só desenhado quando `levelCount > 1`.
    var level: Int = 1
    /// Total de níveis da família. >1 → mostra o número do nível na conquistada.
    var levelCount: Int = 1
    /// Emblema especial "em breve" (Iron Butt): tratamento premium, nunca cadeado.
    var isComingSoon: Bool = false

    private var showLevelBadge: Bool { unlocked && levelCount > 1 && !isComingSoon }

    @ViewBuilder private var art: some View {
        if usesBrandLogo {
            BrandLogoTile(assetName: assetName, size: 56, tileShape: .circle)
        } else {
            Image("Badges/\(assetName)")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                art
                    // Iron Butt fica SEMPRE colorida (especial); o resto dessatura
                    // quando bloqueado.
                    .saturation(isComingSoon || unlocked ? 1 : 0)
                    .opacity(isComingSoon || unlocked ? 1 : 0.5)
                    // Brilho premium ao redor do emblema especial.
                    .shadow(color: isComingSoon ? .orange.opacity(0.35) : .clear,
                            radius: 6)

                if isComingSoon {
                    // Selo "em breve" — ampulheta, sem cadeado.
                    Image(systemName: "hourglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(3)
                        .background(.thinMaterial, in: Circle())
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(3)
                        .background(.thinMaterial, in: Circle())
                } else if showLevelBadge {
                    // Número do nível na conquistada (cor do tema).
                    Text("\(level)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                        .frame(width: 18, height: 18)
                        .background(.thinMaterial, in: Circle())
                        .overlay(Circle().stroke(.tint.opacity(0.45), lineWidth: 1))
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(unlocked || isComingSoon ? .secondary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isComingSoon { return "\(label), em breve" }
        if !unlocked { return "\(label), bloqueada" }
        if showLevelBadge { return "\(label), conquistada, nível \(level)" }
        return "\(label), conquistada"
    }
}

/// Medalha tocada + se está conquistada — empacota para `.sheet(item:)`.
/// `earnedAt` = data carimbada (Garmin: "Você ganhou esta medalha em …");
/// nil quando bloqueada ou ainda sem award persistido.
struct BadgePresentation: Identifiable {
    let badge: Badge
    let unlocked: Bool
    var earnedAt: Date? = nil
    var id: String { badge.id }
}

/// Sheet explicativo da medalha (toque na grade), estilo Apple Fitness / HIG:
/// arte grande, título, estado (conquistada / bloqueada) e a explicação de como
/// se conquista. Detentes médio/grande, sem chrome customizado.
struct BadgeDetailSheet: View {
    let presentation: BadgePresentation
    @Environment(\.dismiss) private var dismiss

    private var badge: Badge { presentation.badge }
    private var unlocked: Bool { presentation.unlocked }

    // Estado: "em breve" (Iron Butt) > conquistada > bloqueada.
    private var statusText: String {
        if badge.isComingSoon { return "Em breve" }
        return unlocked ? "Conquistada" : "Bloqueada"
    }
    // Pontos que a medalha vale, mostrados ao lado do status. Conquistada → crédito
    // já somado ao nível ("+N pts"); bloqueada → incentivo ("Vale N pts"). Medalhas
    // que não pontuam (Iron Butt "em breve") omitem.
    private var pointsText: String? {
        guard badge.points > 0 else { return nil }
        let unit = badge.points == 1 ? "pt" : "pts"
        return unlocked ? "+\(badge.points) \(unit)" : "Vale \(badge.points) \(unit)"
    }
    private var statusIcon: String {
        if badge.isComingSoon { return "hourglass" }
        return unlocked ? "checkmark.seal.fill" : "lock.fill"
    }
    private var statusStyle: AnyShapeStyle {
        if badge.isComingSoon { return AnyShapeStyle(.orange) }
        return unlocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 8)

                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if badge.usesBrandLogo {
                            BrandLogoTile(assetName: badge.assetName, size: 140, tileShape: .circle)
                        } else {
                            Image("Badges/\(badge.assetName)")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                        }
                    }
                    // Iron Butt sempre colorido (especial); demais dessaturam se bloqueado.
                    .saturation(badge.isComingSoon || unlocked ? 1 : 0)
                    .opacity(badge.isComingSoon || unlocked ? 1 : 0.5)
                    .shadow(color: badge.isComingSoon ? .orange.opacity(0.4) : .clear, radius: 16)

                    if badge.isComingSoon {
                        Image(systemName: "hourglass")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    } else if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                }

                VStack(spacing: 8) {
                    Text(badge.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Label(statusText, systemImage: statusIcon)
                            .foregroundStyle(statusStyle)
                        if let pointsText {
                            Text("·").foregroundStyle(.tertiary)
                            Text(pointsText)
                                .foregroundStyle(unlocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        }
                    }
                    .font(.subheadline.weight(.medium))
                }

                Text(badge.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                if unlocked, let earnedAt = presentation.earnedAt {
                    Text("Você ganhou esta medalha em \(AppFormat.dateLong(earnedAt)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// Cabeçalho de NÍVEL do perfil (estilo Garmin), no topo da seção Conquistas.
/// Hexágono com o número do nível + barra de progresso + "N pontos para o próximo
/// nível" (ou "Nível máximo"). Estado é DERIVADO (`ProfileLevel`); nada salvo.
/// Sem avatar — o app não tem foto de perfil. Cor segue o `.tint` do ambiente
/// (tema da marca ativa). SF Symbols + tipografia do sistema; nada custom pesado.
struct ProfileLevelHeader: View {
    let level: ProfileLevel
    private let hexSize: CGFloat = 64

    /// Hexágono "medalha": gradiente da cor da marca (escurece p/ baixo, dá volume)
    /// + brilho especular no topo (camada glass, igual ao BrandLogoTile/badges 3D)
    /// + hairline de borda + sombra projetada. O número grande em destaque.
    private var hex: some View {
        ZStack {
            // Volume: gradiente vertical da tint (claro no topo → escuro embaixo).
            Image(systemName: "hexagon.fill")
                .font(.system(size: hexSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.92), Color.accentColor],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // Brilho especular: arco claro na metade superior (glass).
                .overlay {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: hexSize))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.0)],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .blendMode(.softLight)
                }
                // Hairline de borda p/ recortar do fundo.
                .overlay {
                    Image(systemName: "hexagon")
                        .font(.system(size: hexSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .shadow(color: Color.accentColor.opacity(0.35), radius: 7, y: 3)

            Text("\(level.level)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: hexSize, height: hexSize)
        .accessibilityHidden(true)
    }

    private var caption: String {
        level.isMax
            ? "Nível máximo alcançado"
            : "\(level.pointsForNext) \(level.pointsForNext == 1 ? "ponto" : "pontos") para o próximo nível"
    }

    var body: some View {
        HStack(spacing: 16) {
            hex
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Nível \(level.level)")
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text("\(level.totalPoints) pts")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                ProgressView(value: level.progress)
                    .tint(Color.accentColor)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nível \(level.level), \(level.totalPoints) pontos. \(caption).")
    }
}

/// Contêiner com o visual de card agrupado nativo (sem sombra custom).
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension MaintenanceType {
    /// Cor semântica do tile por tipo de manutenção (padrão Ajustes).
    var tint: Color {
        switch self {
        case .oleo: .blue
        case .filtros: .teal
        case .pneus: .gray
        case .relacao: .orange
        case .freios: .red
        case .revisao: .purple
        case .outro: .gray
        }
    }
}
