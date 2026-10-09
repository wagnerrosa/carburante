//
//  MotorcycleStatus.swift
//  Carburante
//
//  Situação da moto: na garagem (padrão), à venda ou vendida —
//  PLAN/premium-mvp.md §1 e PLAN/monetizacao.md Frente 1. Na garagem não tem
//  rótulo: estado ok é silêncio (PLAN/DESIGN.md §4). Vendida sai da garagem e
//  fica só para consulta; à venda continua sua até vender.
//
//  Persistida por `rawValue` = CHAVE CONGELADA (SwiftData `statusRaw`, Supabase
//  `motorcycles.status`): nunca renomear, nunca exibir — tela usa `label`. Ver
//  a regra completa no `FuelType` (Models/FuelLog.swift).
//

import Foundation

enum MotorcycleStatus: String, CaseIterable {
    case active
    case forSale = "for_sale"
    case sold

    /// Rótulo de tela. Nil na garagem (silêncio).
    var label: String? {
        switch self {
        case .active: nil
        case .forSale: "À venda"
        case .sold: "Vendida"
        }
    }
}
