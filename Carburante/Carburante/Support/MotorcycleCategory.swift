//
//  MotorcycleCategory.swift
//  Carburante
//
//  Categoria/segmento da moto, escolhida no cadastro. Junto com a cilindrada
//  (`Motorcycle.displacementCC`) é a base do comparativo de consumo por
//  categoria — sinal imediato antes do catálogo de modelo exato (Fase 2, ver
//  PLAN/roadmap.md). Persistida por `.rawValue` (String) em `Motorcycle.category`,
//  mesmo padrão de `FuelType`: extensível sem migração de schema, valores fora
//  do enum não quebram (decodificação tolerante via accessor).
//

import Foundation

enum MotorcycleCategory: String, CaseIterable, Identifiable {
    case street       // Street/naked urbana (CG, Fazer, MT) — maior volume no BR
    case scooter      // Automática, CVT (PCX, NMAX, Burgman)
    case trail        // Trail / big trail / adventure (XRE, Lander, GS, Tenéré)
    case sport        // Esportiva carenada (CBR, R, Ninja)
    case custom       // Custom / cruiser (Harley, Meteor, Vulcan)
    case touring      // Touring / sport-touring de longa distância
    case offroad      // Off-road / cross / enduro (sem placa típico)
    case other        // Fora do catálogo

    var id: String { rawValue }

    /// Rótulo pt-BR para o Picker.
    var label: String {
        switch self {
        case .street:  return "Street / Naked"
        case .scooter: return "Scooter"
        case .trail:   return "Trail / Big Trail"
        case .sport:   return "Esportiva"
        case .custom:  return "Custom / Cruiser"
        case .touring: return "Touring"
        case .offroad: return "Off-road / Trilha"
        case .other:   return "Outra"
        }
    }
}
