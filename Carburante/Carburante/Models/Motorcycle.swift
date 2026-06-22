//
//  Motorcycle.swift
//  Carburante
//
//  Modelo da moto. Campos `make`/`model`/`year` separados para derivar
//  categoria e comparar consumo real vs. fabricante no futuro (ver PLAN/).
//  `category` e `manufacturerConsumption` ficam nulos no MVP (backfill depois).
//

import Foundation
import SwiftData

@Model
final class Motorcycle {
    /// ID estável (gerado no app) usado como PK no Supabase — casa o sync sem round-trip.
    var id: UUID = UUID()
    var make: String
    var model: String
    var year: Int
    /// País onde a moto foi vendida/registrada — fonte de verdade do catálogo
    /// de specs do modelo. Não confundir com país do usuário ou do abastecimento.
    var country: String
    /// Hodômetro efetivo da moto = maior entre a leitura manual de cadastro
    /// (`odometerBaseline`) e o maior odômetro dos abastecimentos. Mantido por
    /// `reconcileOdometer(latestEntry:)` ao inserir/editar/excluir um registro.
    var currentOdometer: Double
    /// Leitura MANUAL de hodômetro informada no cadastro/edição da moto. É o
    /// piso de `currentOdometer` independente dos abastecimentos — assim, excluir
    /// o abastecimento mais recente não zera o hodômetro de uma moto cujo valor
    /// veio do cadastro. Default 0 → migração leve (mesmo padrão de `isFullTank`).
    var odometerBaseline: Double = 0
    /// Segmento da moto (street/scooter/trail/...). Escolhido no cadastro.
    /// Base do comparativo de consumo por categoria. Persistido por rawValue
    /// (ver `MotorcycleCategory`); opcional p/ não quebrar motos já gravadas.
    var category: String?
    /// Cilindrada em cc (ex.: 160, 300, 650). Junto com `category` alimenta o
    /// comparativo. Opcional → zero migração quebrada para motos antigas.
    var displacementCC: Int?
    /// Consumo informado pelo fabricante (km/l). Nulo no MVP — backfill depois.
    var manufacturerConsumption: Double?
    var createdAt: Date

    /// Abastecimentos da moto. Apagar a moto apaga seus abastecimentos.
    @Relationship(deleteRule: .cascade, inverse: \FuelLog.motorcycle)
    var fuelLogs: [FuelLog] = []

    /// Manutenções da moto. Apagar a moto apaga suas manutenções.
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceLog.motorcycle)
    var maintenanceLogs: [MaintenanceLog] = []

    init(
        make: String,
        model: String,
        year: Int,
        country: String,
        currentOdometer: Double = 0,
        category: String? = nil,
        displacementCC: Int? = nil,
        manufacturerConsumption: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.make = make
        self.model = model
        self.year = year
        self.country = country
        self.currentOdometer = currentOdometer
        // No cadastro, o hodômetro informado É a leitura manual de referência.
        self.odometerBaseline = currentOdometer
        self.category = category
        self.displacementCC = displacementCC
        self.manufacturerConsumption = manufacturerConsumption
        self.createdAt = createdAt
    }
}

extension Motorcycle {
    /// Rótulo curto para listas/títulos: "Honda CB 500 (2022)".
    var displayName: String {
        "\(make) \(model) (\(year))"
    }

    /// Categoria tipada. Getter tolerante (valor desconhecido → `.other`),
    /// setter grava o rawValue. Mesmo padrão de `FuelLog.fuelType`.
    var categoryEnum: MotorcycleCategory? {
        get { category.flatMap(MotorcycleCategory.init(rawValue:)) }
        set { category = newValue?.rawValue }
    }

    /// Reconcilia `currentOdometer` com a verdade após inserir, editar ou
    /// excluir um abastecimento: maior entre a leitura manual de cadastro
    /// (`odometerBaseline`), o maior odômetro dos abastecimentos e `latestEntry`
    /// (o registro recém-salvo, passado explicitamente para não depender do
    /// momento em que a relação SwiftData atualiza o array `fuelLogs`).
    ///
    /// Excluir o abastecimento mais recente cai naturalmente para o próximo
    /// maior — ou para o `odometerBaseline` se não houver mais abastecimentos,
    /// nunca para zero (corrige o bug do hodômetro preso após exclusão).
    func reconcileOdometer(latestEntry: Double = 0) {
        let logsMax = fuelLogs.map(\.odometer).max() ?? 0
        // Migração preguiçosa: motos gravadas antes deste campo têm
        // `odometerBaseline == 0`. Se o hodômetro atual excede tudo que os
        // abastecimentos explicam, esse excedente veio de uma leitura manual —
        // preserva como baseline para a reconciliação não zerar o valor.
        if odometerBaseline == 0 && currentOdometer > max(logsMax, latestEntry) {
            odometerBaseline = currentOdometer
        }
        currentOdometer = max(odometerBaseline, logsMax, latestEntry)
    }
}
