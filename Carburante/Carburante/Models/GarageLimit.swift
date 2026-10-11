//
//  GarageLimit.swift
//  Carburante
//
//  Limite da garagem no plano grátis (PLAN/premium-mvp.md §1): uma moto ativa.
//  Decide "pode cadastrar outra moto?" e "esta moto aceita registro?". Regra
//  DERIVADA — nada persistido, nada que o usuário marque — e pura: recebe as
//  motos como valores simples, testável sem SwiftData nem StoreKit. Quem lê o
//  app e entrega a decisão às telas é o `GarageAccess` (Views/GarageGate.swift).
//
//  Só para consulta = sem novo abastecimento, manutenção ou edição naquela
//  moto. Ver, histórico, gráfico, custos e exportar seguem livres; nada é
//  apagado.
//

import Foundation

enum GarageLimit {
    /// Data de corte do Premium: moto criada antes dela nunca fica só para
    /// consulta — quem já tinha várias motos não paga por elas.
    ///
    /// ⚠️ ATUALIZAR no envio da 1.1 para o dia do arquivo enviado à revisão
    /// (checklist em PLAN/app-store/envio.md). Antes disso o revisor cadastraria
    /// a 2ª moto "antes do lançamento" e nunca veria o limite; muito depois,
    /// motos criadas na 1.1 escapariam do limite. 20/10/2026 00:00 BRT
    /// (provisório).
    static let premiumLaunch = Date(timeIntervalSince1970: 1_792_465_200)

    /// Moto à venda segue aceitando registro por este tempo depois que a nova
    /// chega: troca de moto não é Premium.
    static let saleGraceDays = 30

    /// O que a regra precisa saber de cada moto.
    struct Bike: Equatable {
        let id: UUID
        let status: MotorcycleStatus
        let createdAt: Date
        /// Último registro feito nela (ou o cadastro, sem registro). Desempata
        /// quem segue ativa quando duas disputam a vaga.
        let lastActivity: Date
    }

    struct Access: Equatable {
        /// Cadastrar mais uma moto sem Premium.
        let canAddMotorcycle: Bool
        /// Motos (não vendidas) só para consulta.
        let readOnlyIDs: Set<UUID>

        static let unlimited = Access(canAddMotorcycle: true, readOnlyIDs: [])

        func isReadOnly(_ id: UUID) -> Bool { readOnlyIDs.contains(id) }
    }

    /// Decide o acesso da garagem. Vendida não entra em nada: já é só consulta
    /// por ser vendida, não pelo limite.
    ///
    /// * **Cadastrar:** sem moto ativa na garagem e no máximo uma à venda
    ///   (trocar de moto = colocar a atual à venda e cadastrar a nova; uma
    ///   troca por vez).
    /// * **Vaga:** uma moto. Ocupa a vaga uma moto anterior ao corte que esteja
    ///   ativa; senão, entre as posteriores, a ativa (antes da à venda) com o
    ///   registro mais recente. Moto só para consulta não ganha registro, então
    ///   a escolha não oscila — para trocar, coloca-se a outra à venda.
    /// * **À venda:** segue aceitando registro por `saleGraceDays` depois que a
    ///   moto da vaga chegou, se ela chegou depois.
    static func access(for bikes: [Bike], isPremium: Bool,
                       launch: Date = premiumLaunch, now: Date) -> Access {
        guard !isPremium else { return .unlimited }

        let garage = bikes.filter { $0.status != .sold }
        let activeCount = garage.filter { $0.status == .active }.count
        let forSaleCount = garage.filter { $0.status == .forSale }.count
        let canAdd = activeCount == 0 && forSaleCount <= 1

        let isLegacy: (Bike) -> Bool = { $0.createdAt < launch }
        let counted = garage.filter { !isLegacy($0) }

        let holder = garage
            .filter { isLegacy($0) && $0.status == .active }
            .max { $0.createdAt < $1.createdAt }
            ?? counted.max { rank($0) < rank($1) }

        let graceEnd = holder.flatMap {
            Calendar.current.date(byAdding: .day, value: saleGraceDays, to: $0.createdAt)
        }
        let readOnly = counted.filter { bike in
            if bike.id == holder?.id { return false }
            if bike.status == .forSale, let holder, let graceEnd,
               holder.createdAt > bike.createdAt, now < graceEnd {
                return false
            }
            return true
        }
        return Access(canAddMotorcycle: canAdd, readOnlyIDs: Set(readOnly.map(\.id)))
    }

    /// Ordem da disputa pela vaga: ativa antes de à venda, depois o registro
    /// mais recente, depois a mais nova.
    private static func rank(_ bike: Bike) -> (Int, Date, Date) {
        (bike.status == .active ? 1 : 0, bike.lastActivity, bike.createdAt)
    }
}
