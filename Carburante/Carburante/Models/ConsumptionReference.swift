//
//  ConsumptionReference.swift
//  Carburante
//
//  Tabela de referência de consumo (km/l, gasolina) por CATEGORIA × faixa de
//  CILINDRADA. É uma ESTIMATIVA "mais ou menos" — média grosseira do segmento,
//  consolidada de testes de imprensa BR (gasolina, uso misto cidade+estrada).
//  Serve para o usuário ter uma régua de comparação já no 1º mês, antes de
//  termos massa de dados.
//
//  Camadas de comparação (ordem de chegada):
//   1. AGORA — média estimada da categoria (esta tabela). Funciona com 1 usuário.
//   2. DEPOIS — a moto contra ela mesma no tempo (precisa histórico > ~1 mês).
//   3. FUTURO — contra outros usuários da mesma moto (precisa massa de usuários).
//
//  Pura, sem UI, sem SwiftData → testável por XCTest. Lógica de tabela única,
//  fácil de refinar (valores são estimativa, não verdade — a verdade do app é o
//  consumo medido full-to-full do próprio usuário).
//

import Foundation

enum ConsumptionReference {
    /// Faixas de cilindrada usadas para agrupar a referência.
    /// `contains(_:)` casa o cc da moto à faixa.
    enum DisplacementBand: CaseIterable {
        case upTo150        // até 150cc
        case from150to300   // 150–300cc
        case from300to500   // 300–500cc
        case from500to800   // 500–800cc
        case above800       // 800cc+

        static func band(for cc: Int) -> DisplacementBand {
            switch cc {
            case ..<150:     return .upTo150
            case 150..<300:  return .from150to300
            case 300..<500:  return .from300to500
            case 500..<800:  return .from500to800
            default:         return .above800
            }
        }
    }

    /// km/l estimado típico (gasolina, uso misto) para uma categoria + cc.
    /// nil quando a combinação não tem referência defensável (ex.: off-road de
    /// competição, scooter de cilindrada alta inexistente no mercado).
    ///
    /// Valores são o ponto médio da faixa observada nos testes BR — estimativa
    /// grosseira de propósito, para uma régua "mais ou menos", não previsão.
    static func expectedKmPerLiter(category: MotorcycleCategory, displacementCC cc: Int) -> Double? {
        guard cc > 0 else { return nil }
        let band = DisplacementBand.band(for: cc)

        switch (category, band) {
        case (.street, .upTo150):       return 42
        case (.street, .from150to300):  return 29
        case (.street, .from300to500):  return 25
        case (.street, .from500to800):  return 20
        case (.street, .above800):      return 16

        case (.scooter, .upTo150):      return 42
        case (.scooter, .from150to300): return 34
        case (.scooter, .from300to500): return 22
        case (.scooter, _):             return nil   // scooter grande ~inexistente no BR

        case (.trail, .upTo150):        return 37
        case (.trail, .from150to300):  return 31
        case (.trail, .from300to500):  return 26
        case (.trail, .from500to800):  return 22
        case (.trail, .above800):      return 18

        case (.sport, .upTo150):        return 38
        case (.sport, .from150to300):  return 27
        case (.sport, .from300to500):  return 25
        case (.sport, .from500to800):  return 19
        case (.sport, .above800):      return 14

        case (.custom, .upTo150):       return 37
        case (.custom, .from150to300): return 30
        case (.custom, .from300to500): return 29
        case (.custom, .from500to800): return 23
        case (.custom, .above800):     return 18

        case (.touring, .from500to800): return 24
        case (.touring, .above800):    return 17
        case (.touring, _):            return nil    // touring pequena rara

        case (.offroad, .upTo150):      return 35
        case (.offroad, .from150to300): return 28
        case (.offroad, _):             return nil   // competição: km/l não publicado

        case (.other, _):              return nil    // sem categoria → sem referência
        }
    }
}

extension Motorcycle {
    /// km/l estimado da categoria desta moto (régua de comparação). nil se a moto
    /// não tem categoria/cilindrada cadastradas ou a combinação não tem referência.
    var categoryReferenceKmPerLiter: Double? {
        guard let cat = categoryEnum, let cc = displacementCC else { return nil }
        return ConsumptionReference.expectedKmPerLiter(category: cat, displacementCC: cc)
    }
}
