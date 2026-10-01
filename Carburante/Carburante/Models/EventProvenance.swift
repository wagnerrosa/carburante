//
//  EventProvenance.swift
//  Carburante
//
//  "Histórico" vs "na hora" — o primeiro degrau da escada de evidência
//  (PLAN/metadados-auditoria.md §"Nível de evidência do evento"). Um evento
//  registrado dias depois de acontecer vale menos que um registrado no momento:
//  não conta para medalhas/conquistas/recordes — mas o abastecimento ENTRA no
//  consumo: proveniência decide conquista, continuidade (lacuna) decide consumo
//  (PLAN/registro-retroativo.md, decisão 1). Regra DERIVADA de `date` (quando aconteceu) e
//  `createdAt` (quando entrou no app) — nada persistido, nada que o usuário
//  marque. Lógica pura, testável.
//

import Foundation

enum EventProvenance {
    /// Dias de calendário de tolerância: registrar o abastecimento do fim de
    /// semana na segunda ainda é "na hora".
    static let historyThresholdDays = 7

    /// A regra vale DAQUI PRA FRENTE (decisão do usuário, 2026-09-28): registro
    /// criado antes dela nunca é histórico. Além de decisão de produto, é
    /// necessidade técnica: até a regra existir, `createdAt` não sincronizava —
    /// o do servidor é a hora do 1º push bem-sucedido (lotes inteiros com o
    /// mesmo carimbo) e o de um device que puxou os dados é a hora do pull.
    /// Nenhum dos dois diz quando o registro foi feito. 28/09/2026 00:00 BRT
    /// (todo `created_at` no servidor naquele momento era anterior).
    static let ruleStart = Date(timeIntervalSince1970: 1_790_564_400)

    /// Histórico quando o evento entrou no app MAIS de `historyThresholdDays`
    /// dias de calendário depois de acontecer. Compara dias (não segundos): o
    /// seletor de data da manutenção guarda o horário de agora, e o tempo gasto
    /// no form não pode mudar a classificação.
    static func isHistorical(date: Date, createdAt: Date, calendar: Calendar = .current) -> Bool {
        guard createdAt >= ruleStart else { return false }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: createdAt)
        ).day ?? 0
        return days > historyThresholdDays
    }
}

extension FuelLog {
    /// Registrado depois do fato (ver `EventProvenance`).
    var isHistorical: Bool { EventProvenance.isHistorical(date: date, createdAt: createdAt) }
}

extension MaintenanceLog {
    /// Registrado depois do fato (ver `EventProvenance`).
    var isHistorical: Bool { EventProvenance.isHistorical(date: date, createdAt: createdAt) }
}
