//
//  Badge.swift
//  Carburante
//
//  Motor de conquistas (ver PLAN/badges.md). Catálogo estático + regra de unlock
//  PURA sobre os dados já persistidos (`Motorcycle`/`FuelLog`/`MaintenanceLog`/
//  `GarageRecords`) — mesmo padrão de `ConsumptionCalculator`: zero UI, testável.
//
//  Modelo de visibilidade (decisão 2026-06-28): seção única "Conquistas".
//  - Universais (abastecimentos, manutenção, melhor consumo): sempre visíveis.
//  - Categorias: o usuário só vê as que JÁ TOCOU (cadastrou ≥1 moto). Categoria
//    nunca cadastrada fica OCULTA. Dentro de uma categoria tocada vê TODOS os
//    níveis (I/II/III).
//  - Marca: badge por marca do CATÁLOGO já cadastrada (Honda Rider, Yamaha
//    Rider…). Usa o LOGO da marca como arte. Marca fora do catálogo ("Outra…")
//    não gera badge (não tem logo). Substitui o antigo "Primeira moto" — a 1ª
//    moto já desbloqueia o badge da sua marca, que é o ponto de partida.
//  - Cilindrada: "clubes" por faixa EXCLUSIVA (uma moto entra em UM clube só).
//    Só os clubes com ≥1 moto na faixa aparecem. Arte = pistão 3D (`piston`).
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
/// para a regra de visibilidade (só categorias tocadas aparecem). `marca` carrega
/// a chave normalizada da marca; `cilindrada` carrega o limite do clube (cc).
enum BadgeGroup: Equatable {
    case universal
    case categoria(MotorcycleCategory)
    case marca(String)
    case cilindrada(Int)
}

/// Km (rodados na categoria) para o nível desbloquear. 0 = nível I (cadastrar).
private let levelTwoKm: Double = 5_000
private let levelThreeKm: Double = 20_000

/// Pontos por nível de categoria (I/II/III). Cresce por esforço — chegar ao
/// nível III de uma categoria vale tanto quanto vários marcos de abastecimento.
private let categoryLevelPoints: [Int] = [1, 3, 6]

/// Uma medalha do catálogo. `assetName` é o nome da arte — por padrão um imageset
/// no namespace `Badges` (arte 3D). Quando `usesBrandLogo == true`, `assetName` é
/// o caminho do logo da marca (`BrandLogos/…`) e a UI desenha um `BrandLogoTile`.
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
    /// `assetName` é um logo de marca (`BrandLogos/…`) → desenhar `BrandLogoTile`.
    var usesBrandLogo: Bool = false
    /// Nível desta medalha dentro da sua família (1, 2, 3…). Para famílias de
    /// progressão (categorias com vários níveis), a UI desenha o número num
    /// círculo para que os níveis não pareçam todos iguais.
    var level: Int = 1
    /// Quantos níveis a família tem ao todo. >1 → mostrar o número do nível.
    var levelCount: Int = 1
    /// Medalha especial "em breve": sempre visível, NUNCA desbloqueável (modalidade
    /// futura). A UI dá tratamento premium próprio (colorida + selo "Em breve",
    /// sem cadeado/dessaturação). Hoje só o Iron Butt.
    var isComingSoon: Bool = false
    /// Pontos que esta medalha credita ao nível do perfil (estilo Garmin). Peso por
    /// dificuldade. 0 = não pontua (ex.: `iron_butt`, ainda "em breve"). O total é
    /// DERIVADO de `unlockedIDs` em `BadgeEvaluator.totalPoints` — nada persistido.
    var points: Int = 0
    /// Medalha que pode ser reconquistada (Iron Butt, eventos futuros). Hoje
    /// ninguém marca true: o flag só prepara o terreno para créditos repetidos
    /// (pontos × vezes) sem migrar schema depois. Não persiste nada ainda.
    var isRepeatable: Bool = false
}

extension Badge {
    /// Catálogo completo.
    static let all: [Badge] = universais + marca + cilindrada + categoria

