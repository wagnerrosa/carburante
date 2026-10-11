//
//  PlanSavings.swift
//  Carburante
//
//  Quanto o plano anual economiza frente a 12 meses do mensal: o preço cheio
//  riscado e o "Economize X%" no cartão do anual da tela de assinatura. Os
//  preços vêm do StoreKit (App Store Connect), então mudar preço lá atualiza
//  a conta sozinho.
//

import Foundation

struct PlanSavings: Equatable {
    /// 12 × o preço do mensal — o valor riscado.
    let fullYearPrice: Decimal
    /// Desconto em %, arredondado para baixo: nunca prometer mais do que é.
    let percent: Int

    /// nil quando o anual não sai mais barato (nada a anunciar).
    init?(monthly: Decimal, yearly: Decimal) {
        let fullYear = monthly * 12
        guard fullYear > 0, yearly > 0, yearly < fullYear else { return nil }
        let ratio = NSDecimalNumber(decimal: (fullYear - yearly) / fullYear * 100).doubleValue
        let percent = Int(ratio.rounded(.down))
        guard percent >= 1 else { return nil }
        self.fullYearPrice = fullYear
        self.percent = percent
    }
}
