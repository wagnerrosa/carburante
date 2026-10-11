//
//  PremiumService.swift
//  Carburante
//
//  Fonte única de "é Premium?" no app (PLAN/premium-mvp.md §Assinatura).
//  StoreKit 2, só no aparelho — sem servidor no MVP: a compra vale em todo
//  aparelho com o mesmo Apple ID (e na família, via Family Sharing). Lê
//  `Transaction.currentEntitlements` no launch e escuta `Transaction.updates`
//  (renovação, reembolso, compra feita em outro aparelho ou pela família).
//
//  O último estado fica guardado: o 1º frame (e o app offline) já sabe quem
//  assina, sem piscar "grátis" até o StoreKit responder.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class PremiumService {
    static let shared = PremiumService()

    /// Produto da assinatura ativa (mensal ou anual); nil = grátis.
    private(set) var activeProductID: String?
    var isPremium: Bool {
        #if DEBUG
        // Simulador sem compra: `-debugPremium YES` (ou NO) força o estado para
        // conferir as telas com e sem Premium. Fora do build de loja.
        if let forced = UserDefaults.standard.string(forKey: "debugPremium") { return forced == "YES" }
        #endif
        return activeProductID != nil
    }
    /// "Mensal" / "Anual" para Ajustes.
    var planName: String? { activeProductID.flatMap(PremiumEntitlement.planName(for:)) }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private static let cacheKey = "premiumActiveProductID"

    private init() {
        activeProductID = UserDefaults.standard.string(forKey: Self.cacheKey)
    }

    /// Chamado uma vez no launch. Escutar `Transaction.updates` desde o início
    /// é recomendação da Apple: transação que chega sem ninguém ouvindo fica
    /// pendente (ex.: compra aprovada depois pelo "Pedir para comprar").
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Relê o direito no StoreKit. Funciona offline (o aparelho guarda as
    /// transações). Chamado no launch, a cada atualização e após uma compra.
    func refresh() async {
        var entries: [PremiumEntitlement.Entry] = []
        for await result in Transaction.currentEntitlements {
            // Transação que não passa na verificação da Apple não dá direito.
            guard case .verified(let transaction) = result else { continue }
            entries.append(PremiumEntitlement.Entry(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate
            ))
        }
        let active = PremiumEntitlement.activeProductID(in: entries, now: .now)
        guard active != activeProductID else { return }
        activeProductID = active
        UserDefaults.standard.set(active, forKey: Self.cacheKey)
    }
}
