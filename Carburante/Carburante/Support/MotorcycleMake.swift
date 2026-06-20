//
//  MotorcycleMake.swift
//  Carburante
//
//  Catálogo de marcas de moto comuns no Brasil, para seleção no form em vez
//  de texto livre (reduz inconsistência: "CG" vs "Honda CG"). Não é enum
//  persistido — `Motorcycle.make` continua String livre, então marcas fora
//  da lista (item "Outra…") seguem funcionando sem migração de schema.
//
//  Ordem: marcas de maior volume no Brasil primeiro (Fenabrave 2025 — Honda
//  domina ~67% do mercado), depois premium/importadas comuns. "Outra…" sempre
//  por último, revela campo de texto livre no form.
//

import Foundation

enum MotorcycleMake {
    /// Marca usada quando a moto não está no catálogo — dispara o campo livre.
    static let other = "Outra…"

    /// Marcas do catálogo, na ordem de exibição no Picker. "Outra…" por último.
    static let catalog: [String] = [
        "Honda",
        "Yamaha",
        "BMW",
        "Suzuki",
        "Harley-Davidson",
        "Royal Enfield",
        "Ducati",
        "Kawasaki",
        "Triumph",
        "KTM",
        other,
    ]

    /// True se `make` está no catálogo (não é texto livre / "Outra…").
    static func isKnown(_ make: String) -> Bool {
        catalog.dropLast().contains(make)  // dropLast remove "Outra…"
    }
}