    /// Universais — sempre visíveis. Desbloqueiam de dados que já existem.
    /// (O antigo "Primeira moto" saiu: o badge da MARCA da 1ª moto cumpre o papel.)
    static let universais: [Badge] = [
        // Abastecimentos — marcos por tanque cheio (mecânica full-to-full). Mesma
        // arte 3D (`firstFuel`) → marcados como família de 4 níveis (1→4) para a UI
        // desenhar o número, senão as 4 medalhas ficam idênticas (feedback do usuário).
        Badge(id: "fuel_1",  title: "1º abastecimento", assetName: "firstFuel", group: .universal,
              detail: "Seu primeiro abastecimento com tanque cheio registrado. Ele é a âncora do cálculo de consumo.",
              requiredFullTanks: 1, level: 1, levelCount: 4, points: 1),
        Badge(id: "fuel_2",  title: "Primeira média", assetName: "firstFuel", group: .universal,
              detail: "Com dois tanques cheios o app já calcula seu consumo (km/l) pelo método full-to-full.",
              requiredFullTanks: 2, level: 2, levelCount: 4, points: 2),
        Badge(id: "fuel_3",  title: "Na média", assetName: "firstFuel", group: .universal,
              detail: "Três tanques cheios desbloqueiam o gráfico de tendência no Resumo — dá para ver se o consumo melhora ou piora.",
              requiredFullTanks: 3, level: 3, levelCount: 4, points: 4),
        Badge(id: "fuel_10", title: "Abastecedor", assetName: "firstFuel", group: .universal,
              detail: "Dez tanques cheios registrados. O hábito virou rotina e os números ficam cada vez mais confiáveis.",
              requiredFullTanks: 10, level: 4, levelCount: 4, points: 10),

        Badge(id: "first_maintenance", title: "1ª manutenção", assetName: "firstMaintenance", group: .universal,
              detail: "Você registrou sua primeira manutenção. Manter o histórico ajuda a prever trocas e a cuidar da moto.",
              points: 2),

        Badge(id: "best_consumption", title: "Acima da média", assetName: "bestConsumption", group: .universal,
              detail: "Seu melhor consumo superou a média estimada para a categoria da sua moto. Pilotagem econômica!",
              points: 5),

        // Medalha especial — modalidade futura. Sempre visível, nunca desbloqueia
        // ainda (`isComingSoon`). É o emblema mais raro do app: o desafio Iron Butt.
        // Não pontua até virar conquistável; será repetível (cada feito re-credita).
        Badge(id: "iron_butt", title: "Iron Butt", assetName: "ironButt", group: .universal,
              detail: "A medalha mais cobiçada do motociclismo de longa distância: percorrer 1.600 km em menos de 24 horas. O desafio Iron Butt chega ao Carburante em breve — fique de olho.",
              isComingSoon: true, points: 0, isRepeatable: true),
    ]

    /// Badges de MARCA — um por marca do catálogo (logo como arte). Só aparecem
    /// quando o usuário cadastra uma moto daquela marca. Gerados de
    /// `MotorcycleMake.catalog` (menos "Outra…") para ficarem em sincronia com o
    /// form e os logos de `BrandTheme`. Marca sem logo é simplesmente pulada.
    static let marca: [Badge] = MotorcycleMake.catalog
        .filter { $0 != MotorcycleMake.other }
        .compactMap { make -> Badge? in
            guard let logo = BrandTheme.logoAsset(make: make) else { return nil }
            let key = BrandTheme.normalizedKey(make)
            return Badge(
                id: "make_\(key)",
                title: "\(make) Rider",
                assetName: logo,
                group: .marca(key),
                detail: "Você cadastrou uma \(make) na garagem. A marca virou parte da sua história.",
                usesBrandLogo: true,
                points: 1
            )
        }

    /// Clubes de CILINDRADA — faixa EXCLUSIVA (cada moto entra em um clube só).
    /// Limites: ver `DisplacementClub.club(forCC:)`. Arte = pistão 3D.
    static let cilindrada: [Badge] = DisplacementClub.all.map { club in
        Badge(
            id: "cc_\(club.cc)",
            title: "\(club.cc)cc Club",
            assetName: "piston",
            group: .cilindrada(club.cc),
            detail: club.detail,
            points: 2
        )
    }

