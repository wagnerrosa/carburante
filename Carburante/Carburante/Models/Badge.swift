//
//  Badge.swift
//  Carburante
//
//  Motor de conquistas (ver PLAN/badges.md). Catálogo estático + regra de unlock
//  PURA sobre os dados já persistidos (`Motorcycle`/`FuelLog`/`MaintenanceLog`/
//  `GarageRecords`) — mesmo padrão de `ConsumptionCalculator`: zero UI, testável.
//
//  Modelo de visibilidade (decisão 2026-06-28): seção única "Conquistas".
//  - Universais (primeira moto, abastecimentos, manutenção, melhor consumo):
//    sempre visíveis.
//  - Categorias: o usuário só vê as que JÁ TOCOU (cadastrou ≥1 moto). Categoria
//    nunca cadastrada fica OCULTA. Dentro de uma categoria tocada vê TODOS os
//    níveis (I/II/III).
//
//  Marcos de abastecimento contam TANQUES CHEIOS (casa com a mecânica
//  full-to-full): 1 = primeiro; 2 = 1ª média desbloqueada; 3 = gráfico de
//  tendência no Resumo ganha sentido (2 segmentos); 10 = hábito.
//  "Melhor consumo" desbloqueia quando o melhor km/l da moto supera a régua
//  estimada da categoria (`ConsumptionReference`) — exige cilindrada cadastrada.
//
//  Níveis de categoria por km rodado: I = cadastrar; II = 5.000; III = 20.000.
//
//  Cada badge carrega um `detail` explicativo, mostrado num sheet ao tocar
//  (estilo Apple Fitness / HIG). Sem persistência de unlock: estado derivado.
//

import Foundation

/// Agrupamento da medalha. `categoria` carrega a `MotorcycleCategory` de origem
/// para a regra de visibilidade (só categorias tocadas aparecem).
enum BadgeGroup: Equatable {
    case universal
    case categoria(MotorcycleCategory)
}

/// Km (rodados na categoria) para o nível desbloquear. 0 = nível I (cadastrar).
private let levelTwoKm: Double = 5_000
private let levelThreeKm: Double = 20_000

/// Uma medalha do catálogo. `assetName` é o nome no namespace `Badges` (arte 3D).
/// Badges da mesma família reusam o mesmo asset, diferenciam por título + regra.
/// `detail` é o texto explicativo do sheet de toque. O estado de conquista NÃO
/// mora aqui — é derivado em `BadgeEvaluator`.
struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let assetName: String
    let group: BadgeGroup
    /// Explicação curta mostrada ao tocar a medalha (como/por que se conquista).
    let detail: String
    /// Km na categoria exigidos (0 = só cadastrar a moto). Só para `.categoria`.
    var requiredKm: Double = 0
    /// Tanques cheios exigidos (0 = ignora). Só para os badges de abastecimento.
    var requiredFullTanks: Int = 0
}

extension Badge {
    /// Catálogo completo.
    static let all: [Badge] = universais + categoria

    /// Universais — sempre visíveis. Desbloqueiam de dados que já existem.
    static let universais: [Badge] = [
        Badge(id: "first_bike", title: "Primeira moto", assetName: "firstBike", group: .universal,
              detail: "Você cadastrou sua primeira moto. É o ponto de partida para acompanhar consumo, gastos e manutenção."),

        // Abastecimentos — marcos por tanque cheio (mecânica full-to-full).
        Badge(id: "fuel_1",  title: "1º abastecimento", assetName: "firstFuel", group: .universal,
              detail: "Seu primeiro abastecimento com tanque cheio registrado. Ele é a âncora do cálculo de consumo.",
              requiredFullTanks: 1),
        Badge(id: "fuel_2",  title: "Primeira média", assetName: "firstFuel", group: .universal,
              detail: "Com dois tanques cheios o app já calcula seu consumo (km/l) pelo método full-to-full.",
              requiredFullTanks: 2),
        Badge(id: "fuel_3",  title: "Na média", assetName: "firstFuel", group: .universal,
              detail: "Três tanques cheios desbloqueiam o gráfico de tendência no Resumo — dá para ver se o consumo melhora ou piora.",
              requiredFullTanks: 3),
        Badge(id: "fuel_10", title: "Abastecedor", assetName: "firstFuel", group: .universal,
              detail: "Dez tanques cheios registrados. O hábito virou rotina e os números ficam cada vez mais confiáveis.",
              requiredFullTanks: 10),

        Badge(id: "first_maintenance", title: "1ª manutenção", assetName: "firstMaintenance", group: .universal,
              detail: "Você registrou sua primeira manutenção. Manter o histórico ajuda a prever trocas e a cuidar da moto."),

        Badge(id: "best_consumption", title: "Acima da média", assetName: "bestConsumption", group: .universal,
              detail: "Seu melhor consumo superou a média estimada para a categoria da sua moto. Pilotagem econômica!"),
    ]

