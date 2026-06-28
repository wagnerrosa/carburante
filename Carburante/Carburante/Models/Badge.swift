//
//  Badge.swift
//  Carburante
//
//  Motor de conquistas (ver PLAN/badges.md). Catálogo estático + regra de unlock
//  PURA sobre os dados já persistidos (`Motorcycle`/`FuelLog`/`MaintenanceLog`/
//  `GarageRecords`) — mesmo padrão de `ConsumptionCalculator`: zero UI, testável.
//
//  Modelo de visibilidade (decisão 2026-06-28): seção única "Conquistas".
//  - Primeiros passos: sempre visíveis (universais).
//  - Categorias: o usuário só vê as categorias que JÁ TOCOU (cadastrou ao menos
//    uma moto). Categoria nunca cadastrada fica OCULTA (nem locked). Dentro de
//    uma categoria tocada ele vê TODOS os níveis (I/II/III) — desbloqueados e
//    bloqueados — como metas a perseguir.
//  - Níveis das 5 categorias com progressão (scooter/trail/custom/street/sport):
//    I = cadastrar a moto; II = 5.000 km; III = 20.000 km rodados em motos
//    daquela categoria (km = soma de `currentOdometer − odometerBaseline`).
//    touring/offroad/other têm 1 nível só (sem km).
//
//  Sem persistência de unlock no MVP: o estado é DERIVADO a cada render.
//  Confinado à seção Conquistas da Garagem (exceção à constraint "native iOS
//  only", estilo Apple Fitness) — não vaza para navegação/chrome.
//

import Foundation

/// Agrupamento da medalha. `categoria` carrega a `MotorcycleCategory` de origem
/// para a regra de visibilidade (só categorias tocadas aparecem).
enum BadgeGroup: Equatable {
    case primeirosPassos
    case categoria(MotorcycleCategory)
}

/// Quilometragem (rodada na categoria) exigida para o nível desbloquear.
/// 0 = nível I (basta cadastrar a moto). Níveis II/III usam km > 0.
private let levelTwoKm: Double = 5_000
private let levelThreeKm: Double = 20_000

/// Uma medalha do catálogo. `assetName` é o nome no namespace `Badges` (arte 3D).
/// Níveis da mesma categoria reusam o mesmo asset (família, estilo Fitness) e se
/// diferenciam por título + `requiredKm`. O estado de conquista NÃO mora aqui.
struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let assetName: String
    let group: BadgeGroup
    /// Km na categoria exigidos para desbloquear (0 = só cadastrar a moto).
    /// Ignorado para primeiros passos.
    var requiredKm: Double = 0
}

extension Badge {
    /// Catálogo completo.
    static let all: [Badge] = primeirosPassos + categoria

    /// Desbloqueiam de dados que já existem hoje — sempre visíveis.
    static let primeirosPassos: [Badge] = [
        Badge(id: "first_bike",        title: "Primeira moto",    assetName: "firstBike",        group: .primeirosPassos),
        Badge(id: "first_fuel",        title: "1º abastecimento", assetName: "firstFuel",        group: .primeirosPassos),
        Badge(id: "first_maintenance", title: "1ª manutenção",    assetName: "firstMaintenance", group: .primeirosPassos),
        Badge(id: "best_consumption",  title: "Melhor consumo",   assetName: "bestConsumption",  group: .primeirosPassos),
    ]