    /// Badges de categoria. 5 categorias têm 3 níveis (km); 3 têm 1 nível só.
    /// Nomes seguem PLAN/badges.md §"Categorias".
    static let categoria: [Badge] = [
        // Scooter
        Badge(id: "cat_scooter_1", title: "Urban Rider",   assetName: "scooter", group: .categoria(.scooter), detail: "Você cadastrou uma scooter. Bem-vindo à mobilidade urbana.", level: 1, levelCount: 3, points: categoryLevelPoints[0]),
        Badge(id: "cat_scooter_2", title: "Rei da Cidade", assetName: "scooter", group: .categoria(.scooter), detail: "5.000 km rodados em scooters. A cidade é seu território.", requiredKm: levelTwoKm, level: 2, levelCount: 3, points: categoryLevelPoints[1]),
        Badge(id: "cat_scooter_3", title: "City Commuter", assetName: "scooter", group: .categoria(.scooter), detail: "20.000 km em scooters. Deslocamento diário dominado.", requiredKm: levelThreeKm, level: 3, levelCount: 3, points: categoryLevelPoints[2]),
        // Trail / Big Trail
        Badge(id: "cat_trail_1", title: "Adventure Rider", assetName: "trail", group: .categoria(.trail), detail: "Você cadastrou uma trail/big trail. A aventura começou.", level: 1, levelCount: 3, points: categoryLevelPoints[0]),
        Badge(id: "cat_trail_2", title: "Explorador",      assetName: "trail", group: .categoria(.trail), detail: "5.000 km de aventura registrados.", requiredKm: levelTwoKm, level: 2, levelCount: 3, points: categoryLevelPoints[1]),
        Badge(id: "cat_trail_3", title: "Sem Destino",     assetName: "trail", group: .categoria(.trail), detail: "20.000 km em trails. O caminho é o destino.", requiredKm: levelThreeKm, level: 3, levelCount: 3, points: categoryLevelPoints[2]),
        // Custom / Cruiser ("Road Captain" é o posto mais alto → nível III)
        Badge(id: "cat_custom_1", title: "Highway Rider", assetName: "custom", group: .categoria(.custom), detail: "Você cadastrou uma custom/cruiser. Estrada e estilo.", level: 1, levelCount: 3, points: categoryLevelPoints[0]),
        Badge(id: "cat_custom_2", title: "Long Road",     assetName: "custom", group: .categoria(.custom), detail: "5.000 km em customs registrados.", requiredKm: levelTwoKm, level: 2, levelCount: 3, points: categoryLevelPoints[1]),
        Badge(id: "cat_custom_3", title: "Road Captain",  assetName: "custom", group: .categoria(.custom), detail: "20.000 km de estrada na sua custom. Você é o capitão da estrada.", requiredKm: levelThreeKm, level: 3, levelCount: 3, points: categoryLevelPoints[2]),
        // Street / Naked
        Badge(id: "cat_street_1", title: "Street Fighter", assetName: "street", group: .categoria(.street), detail: "Você cadastrou uma street/naked. A rua é sua.", level: 1, levelCount: 3, points: categoryLevelPoints[0]),
        Badge(id: "cat_street_2", title: "Urban Warrior",  assetName: "street", group: .categoria(.street), detail: "5.000 km em streets registrados.", requiredKm: levelTwoKm, level: 2, levelCount: 3, points: categoryLevelPoints[1]),
        Badge(id: "cat_street_3", title: "Asphalt Rider",  assetName: "street", group: .categoria(.street), detail: "20.000 km de asfalto na sua naked.", requiredKm: levelThreeKm, level: 3, levelCount: 3, points: categoryLevelPoints[2]),
        // Esportiva
        Badge(id: "cat_sport_1", title: "Speed Demon", assetName: "sport", group: .categoria(.sport), detail: "Você cadastrou uma esportiva. Adrenalina no cadastro.", level: 1, levelCount: 3, points: categoryLevelPoints[0]),
        Badge(id: "cat_sport_2", title: "Track Soul",  assetName: "sport", group: .categoria(.sport), detail: "5.000 km na sua esportiva.", requiredKm: levelTwoKm, level: 2, levelCount: 3, points: categoryLevelPoints[1]),
        Badge(id: "cat_sport_3", title: "Redline Club", assetName: "sport", group: .categoria(.sport), detail: "20.000 km de pura emoção.", requiredKm: levelThreeKm, level: 3, levelCount: 3, points: categoryLevelPoints[2]),
        // Nível único.
        Badge(id: "cat_touring_1", title: "Estradeiro",   assetName: "touring", group: .categoria(.touring), detail: "Você cadastrou uma touring. Longas distâncias com conforto.", points: categoryLevelPoints[0]),
        Badge(id: "cat_offroad_1", title: "Off-road",     assetName: "offroad", group: .categoria(.offroad), detail: "Você cadastrou uma moto off-road. Fora do asfalto.", points: categoryLevelPoints[0]),
        Badge(id: "cat_other_1",   title: "Motociclista", assetName: "other",   group: .categoria(.other),   detail: "Toda moto conta. Bem-vindo à garagem.", points: categoryLevelPoints[0]),
    ]
}

/// Clubes de cilindrada — faixa EXCLUSIVA. Cada moto cai em UM clube pela sua
/// cilindrada (cc). O número do clube é o limite INFERIOR da faixa, no jargão de
/// moto ("entrei no clube dos 1000"). Uma Harley 1800cc entra no clube 1000 (é o
/// clube dos litrões, sem precisar de um badge "1800 exato"). Tipo puro, testável.
struct DisplacementClub: Equatable {
    /// Limite que nomeia o clube (125 / 250 / 500 / 800 / 1000).
    let cc: Int
    /// Faixa fechada [lower, upper] de cilindradas que caem neste clube.
    let lower: Int
    let upper: Int
    let detail: String

