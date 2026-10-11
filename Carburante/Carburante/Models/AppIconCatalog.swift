//
//  AppIconCatalog.swift
//  Carburante
//
//  Ícones de conquista (Premium — PLAN/premium-mvp.md §3): a medalha que o
//  piloto ganhou vira o ícone do app. Um ícone por ARTE de medalha (os níveis
//  de uma categoria dividem a arte); destrava quando qualquer medalha com
//  aquela arte foi conquistada. Medalhas de marca (logo de fabricante) e Iron
//  Butt ("em breve") ficam de fora. Só exibição: não mexe em pontos, nível nem
//  evidência.
//
//  Os ícones são gerados por `scripts/achievement_icons.py` em
//  `AchievementIcons/conquista-<arte>.icon`. `arts` tem de bater com a lista
//  do script e com `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
//

import Foundation

struct AppIconOption: Identifiable, Equatable {
    /// Nome do ícone alternativo; nil = ícone padrão do app.
    let iconName: String?
    /// Arte da medalha (`Badge.assetName`); nil = padrão (roda em chamas).
    let art: String?
    let title: String
    var id: String { iconName ?? "default" }
}

enum AppIconCatalog {

    /// Artes com ícone, na ordem do seletor (mesma do script).
    static let arts = [
        "firstFuel", "firstMaintenance", "bestConsumption", "piston",
        "scooter", "sport", "trail", "offroad", "street", "custom", "touring", "other",
    ]

    static let defaultOption = AppIconOption(iconName: nil, art: nil, title: "Padrão")

    static let options: [AppIconOption] = [defaultOption] + arts.map {
        AppIconOption(iconName: iconName(for: $0), art: $0, title: title(for: $0))
    }

    static func iconName(for art: String) -> String { "conquista-\(art)" }

    /// Nome no seletor = o da medalha mais fácil com aquela arte (a que o piloto
    /// conhece da Garagem). O pistão é de vários clubes de cilindrada → nome do grupo.
    static func title(for art: String) -> String {
        if art == "piston" { return "Clube de cilindrada" }
        return Badge.all.first { $0.assetName == art && !$0.usesBrandLogo }?.title ?? art
    }

    /// Artes liberadas pelas medalhas conquistadas (logo de marca não conta).
    static func unlockedArts(unlockedBadgeIDs: Set<String>) -> Set<String> {
        Set(Badge.all
            .filter { unlockedBadgeIDs.contains($0.id) && !$0.usesBrandLogo }
            .map(\.assetName))
    }

    static func isUnlocked(_ option: AppIconOption, unlockedArts: Set<String>) -> Bool {
        guard let art = option.art else { return true }
        return unlockedArts.contains(art)
    }

    /// Opção do ícone em uso (`UIApplication.alternateIconName`); nome
    /// desconhecido cai no padrão.
    static func option(forIconName name: String?) -> AppIconOption {
        options.first { $0.iconName == name } ?? defaultOption
    }

    /// Opção de uma arte de medalha, se ela tem ícone (nil p/ marca, Iron Butt…).
    static func option(forArt art: String) -> AppIconOption? {
        options.first { $0.art == art }
    }
}
