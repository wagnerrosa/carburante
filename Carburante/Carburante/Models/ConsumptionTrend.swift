//
//  ConsumptionTrend.swift
//  Carburante
//
//  Seta de tendência do km/l de um abastecimento frente à média da moto
//  (histórico de abastecimentos). Neutra por design: consumo abaixo da média
//  não é erro — a seta informa, não julga (sem verde/vermelho).
//

import Foundation

nonisolated enum ConsumptionTrend: Equatable {
    case up
    case down

    /// Desvio mínimo (fração da média) para ganhar seta. Abaixo disso é ruído
    /// de bomba/medição e não vira sinal.
    static let threshold = 0.05

    /// nil = sem seta: sem média (1 só segmento) ou desvio < `threshold`.
    static func of(kmPerLiter: Double, average: Double?) -> ConsumptionTrend? {
        guard let average, average > 0 else { return nil }
        let delta = (kmPerLiter - average) / average
        if delta >= threshold { return .up }
        if delta <= -threshold { return .down }
        return nil
    }

    var symbolName: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }

    /// Complemento falado no VoiceOver.
    var accessibilityDescription: String {
        switch self {
        case .up: "acima da média"
        case .down: "abaixo da média"
        }
    }
}
