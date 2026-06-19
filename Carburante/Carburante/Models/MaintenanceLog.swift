//
//  MaintenanceLog.swift
//  Carburante
//
//  Manutenção da moto. Relação Motorcycle 1—N MaintenanceLog.
//  Espelha o schema do Supabase (type/date/mileage/cost/notes).
//

import Foundation
import SwiftData

/// Tipos comuns de manutenção. `.rawValue` (String) é persistido — adicionar
/// casos no futuro não corrompe dados. "Outro" + `notes` cobre o resto.
enum MaintenanceType: String, CaseIterable, Codable, Identifiable {
    case oleo = "Troca de óleo"
    case filtros = "Filtros"
    case pneus = "Pneus"
    case relacao = "Relação / corrente"
    case freios = "Freios"
    case revisao = "Revisão geral"
    case outro = "Outro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .oleo: return "drop.fill"
        case .filtros: return "air.purifier"
        case .pneus: return "tire"
        case .relacao: return "gearshape.2"
        case .freios: return "pedal.brake.fill"
        case .revisao: return "wrench.and.screwdriver.fill"
        case .outro: return "ellipsis.circle"
        }
    }
}

@Model
final class MaintenanceLog {
    /// ID estável (gerado no app) usado como PK no Supabase.
    var id: UUID = UUID()
    var date: Date
    /// Quilometragem (hodômetro) na manutenção.
    var mileage: Double
    var cost: Double
    var notes: String
    /// Persistido como String (rawValue de `MaintenanceType`) via `type`.
    var typeRaw: String

    var createdAt: Date

    /// Relação inversa: cada manutenção pertence a uma moto.
    var motorcycle: Motorcycle?

    init(
        date: Date = Date(),
        mileage: Double,
        cost: Double = 0,
        notes: String = "",
        type: MaintenanceType,
        motorcycle: Motorcycle? = nil,
        createdAt: Date = Date()
    ) {
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.notes = notes
        self.typeRaw = type.rawValue
        self.motorcycle = motorcycle
        self.createdAt = createdAt
    }
}

extension MaintenanceLog {
    var type: MaintenanceType {
        get { MaintenanceType(rawValue: typeRaw) ?? .outro }
        set { typeRaw = newValue.rawValue }
    }
}
