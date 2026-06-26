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

/// Tile com o logo da marca no estilo "ícone de app", com brilho glass.
///
/// Os assets em `Assets.xcassets/BrandLogos/` já são tiles full-bleed na cor
/// da marca (desenhados como ícone) — aqui só recortamos os cantos contínuos e
/// aplicamos a camada de vidro: brilho especular no topo + leve reflexo lateral
/// na diagonal + hairline de borda + sombra suave. Sem libs externas.
///
/// `assetName` é o nome do imageset (ex.: "BrandLogos/honda"). Para marcas sem
/// logo, o chamador usa `IconTile` (ícone genérico + cor da marca).
struct BrandLogoTile: View {
    let assetName: String
    var size: CGFloat = 38

    private var corner: CGFloat { size * 0.24 }  // mesmo raio do IconTile

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
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