    /// Todos os clubes, do menor ao maior. O último é aberto no topo.
    static let all: [DisplacementClub] = [
        DisplacementClub(cc: 125,  lower: 0,    upper: 180,
                         detail: "Sua moto está no clube das pequenas (até 180cc). Ágil, econômica e perfeita para a cidade."),
        DisplacementClub(cc: 250,  lower: 181,  upper: 350,
                         detail: "Sua moto entrou no clube das 250 (181–350cc). O equilíbrio entre economia e desempenho."),
        DisplacementClub(cc: 500,  lower: 351,  upper: 650,
                         detail: "Sua moto está no clube das 500 (351–650cc). Versátil para cidade e estrada."),
        DisplacementClub(cc: 800,  lower: 651,  upper: 900,
                         detail: "Sua moto entrou no clube das 800 (651–900cc). Torque de sobra para qualquer viagem."),
        DisplacementClub(cc: 1000, lower: 901,  upper: .max,
                         detail: "Sua moto está no clube dos litrões (acima de 900cc). Potência de verdade entre as pernas."),
    ]

    /// Clube (limite) em que uma cilindrada cai. nil se `cc <= 0` ou ausente.
    static func club(forCC cc: Int) -> Int? {
        guard cc > 0 else { return nil }
        return all.first { cc >= $0.lower && cc <= $0.upper }?.cc
    }
}

/// Snapshot da FROTA que decide unlock + visibilidade — desacoplado de SwiftData
/// para o motor ser testável com valores puros.
struct BadgeFleetContext {
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
    /// Marcas (chave normalizada, do catálogo) já cadastradas → badge de marca.
    let presentMakes: Set<String>
    /// Clubes de cilindrada (limite) com ≥1 moto na faixa → badge de clube.
    let presentDisplacementClubs: Set<Int>
}

enum BadgeEvaluator {
    /// Badges que devem APARECER (universais sempre + só marcas/clubes/categorias
    /// presentes). Ordem do catálogo preservada, EXCETO os "em breve" (Iron Butt),
    /// que vão para o FIM da grade (emblema especial fecha as Conquistas).
    static func visibleBadges(_ ctx: BadgeFleetContext) -> [Badge] {
        Badge.all
            .filter { badge in
                switch badge.group {
                case .universal:
                    return true
                case .categoria(let cat):
                    return ctx.presentCategories.contains(cat)
                case .marca(let key):
                    return ctx.presentMakes.contains(key)
                case .cilindrada(let cc):
                    return ctx.presentDisplacementClubs.contains(cc)
                }
            }
            // Estável: mantém a ordem do catálogo; só empurra os "em breve" p/ o fim.
            .sorted { !$0.isComingSoon && $1.isComingSoon }
    }

    /// IDs das badges conquistadas (regra pura de unlock).
    static func unlockedIDs(_ ctx: BadgeFleetContext) -> Set<String> {
        var ids = Set<String>()

        if ctx.hasMaintenanceLog  { ids.insert("first_maintenance") }
        if ctx.beatsCategoryAverage { ids.insert("best_consumption") }

        // Abastecimentos: cada marco compara o total de cheios.
        for badge in Badge.universais where badge.requiredFullTanks > 0 {
            if ctx.fullTankCount >= badge.requiredFullTanks {
                ids.insert(badge.id)
            }
        }

        // Marca presente → badge conquistado (cadastrar já basta).
        for badge in Badge.marca {
            guard case .marca(let key) = badge.group,
                  ctx.presentMakes.contains(key) else { continue }
            ids.insert(badge.id)
        }

        // Clube de cilindrada presente → conquistado (faixa exclusiva).
        for badge in Badge.cilindrada {
            guard case .cilindrada(let cc) = badge.group,
                  ctx.presentDisplacementClubs.contains(cc) else { continue }
            ids.insert(badge.id)
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

    /// Soma de pontos das medalhas conquistadas → alimenta o nível do perfil
    /// (`ProfileLevel`). DERIVADO de `unlockedIDs` (mesma verdade do grid): nada
    /// persistido, recalcula a cada render. `iron_butt` nunca está em `unlockedIDs`
    /// e vale 0 → não soma. Badges repetíveis ainda não existem (contam 1×).
    static func totalPoints(_ ctx: BadgeFleetContext) -> Int {
        let unlocked = unlockedIDs(ctx)
        return Badge.all
            .filter { unlocked.contains($0.id) }
            .reduce(0) { $0 + $1.points }
    }
}
