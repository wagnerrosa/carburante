//
//  Components.swift
//  Carburante
//
//  Componentes nativos reaproveitados (Fase 11 — refinamento UI):
//  tile de ícone colorido (padrão Ajustes), mini-card de métrica (padrão
//  Esportes/Fitness) e faixa de status (padrão Casa). Sem libs externas,
//  sem sombras custom — só hierarquia, SF Symbols e cores semânticas.
//

import SwiftUI

/// Tile de ícone colorido à esquerda de uma linha (padrão Ajustes/Casa).
struct IconTile: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 29

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
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

/// Faixa de status no topo (padrão Casa "Tudo seguro").
struct StatusBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(tint.opacity(0.12),
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
