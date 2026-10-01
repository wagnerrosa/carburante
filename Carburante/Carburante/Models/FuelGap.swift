//
//  FuelGap.swift
//  Carburante
//
//  Detecção de lacuna de abastecimento (PLAN/lacuna-abastecimento.md §3).
//  Lógica pura: só SUGERE — o app mostra um aviso e o usuário decide se marca
//  "Abasteci sem registrar". Nunca bloqueia o save, nunca marca sozinho
//  (descartar em silêncio esconderia um erro de digitação/OCR).
//
//  Exceção: acima do teto físico (`absoluteKmPerLiterCeiling`) não é suspeita,
//  é impossível — `ConsumptionCalculator.segments` tira o trecho da média
//  sozinho (derivado, nada gravado). Protege o histórico: recibo antigo sem os
//  abastecimentos do meio daria centenas de km/l (PLAN/registro-retroativo.md).
//
//  Dois sinais independentes:
//  - salto de km (passo do hodômetro, litros ainda desconhecidos);
//  - km/l implícito alto demais (revisão, quando o registro fecha um trecho).
//
//  Os limites são HIPÓTESE a calibrar com dado de campo (analytics
//  `fuel_created.gap_warning`). A janela de salto é a mesma que o OCR vai usar
//  para julgar plausibilidade (PLAN/ocr-hodometro.md §4.2) — uma função só.
//

import Foundation

enum FuelGap {

    /// Salto mínimo que já merece aviso, com ou sem histórico.
    static let baseJumpKm: Double = 1_500
    /// Teto físico por dia (Iron Butt ≈ 1.600 km/24h; 1.000 é folgado p/ o normal).
    static let maxKmPerDay: Double = 1_000
    /// Teto de km/l sem histórico da moto (nenhuma moto de rua passa disso).
    /// Também é o teto FÍSICO: trecho acima dele nunca entra na média.
    static let absoluteKmPerLiterCeiling: Double = 80

    /// Aviso que o fluxo mostra (e manda no analytics).
    enum Warning: String {
        case jump   // salto de km grande demais
        case kmPerLiter = "kml" // consumo implícito alto demais
    }

    // MARK: - Salto de km

    /// Limite de salto (km) acima do qual o delta parece erro ou lacuna:
    /// `max(1.500, 3 × p90 dos deltas da moto)`, limitado pelo que dá para
    /// rodar nos dias desde o último registro (~1.000 km/dia).
    /// - Parameters:
    ///   - deltas: km entre abastecimentos consecutivos da moto (só positivos
    ///     contam; lacunas já marcadas devem vir de fora).
    ///   - daysSinceLast: dias desde o último registro (nil = desconhecido).
    static func jumpLimit(deltas: [Double], daysSinceLast: Int?) -> Double {
        let valid = deltas.filter { $0 > 0 }
        // p90 com poucos pontos é ruído — só a base.
        let historyLimit = valid.count >= 3 ? 3 * percentile90(valid) : 0
        let limit = max(baseJumpKm, historyLimit)
        guard let days = daysSinceLast else { return limit }
        return min(limit, Double(max(days, 1)) * maxKmPerDay)
    }

    /// O delta passa do limite de salto?
    static func isSuspiciousJump(delta: Double, deltas: [Double], daysSinceLast: Int?) -> Bool {
        delta > jumpLimit(deltas: deltas, daysSinceLast: daysSinceLast)
    }

    /// Deltas consecutivos (por odômetro) dos registros de uma moto, sem os
    /// trechos que terminam numa lacuna já marcada (não são uso normal).
    static func deltas(from entries: [FuelEntry]) -> [Double] {
        let ordered = entries.sorted { $0.odometer < $1.odometer }
        return zip(ordered, ordered.dropFirst()).compactMap { prev, next in
            next.missedPrevious ? nil : next.odometer - prev.odometer
        }
    }

    // MARK: - km/l implícito

    /// Teto de km/l plausível: `2 × mediana dos trechos da moto`, ou o teto
    /// absoluto enquanto não há ao menos 2 trechos medidos.
    static func kmPerLiterCeiling(history: [Double]) -> Double {
        let valid = history.filter { $0 > 0 }
        guard valid.count >= 2 else { return absoluteKmPerLiterCeiling }
        return 2 * median(valid)
    }

    /// km/l do trecho que ESTE registro fecharia, se fechar algum. Usa o mesmo
    /// cálculo do app (`ConsumptionCalculator.segments`), então parciais no
    /// meio do trecho entram. Mantém o trecho impossível (> teto físico) — o
    /// aviso precisa mostrar justamente esse número.
    static func impliedKmPerLiter(adding entry: FuelEntry, to entries: [FuelEntry]) -> Double? {
        guard entry.isFullTank, !entry.missedPrevious else { return nil }
        let segs = ConsumptionCalculator.segments(from: entries + [entry], keepingImpossible: true)
        return segs.last(where: { $0.endOdometer == entry.odometer })?.kmPerLiter
    }

    /// O registro fecharia um trecho com km/l acima do teto?
    static func isImplausibleKmPerLiter(adding entry: FuelEntry, to entries: [FuelEntry]) -> Bool {
        guard let implied = impliedKmPerLiter(adding: entry, to: entries) else { return false }
        let history = ConsumptionCalculator.segments(from: entries).map(\.kmPerLiter)
        return implied > kmPerLiterCeiling(history: history)
    }

    // MARK: - Estatística

    static func percentile90(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        // Nearest-rank: simples e auditável.
        let rank = Int((0.9 * Double(sorted.count)).rounded(.up))
        return sorted[max(rank - 1, 0)]
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
