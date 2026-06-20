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

/// Mini-card de métrica para grade (padrão stat grid — Esportes/Fitness).
struct MetricTile: View {
    let label: String
    let value: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
