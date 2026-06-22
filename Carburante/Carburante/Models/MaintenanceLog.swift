//
//  MaintenanceLog.swift
//  Carburante
//
//  Manutenção da moto. Relação Motorcycle 1—N MaintenanceLog.
//  Espelha o schema do Supabase
//  (type/date/mileage/cost/notes/oil_change_interval_km).
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

    /// Chave ASCII estável (sem espaços/acentos) p/ identificadores de
    /// notificação (`maint-<chave>-<eixo>`). Não persiste — derivada do caso.
    var identifierKey: String {
        switch self {
        case .oleo: return "oleo"
        case .filtros: return "filtros"
        case .pneus: return "pneus"
        case .relacao: return "relacao"
        case .freios: return "freios"
        case .revisao: return "revisao"
        case .outro: return "outro"
        }
    }

    /// Intervalo padrão sugerido por km (nil = sem sugestão de eixo km).
    /// Conservador p/ uso comum no Brasil; o usuário sempre pode alterar.
    /// Ver PLAN/manutencao-programada.md §3.
    var defaultIntervalKm: Double? {
        switch self {
        case .oleo: return 3_000
        case .filtros: return 6_000
        case .freios: return 10_000
        case .pneus: return 12_000
        case .relacao: return 20_000
        case .revisao: return 10_000
        case .outro: return nil
        }
    }

    /// Intervalo padrão sugerido por tempo (em meses; nil = sem sugestão de eixo
    /// tempo). Tempo em meses dá math de calendário exata e UI amigável.
    var defaultIntervalMonths: Int? {
        switch self {
        case .oleo: return 6
        case .filtros: return 12
        case .freios: return 12
        case .pneus: return 60
        case .relacao: return 36
        case .revisao: return 12
        case .outro: return nil
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
    /// Intervalo por km escolhido nesta manutenção para calcular a próxima do
    /// mesmo tipo. Nil → cai no padrão do tipo (`effectiveIntervalKm`).
    /// Renomeado de `oilChangeIntervalKm` (migração leve via `originalName`) ao
    /// generalizar para todos os tipos — ver PLAN/manutencao-programada.md.
    @Attribute(originalName: "oilChangeIntervalKm")
    var intervalKm: Double?
    /// Intervalo por tempo (em meses) escolhido nesta manutenção. Nil → padrão
    /// do tipo. Antes o tempo era uma constante global só de óleo (180 dias).
    var intervalMonths: Int?
    /// Fase B (combo Revisão Geral): aponta para o log da Revisão Geral que
    /// gerou este item. Nil em registros avulsos e em tudo da Fase A.
    /// Declarado já para evitar uma segunda migração.
    var partOfMaintenanceID: UUID?
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
        intervalKm: Double? = nil,
        intervalMonths: Int? = nil,
        partOfMaintenanceID: UUID? = nil,
        motorcycle: Motorcycle? = nil,
        createdAt: Date = Date()
    ) {
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.notes = notes
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.partOfMaintenanceID = partOfMaintenanceID
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

    /// Intervalo por km efetivo: o personalizado nesta manutenção, senão o padrão
    /// do tipo. Nil quando o tipo não tem padrão de km (ex.: "Outro") e nenhum
    /// foi informado → o eixo km não é acompanhado.
    var effectiveIntervalKm: Double? {
        if let intervalKm, intervalKm > 0 { return intervalKm }
        return type.defaultIntervalKm
    }

    /// Intervalo por tempo (meses) efetivo: o personalizado, senão o padrão do
    /// tipo. Nil → o eixo tempo não é acompanhado.
    var effectiveIntervalMonths: Int? {
        if let intervalMonths, intervalMonths > 0 { return intervalMonths }
        return type.defaultIntervalMonths
    }
}
