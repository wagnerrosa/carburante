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
    /// (`odometerBaseline`) e o maior km dos abastecimentos e das manutenções.
    /// Mantido por `reconcileOdometer(latestEntry:)` ao inserir/editar/excluir
    /// um registro. O piso do abastecimento NÃO é este valor: ver
    /// `fuelOdometerFloor`.
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
    /// Exclusão lógica (Soft Revision). Não-nil = moto excluída pelo usuário: some
    /// da leitura (as `@Query` filtram por `activePredicate`) mas a linha fica
    /// para o sync propagar o delete. Um delete físico não chegava ao Supabase e
    /// o pull aditivo ressuscitava a moto no launch seguinte. Default nil →
    /// migração leve.
    var deletedAt: Date?

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

    // MARK: - Exclusão lógica da moto

    /// Filtro das `@Query`/fetches de leitura: só motos não excluídas.
    static var activePredicate: Predicate<Motorcycle> {
        #Predicate<Motorcycle> { $0.deletedAt == nil }
    }

    /// Exclui a moto logicamente e, em cascata, seus abastecimentos e manutenções
    /// (cada filho carimba o próprio `deletedAt`/`updatedAt` → o push propaga e o
    /// pull LWW dos outros devices aplica). Idempotente.
    func softDelete(now: Date = Date()) {
        guard deletedAt == nil else { return }
        deletedAt = now
        for log in fuelLogs { log.softDelete(now: now) }
        for log in maintenanceLogs { log.softDelete(now: now) }
    }

    // MARK: - Eventos vivos (Soft Revision — Fase 1)

    /// Abastecimentos NÃO deletados logicamente. Fonte única para toda leitura
    /// de negócio (consumo, totais, histórico, hodômetro, badges) — um log
    /// soft-deletado deixa de existir para o usuário. O array cru `fuelLogs`
    /// (com deletados) só é usado pelo sync, que precisa propagar o delete.
    var activeFuelLogs: [FuelLog] {
        fuelLogs.filter { $0.deletedAt == nil }
    }

    /// Manutenções NÃO deletadas logicamente. Mesma regra de `activeFuelLogs`.
    var activeMaintenanceLogs: [MaintenanceLog] {
        maintenanceLogs.filter { $0.deletedAt == nil }
    }

    /// Categoria tipada. Getter tolerante (valor desconhecido → `.other`),
    /// setter grava o rawValue. Mesmo padrão de `FuelLog.fuelType`.
    var categoryEnum: MotorcycleCategory? {
        get { category.flatMap(MotorcycleCategory.init(rawValue:)) }
        set { category = newValue?.rawValue }
    }

    /// Aplica o hodômetro do form de EDIÇÃO da moto. Só regrava a leitura de
    /// referência (`odometerBaseline`) se o usuário MUDOU o campo: o form carrega
    /// o hodômetro efetivo, e regravar sempre fazia `baseline = currentOdometer`
    /// a cada edição (trocar o nome/ano bastava) — zerava `distanceSinceBaseline`
    /// e o km das medalhas de categoria (nível II/III voltavam a bloquear).
    func applyEditedOdometer(_ entered: Double?, loaded: Double?) {
        guard entered != loaded else { return }
        odometerBaseline = entered ?? 0
        reconcileOdometer()
    }

    /// Reconcilia `currentOdometer` com a verdade após inserir, editar ou
    /// excluir um registro: maior entre a leitura manual de cadastro
    /// (`odometerBaseline`), o maior km dos abastecimentos e das manutenções e
    /// `latestEntry` (o registro recém-salvo, passado explicitamente para não
    /// depender do momento em que a relação SwiftData atualiza o array).
    ///
    /// Manutenção conta desde 2026-10-01: o km dela é outra leitura do painel
    /// (troca de óleo com km acima do último abastecimento = a moto andou), e o
    /// "faltam X km" ficava maior que o real até o próximo abastecimento.
    ///
    /// Excluir o registro mais recente cai naturalmente para o próximo maior —
    /// ou para o `odometerBaseline` se não houver mais registros, nunca para
    /// zero (corrige o bug do hodômetro preso após exclusão).
    func reconcileOdometer(latestEntry: Double = 0) {
        // Só registros vivos: soft-deletar o mais recente recua o hodômetro
        // para o próximo maior (ou o baseline), igual ao delete físico antigo.
        let logsMax = readingsMax()
        // Migração preguiçosa: motos gravadas antes deste campo têm
        // `odometerBaseline == 0`. Se o hodômetro atual excede tudo que os
        // abastecimentos explicam, esse excedente veio de uma leitura manual —
        // preserva como baseline para a reconciliação não zerar o valor.
        if odometerBaseline == 0 && currentOdometer > max(logsMax, latestEntry) {
            odometerBaseline = currentOdometer
        }
        currentOdometer = max(odometerBaseline, logsMax, latestEntry)
    }

    /// Maior km registrado (abastecimentos + manutenções vivos). `excluding`
    /// tira uma manutenção e os itens dela — a que está sendo editada.
    func readingsMax(excluding log: MaintenanceLog? = nil) -> Double {
        let fuel = activeFuelLogs.map(\.odometer).max() ?? 0
        let maintenance = activeMaintenanceLogs
            .filter { log == nil || ($0.id != log?.id && $0.partOfMaintenanceID != log?.id) }
            .map(\.mileage).max() ?? 0
        return max(fuel, maintenance)
    }

    /// Piso do hodômetro para um abastecimento: leitura do cadastro + maior km
    /// dos abastecimentos. Manutenção fica de fora de propósito: o km dela
    /// costuma vir arredondado da nota da oficina ("12.500") e não pode travar
    /// um abastecimento real em 12.450 — ela só avança o hodômetro exibido.
    /// Também é a referência do "+X km desde o último" e do km/l ao vivo.
    var fuelOdometerFloor: Double {
        max(odometerBaseline, activeFuelLogs.map(\.odometer).max() ?? 0)
    }
}