    /// Badges de categoria. 5 categorias têm 3 níveis (km); 3 têm 1 nível só.
    /// Nomes seguem PLAN/badges.md §"Categorias".
    static let categoria: [Badge] = [
        // Scooter
        Badge(id: "cat_scooter_1", title: "Urban Rider",   assetName: "scooter", group: .categoria(.scooter), detail: "Você cadastrou uma scooter. Bem-vindo à mobilidade urbana."),
        Badge(id: "cat_scooter_2", title: "Rei da Cidade", assetName: "scooter", group: .categoria(.scooter), detail: "5.000 km rodados em scooters. A cidade é seu território.", requiredKm: levelTwoKm),
        Badge(id: "cat_scooter_3", title: "City Commuter", assetName: "scooter", group: .categoria(.scooter), detail: "20.000 km em scooters. Deslocamento diário dominado.", requiredKm: levelThreeKm),
        // Trail / Big Trail
        Badge(id: "cat_trail_1", title: "Adventure Rider", assetName: "trail", group: .categoria(.trail), detail: "Você cadastrou uma trail/big trail. A aventura começou."),
        Badge(id: "cat_trail_2", title: "Explorador",      assetName: "trail", group: .categoria(.trail), detail: "5.000 km de aventura registrados.", requiredKm: levelTwoKm),
        Badge(id: "cat_trail_3", title: "Sem Destino",     assetName: "trail", group: .categoria(.trail), detail: "20.000 km em trails. O caminho é o destino.", requiredKm: levelThreeKm),
        // Custom / Cruiser
        Badge(id: "cat_custom_1", title: "Road Captain",  assetName: "custom", group: .categoria(.custom), detail: "Você cadastrou uma custom/cruiser. Estrada e estilo."),
        Badge(id: "cat_custom_2", title: "Long Road",     assetName: "custom", group: .categoria(.custom), detail: "5.000 km em customs registrados.", requiredKm: levelTwoKm),
        Badge(id: "cat_custom_3", title: "Highway Rider", assetName: "custom", group: .categoria(.custom), detail: "20.000 km de estrada na sua custom.", requiredKm: levelThreeKm),
        // Street / Naked
        Badge(id: "cat_street_1", title: "Street Fighter", assetName: "street", group: .categoria(.street), detail: "Você cadastrou uma street/naked. A rua é sua."),
        Badge(id: "cat_street_2", title: "Urban Warrior",  assetName: "street", group: .categoria(.street), detail: "5.000 km em streets registrados.", requiredKm: levelTwoKm),
        Badge(id: "cat_street_3", title: "Asphalt Rider",  assetName: "street", group: .categoria(.street), detail: "20.000 km de asfalto na sua naked.", requiredKm: levelThreeKm),
        // Esportiva
        Badge(id: "cat_sport_1", title: "Speed Demon", assetName: "sport", group: .categoria(.sport), detail: "Você cadastrou uma esportiva. Adrenalina no cadastro."),
        Badge(id: "cat_sport_2", title: "Track Soul",  assetName: "sport", group: .categoria(.sport), detail: "5.000 km na sua esportiva.", requiredKm: levelTwoKm),
        Badge(id: "cat_sport_3", title: "Redline Club", assetName: "sport", group: .categoria(.sport), detail: "20.000 km de pura emoção.", requiredKm: levelThreeKm),
        // Nível único.
        Badge(id: "cat_touring_1", title: "Estradeiro",   assetName: "touring", group: .categoria(.touring), detail: "Você cadastrou uma touring. Longas distâncias com conforto."),
        Badge(id: "cat_offroad_1", title: "Off-road",     assetName: "offroad", group: .categoria(.offroad), detail: "Você cadastrou uma moto off-road. Fora do asfalto."),
        Badge(id: "cat_other_1",   title: "Motociclista", assetName: "other",   group: .categoria(.other),   detail: "Toda moto conta. Bem-vindo à garagem."),
    ]
}

/// Snapshot da FROTA que decide unlock + visibilidade — desacoplado de SwiftData
/// para o motor ser testável com valores puros.
struct BadgeFleetContext {
    let hasMotorcycle: Bool
    let hasMaintenanceLog: Bool
    /// Total de tanques CHEIOS registrados na frota (marcos de abastecimento).
    let fullTankCount: Int
    /// Algum km/l medido superou a régua estimada da categoria daquela moto.
    let beatsCategoryAverage: Bool
    /// Categorias que o usuário já cadastrou (ao menos 1 moto) → o que fica VISÍVEL.
    let presentCategories: Set<MotorcycleCategory>
    /// Km rodados por categoria (soma de `currentOdometer − odometerBaseline`)
    /// → decide os níveis II/III.
    let kmByCategory: [MotorcycleCategory: Double]
}

enum BadgeEvaluator {
    /// Badges que devem APARECER (universais sempre + só categorias presentes).
    /// Ordem do catálogo preservada.
    static func visibleBadges(_ ctx: BadgeFleetContext) -> [Badge] {
        Badge.all.filter { badge in
            switch badge.group {
            case .universal:
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
        if ctx.hasMaintenanceLog  { ids.insert("first_maintenance") }
        if ctx.beatsCategoryAverage { ids.insert("best_consumption") }

        // Abastecimentos: cada marco compara o total de cheios.
        for badge in Badge.universais where badge.requiredFullTanks > 0 {
            if ctx.fullTankCount >= badge.requiredFullTanks {
                ids.insert(badge.id)
            }
        }

        // Categorias presentes: nível I sempre; II/III por km.
        for badge in Badge.categoria {
            guard case .categoria(let cat) = badge.group,
                  ctx.presentCategories.contains(cat) else { continue }
            let km = ctx.kmByCategory[cat] ?? 0
            if km >= badge.requiredKm {
                ids.insert(badge.id)
            }
        }
        return ids
    }
}
