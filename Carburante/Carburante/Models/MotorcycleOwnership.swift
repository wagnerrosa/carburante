//
//  MotorcycleOwnership.swift
//  Carburante
//
//  Relação de PROPRIEDADE entre um usuário e uma motocicleta, modelada à parte
//  da moto de propósito. A moto (`Motorcycle`) é a entidade permanente com
//  identidade própria (`Motorcycle.id` nunca muda); QUEM a possui, e em qual
//  período, vive aqui. No MVP existe sempre exatamente UM registro ativo
//  (`endedAt == nil`) por moto — mas a estrutura já suporta troca de dono,
//  histórico cronológico de proprietários e histórico de motos de um usuário,
//  sem remodelar nada (só fechar a linha ativa e abrir outra numa venda futura).
//
//  Fonte de verdade CONCEITUAL da propriedade. A coluna legada
//  `motorcycles.user_id` (e o `user_id` denormalizado em fuel/maintenance)
//  sobrevive só por compatibilidade + performance de RLS; código novo NÃO deve
//  ler `user_id` como sinal de dono — deriva daqui (linha ativa). Ver
//  PLAN + memory motorcycle-ownership.
//
//  Referência SOLTA por UUID (`motorcycleID`), não um `@Relationship` do
//  SwiftData: o ponto é a moto sobreviver a qualquer dono, então um vínculo
//  rígido com cascade acoplaria os dois. Mesmo padrão do `BadgeAward` (um
//  @Model sem relação dura). Espelha a tabela `motorcycle_ownerships`.
//

import Foundation
import SwiftData

@Model
final class MotorcycleOwnership {
    /// ID estável (gerado no app) usado como PK no Supabase — casa o sync sem round-trip.
    var id: UUID = UUID()
    /// A moto possuída — identidade permanente (`Motorcycle.id`). Referência solta.
    var motorcycleID: UUID
    /// O dono — id da sessão do Supabase Auth (`auth.users.id`).
    var userID: UUID
    /// Quando a propriedade começou.
    var startedAt: Date
    /// Quando terminou. `nil` = ainda é o dono (a linha ATIVA). Preenchido numa
    /// transferência futura (fecha esta linha, abre outra para o novo dono).
    var endedAt: Date?
    /// Espelho conveniente de `endedAt == nil` — deixa a busca do dono atual
    /// trivial e indexável. Mantido em sincronia por `init` e por `end()`.
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(
        motorcycleID: UUID,
        userID: UUID,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.motorcycleID = motorcycleID
        self.userID = userID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isActive = endedAt == nil
        self.createdAt = createdAt
    }
}

extension MotorcycleOwnership {
    /// Fecha a propriedade num dado instante (base da transferência futura).
    /// Mantém `isActive` coerente com `endedAt`. Não usado pelo MVP.
    func end(at date: Date = Date()) {
        endedAt = date
        isActive = false
    }

    /// Garante uma propriedade ATIVA para cada moto que ainda não tem uma,
    /// atribuída ao `userID` informado (a sessão atual). Idempotente — rodar de
    /// novo é no-op. É a migração para dados anteriores a esta feature: motos
    /// criadas antes ganham a linha de propriedade no 1º sync, sem ação do
    /// usuário. Mesmo padrão de `BadgeAward.reconcile`.
    ///
    /// `startedAt` de cada linha nova = `createdAt` da moto (a melhor verdade
    /// que temos de quando a posse começou).
    ///
    /// Retorna true se criou algo (caller decide sincronizar).
    @discardableResult
    @MainActor
    static func backfillActive(
        for motorcycles: [Motorcycle],
        userID: UUID,
        in context: ModelContext
    ) -> Bool {
        guard !motorcycles.isEmpty else { return false }
        let existing = (try? context.fetch(FetchDescriptor<MotorcycleOwnership>())) ?? []
        // Motos que já têm uma linha ativa não recebem outra.
        let motosWithActive = Set(existing.filter { $0.endedAt == nil }.map(\.motorcycleID))

        var created = false
        for moto in motorcycles where !motosWithActive.contains(moto.id) {
            context.insert(
                MotorcycleOwnership(
                    motorcycleID: moto.id,
                    userID: userID,
                    startedAt: moto.createdAt,
                    endedAt: nil
                )
            )
            created = true
        }
        return created
    }
}
