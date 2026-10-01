//
//  FuelPrice.swift
//  Carburante
//
//  Plausibilidade do preço por litro (valor ÷ litros). Pega o erro de vírgula
//  do OCR da bomba/comprovante (campo: R$ 28,49 lido como 2.849) e de
//  digitação, que viraria gasto e custo/km errados sem ninguém notar.
//
//  Lógica pura: só SUGERE — a linha do preço vira aviso laranja e o usuário
//  confere. Nunca bloqueia o save (mesma regra de `FuelGap`).
//
//  Faixa em BRL (o app é pt-BR/BRL fixo — `AppFormat`). Erro de vírgula muda o
//  preço por 10×, 100× ou 1.000×, então a faixa pode ser larga: cobre etanol
//  barato, GNV (R$/m³), gasolina premium e posto remoto sem falso alarme.
//  Moeda por país (expansão internacional) → a faixa passa a vir do país.
//

import Foundation

enum FuelPrice {

    /// Preço por litro plausível em BRL. Fora disso = provável erro de vírgula.
    static let plausibleRange: ClosedRange<Double> = 2...15

    /// Preço por litro, ou nil se faltar valor/litros.
    static func perLiter(cost: Double?, liters: Double?) -> Double? {
        guard let cost, cost > 0, let liters, liters > 0 else { return nil }
        return cost / liters
    }

    /// O preço por litro fica fora da faixa plausível? Sem os dois valores,
    /// não há o que avisar.
    static func isImplausible(cost: Double?, liters: Double?) -> Bool {
        guard let ppl = perLiter(cost: cost, liters: liters) else { return false }
        return !plausibleRange.contains(ppl)
    }
}