    /// Badges de categoria. 5 categorias têm 3 níveis (km); 3 têm 1 nível só.
    /// Nomes seguem PLAN/badges.md §"Categorias".
    static let categoria: [Badge] = [
        // Scooter
        Badge(id: "cat_scooter_1", title: "Urban Rider",    assetName: "scooter", group: .categoria(.scooter)),
        Badge(id: "cat_scooter_2", title: "Rei da Cidade",  assetName: "scooter", group: .categoria(.scooter), requiredKm: levelTwoKm),
        Badge(id: "cat_scooter_3", title: "City Commuter",  assetName: "scooter", group: .categoria(.scooter), requiredKm: levelThreeKm),
        // Trail / Big Trail
        Badge(id: "cat_trail_1",   title: "Adventure Rider", assetName: "trail",  group: .categoria(.trail)),
        Badge(id: "cat_trail_2",   title: "Explorador",      assetName: "trail",  group: .categoria(.trail), requiredKm: levelTwoKm),
        Badge(id: "cat_trail_3",   title: "Sem Destino",     assetName: "trail",  group: .categoria(.trail), requiredKm: levelThreeKm),
        // Custom / Cruiser
        Badge(id: "cat_custom_1",  title: "Road Captain",    assetName: "custom", group: .categoria(.custom)),
        Badge(id: "cat_custom_2",  title: "Long Road",       assetName: "custom", group: .categoria(.custom), requiredKm: levelTwoKm),
        Badge(id: "cat_custom_3",  title: "Highway Rider",   assetName: "custom", group: .categoria(.custom), requiredKm: levelThreeKm),
        // Street / Naked
        Badge(id: "cat_street_1",  title: "Street Fighter",  assetName: "street", group: .categoria(.street)),
        Badge(id: "cat_street_2",  title: "Urban Warrior",   assetName: "street", group: .categoria(.street), requiredKm: levelTwoKm),
        Badge(id: "cat_street_3",  title: "Asphalt Rider",   assetName: "street", group: .categoria(.street), requiredKm: levelThreeKm),
        // Esportiva
        Badge(id: "cat_sport_1",   title: "Speed Demon",     assetName: "sport",  group: .categoria(.sport)),
        Badge(id: "cat_sport_2",   title: "Track Soul",      assetName: "sport",  group: .categoria(.sport), requiredKm: levelTwoKm),
        Badge(id: "cat_sport_3",   title: "Redline Club",    assetName: "sport",  group: .categoria(.sport), requiredKm: levelThreeKm),
        // Categorias de nível único (sem progressão por km).
        Badge(id: "cat_touring_1", title: "Estradeiro",      assetName: "touring", group: .categoria(.touring)),
        Badge(id: "cat_offroad_1", title: "Off-road",        assetName: "offroad", group: .categoria(.offroad)),
        Badge(id: "cat_other_1",   title: "Motociclista",    assetName: "other",   group: .categoria(.other)),
    ]
}

/// Snapshot da FROTA que decide unlock + visibilidade — desacoplado de SwiftData
/// para o motor ser testável com valores puros.
struct BadgeFleetContext {
    let hasMotorcycle: Bool
    let hasFuelLog: Bool
    let hasMaintenanceLog: Bool
    let hasBestConsumption: Bool
    /// Categorias que o usuário já cadastrou (ao menos 1 moto) → o que fica VISÍVEL.
    let presentCategories: Set<MotorcycleCategory>
    /// Km rodados por categoria (soma de `currentOdometer − odometerBaseline`
    /// das motos da categoria) → decide os níveis II/III.
    let kmByCategory: [MotorcycleCategory: Double]
}

enum BadgeEvaluator {
    /// IDs das badges que devem APARECER na grade (primeiros passos sempre +
    /// só as categorias presentes). Ordem do catálogo preservada.
    static func visibleBadges(_ ctx: BadgeFleetContext) -> [Badge] {
        Badge.all.filter { badge in
            switch badge.group {
            case .primeirosPassos:
                return true
            case .categoria(let cat):
                return ctx.presentCategories.contains(cat)
            }
        }
    }

    /// IDs das badges conquistadas (regra pura de unlock).
    static func unlockedIDs(_ ctx: BadgeFleetContext) -> Set<String> {
        var ids = Set<String>()
        if ctx.hasMotorcycle      { ids.insert("first_bike") }
        if ctx.hasFuelLog         { ids.insert("first_fuel") }
        if ctx.hasMaintenanceLog  { ids.insert("first_maintenance") }
        if ctx.hasBestConsumption { ids.insert("best_consumption") }

        for badge in Badge.categoria {
            guard case .categoria(let cat) = badge.group,
                  ctx.presentCategories.contains(cat) else { continue }
            // Nível I (requiredKm 0) basta cadastrar; II/III exigem km na categoria.
            let km = ctx.kmByCategory[cat] ?? 0
            if km >= badge.requiredKm {
                ids.insert(badge.id)
            }
        }
        return ids
    }
}
