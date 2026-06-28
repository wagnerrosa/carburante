//
//  Badge.swift
//  Carburante
//
//  Motor de conquistas (1º corte — ver PLAN/badges.md §"Plano de implementação").
//  Catálogo estático + regra de unlock PURA sobre os dados já persistidos
//  (`Motorcycle`/`FuelLog`/`MaintenanceLog`/`GarageRecords`) — mesmo padrão de
//  `ConsumptionCalculator`: zero UI aqui, testável em isolamento.
//
//  Sem persistência de unlock no MVP: o estado (locked/unlocked) é DERIVADO dos
//  dados a cada render. Data de conquista (timestamp) fica para a Fase 7.
//
//  Confinado à seção Medalhas da Garagem (exceção à constraint "native iOS only",
//  como o Apple Fitness faz com conquistas) — não vaza para navegação/chrome.
//

import Foundation

/// Agrupamento da medalha na grade da Garagem.
enum BadgeGroup: String, CaseIterable, Identifiable {
    case primeirosPassos
    case categoria

    var id: String { rawValue }

    /// Cabeçalho pt-BR da seção na Garagem.
    var title: String {
        switch self {
        case .primeirosPassos: return "Primeiros passos"
        case .categoria:       return "Sua moto"
        }
    }
}

/// Uma medalha do catálogo. `assetName` é o nome dentro do namespace `Badges`
/// no asset catalog (arte 3D); o estado de conquista NÃO mora aqui (é derivado).
struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let assetName: String
    let group: BadgeGroup
}

extension Badge {
    /// Catálogo do 1º corte (~12 badges). Marcas, cilindrada, km e Iron Butt
    /// ficam para a Fase 7 (ver PLAN/badges.md §"Fora deste corte").
    static let all: [Badge] = primeirosPassos + categoria

    /// Desbloqueiam de dados que já existem hoje.
    static let primeirosPassos: [Badge] = [
        Badge(id: "first_bike",       title: "Primeira moto",       assetName: "firstBike",        group: .primeirosPassos),
        Badge(id: "first_fuel",       title: "1º abastecimento",    assetName: "firstFuel",        group: .primeirosPassos),
        Badge(id: "first_maintenance",title: "1ª manutenção",       assetName: "firstMaintenance", group: .primeirosPassos),
        Badge(id: "best_consumption", title: "Melhor consumo",      assetName: "bestConsumption",  group: .primeirosPassos),
    ]

    /// Uma por `MotorcycleCategory` — desbloqueia no cadastro pela categoria.
    /// Títulos seguem os nomes de identidade de PLAN/badges.md §"Categorias".
    static let categoria: [Badge] = [
        Badge(id: "cat_scooter", title: "Urban Rider",     assetName: "scooter", group: .categoria),
        Badge(id: "cat_street",  title: "Street Fighter",  assetName: "street",  group: .categoria),
        Badge(id: "cat_trail",   title: "Adventure Rider", assetName: "trail",   group: .categoria),
        Badge(id: "cat_sport",   title: "Speed Demon",     assetName: "sport",   group: .categoria),
        Badge(id: "cat_custom",  title: "Road Captain",    assetName: "custom",  group: .categoria),
        Badge(id: "cat_touring", title: "Estradeiro",      assetName: "touring", group: .categoria),
        Badge(id: "cat_offroad", title: "Off-road",        assetName: "offroad", group: .categoria),
        Badge(id: "cat_other",   title: "Motociclista",    assetName: "other",   group: .categoria),
    ]

    /// Mapa categoria → id da medalha correspondente.
    static func id(for category: MotorcycleCategory) -> String {
        switch category {
        case .scooter: return "cat_scooter"
        case .street:  return "cat_street"
        case .trail:   return "cat_trail"
        case .sport:   return "cat_sport"
        case .custom:  return "cat_custom"
        case .touring: return "cat_touring"
        case .offroad: return "cat_offroad"
        case .other:   return "cat_other"
        }
    }
}

/// Snapshot dos dados que decidem o unlock — desacoplado de SwiftData para o
/// motor ser testável com valores puros (mesma estratégia de `FuelEntry`).
struct BadgeUnlockContext {
    let hasMotorcycle: Bool
    let hasFuelLog: Bool
    let hasMaintenanceLog: Bool
    let hasBestConsumption: Bool
    /// Categoria da moto ativa (nil → nenhuma categoria desbloqueada).
    let category: MotorcycleCategory?
}

enum BadgeEvaluator {
    /// Regra pura de unlock. Recebe o contexto, devolve os IDs conquistados.
    static func unlockedIDs(_ ctx: BadgeUnlockContext) -> Set<String> {
        var ids = Set<String>()
        if ctx.hasMotorcycle      { ids.insert("first_bike") }
        if ctx.hasFuelLog         { ids.insert("first_fuel") }
        if ctx.hasMaintenanceLog  { ids.insert("first_maintenance") }
        if ctx.hasBestConsumption { ids.insert("best_consumption") }
        if let cat = ctx.category { ids.insert(Badge.id(for: cat)) }
        return ids
    }
}
