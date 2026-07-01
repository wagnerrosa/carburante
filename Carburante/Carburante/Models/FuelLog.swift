//
//  FuelLog.swift
//  Carburante
//
//  Abastecimento. Relação Motorcycle 1—N FuelLog.
//  Campos de localização e metadados OCR ficam nulos no MVP (Fases 6/7).
//  `temperatureC` nulo no MVP — backfill por API depois (lat/long + data).
//

import Foundation
import SwiftData

/// Tipos de combustível comuns no Brasil. `.rawValue` é persistido (String),
/// não o índice — adicionar casos no futuro não corrompe dados existentes.
enum FuelType: String, CaseIterable, Codable, Identifiable {
    case gasolinaComum = "Gasolina comum"
    case gasolinaAditivada = "Gasolina aditivada"
    case etanol = "Etanol"
    case diesel = "Diesel"
    case gnv = "GNV"

    var id: String { rawValue }
}

@Model
final class FuelLog {
    /// ID estável (gerado no app) usado como PK no Supabase.
    var id: UUID = UUID()
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    /// Persistido como String (rawValue de `FuelType`) via `fuelType`.
    var fuelTypeRaw: String
    /// Encheu o tanque? Consumo só é calculado entre dois abastecimentos
    /// cheios (litros de parciais intermediários são somados). Ver `ConsumptionCalculator`.
    /// Default na declaração permite migração leve de stores antigos.
    var isFullTank: Bool = true

    // Contexto — nulo no MVP (Fase 7 GPS preenche).
    var latitude: Double?
    var longitude: Double?
    var city: String?
    var state: String?
    var country: String?

    /// Nulo no MVP — backfill por API (OpenWeather Time Machine) depois.
    var temperatureC: Double?

    // Metadados OCR — nulo no MVP (Fase 6).
    var receiptImageURL: String?
    /// URL/caminho da foto do hodômetro (comprovante de leitura). Nulo no MVP —
    /// quando o Storage existir, guarda a foto que prova o km rodado (base para
    /// o diff foto-anterior e auditoria anti-burla dos desafios Iron Butt).
    var odometerPhotoURL: String?
    var ocrProcessed: Bool
    var ocrConfidence: Double?

    // Proveniência / auditoria — base anti-burla (desafios Iron Butt no futuro).
    // Marca se o usuário alterou MANUALMENTE o contexto auto-capturado: uma data
    // ou local mexido à mão é sinal de possível fraude num desafio de distância.
    // Default false (zero migração quebrada — mesmo padrão de `isFullTank`).
    var dateWasEdited: Bool = false
    var locationWasEdited: Bool = false

    // Soft Revision (Fase 1 — ver PLAN/metadados-auditoria.md). Infra mínima de
    // auditoria/sync, invisível ao usuário. Defaults → migração leve.
    /// Última alteração da linha. Fonte de verdade da reconciliação de sync
    /// (last-write-wins): no pull, a linha remota só sobrescreve a local se o
    /// `updatedAt` remoto for mais novo. Setado no criar e a cada editar.
    var updatedAt: Date = Date()
    /// Contador de edições (0 = nunca alterado após criar). Incrementa a cada
    /// edição. Trilha barata — não guarda o QUE mudou (isso é Fase 2).
    var revision: Int = 0
    /// Exclusão lógica: nil = vivo; não-nil = apagado pelo usuário. Some da UI
    /// (leituras usam `Motorcycle.activeFuelLogs`), mas fica no banco e propaga
    /// o delete a outros devices via sync. `nil` no store antigo → tudo vivo.
    var deletedAt: Date?

    var createdAt: Date

    /// Relação inversa: cada abastecimento pertence a uma moto.
    var motorcycle: Motorcycle?

    init(
        date: Date = Date(),
        odometer: Double,
        liters: Double,
        totalCost: Double,
        fuelType: FuelType,
        isFullTank: Bool = true,
        motorcycle: Motorcycle? = nil,
        ocrProcessed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.date = date
        self.odometer = odometer
        self.liters = liters
        self.totalCost = totalCost
        self.fuelTypeRaw = fuelType.rawValue
        self.isFullTank = isFullTank
        self.motorcycle = motorcycle
        self.ocrProcessed = ocrProcessed
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension FuelLog {
    /// Marca a linha como editada: incrementa `revision` e carimba `updatedAt`.
    /// Chamar ao salvar uma edição (não na criação — nasce revision 0).
    func markUpdated(now: Date = Date()) {
        revision += 1
        updatedAt = now
    }

    /// Exclusão lógica: carimba `deletedAt`/`updatedAt` em vez de remover a linha.
    /// A leitura some (via `Motorcycle.activeFuelLogs`) mas o sync propaga o
    /// delete. Idempotente — não re-carimba se já deletado.
    func softDelete(now: Date = Date()) {
        guard deletedAt == nil else { return }
        deletedAt = now
        updatedAt = now
    }
}

extension FuelLog {
    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .gasolinaComum }
        set { fuelTypeRaw = newValue.rawValue }
    }

    /// Preço por litro — derivado, não armazenado.
    var pricePerLiter: Double? {
        guard liters > 0 else { return nil }
        return totalCost / liters
    }

    /// Rótulo curto de localização, ex.: "São Paulo, SP". nil se não capturado.
    var placeLabel: String? {
        let parts = [city, state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
