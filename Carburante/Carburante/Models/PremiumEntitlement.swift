//
//  PremiumEntitlement.swift
//  Carburante
//
//  Regra pura de "esta compra dá Premium?" (PLAN/premium-mvp.md §Assinatura).
//  Recebe as transações já verificadas pelo StoreKit como valores simples —
//  desacoplado do StoreKit, testável sem sessão de compra. Quem lê o StoreKit
//  é o `PremiumService`.
//

import Foundation

enum PremiumEntitlement {
    /// IDs criados no App Store Connect (2026-10-10). Product ID é imutável no
    /// ASC — nunca renomear aqui sem criar o produto novo lá.
    static let monthlyID = "carburante.premium.monthly"
    static let yearlyID = "carburante.premium.yearly"
    static let productIDs = [monthlyID, yearlyID]

    /// O que importa de uma transação para decidir o direito.
    struct Entry: Equatable {
        let productID: String
        let expirationDate: Date?
        let revocationDate: Date?
    }

    /// Produto que dá Premium agora, ou nil. Ignora produto desconhecido,
    /// transação reembolsada/revogada e assinatura vencida. Com mais de uma
    /// válida (ex.: troca de mensal para anual no meio do período), vale a que
    /// vence por último.
    static func activeProductID(in entries: [Entry], now: Date) -> String? {
        entries
            .filter { productIDs.contains($0.productID) }
            .filter { $0.revocationDate == nil }
            .filter { ($0.expirationDate ?? .distantFuture) > now }
            .max { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }?
            .productID
    }

    /// Nome do plano para a tela ("Mensal", "Anual").
    static func planName(for productID: String) -> String? {
        switch productID {
        case monthlyID: "Mensal"
        case yearlyID: "Anual"
        default: nil
        }
    }
}
