//
//  Expense.swift
//  Carburante
//
//  Outras despesas da moto (Custos v2 — PLAN/premium-mvp.md §2): IPVA,
//  licenciamento, seguro, financiamento, pedágio, estacionamento… Tudo o que a
//  moto custa além da gasolina e da manutenção. Registro grátis, sempre; entra
//  na tela Custos (`CostCalculator`). Relação Motorcycle 1—N Expense. Espelha a
//  tabela `expenses` do Supabase.
//
//  Sem hodômetro de propósito: despesa não é leitura do painel e não mexe em
//  `currentOdometer`, medalhas nem lembretes.
//

import Foundation
import SwiftData

/// Categoria da despesa. `.rawValue` é **chave congelada** (SwiftData,
/// Supabase `category`, PostHog): nunca exibir, nunca renomear, nunca remover um
/// caso com dado — texto de tela = `label` (ver `FuelType`). Chaves ASCII em
/// inglês desde o início, prontas para o lançamento mundial.
enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case ipva
    case licensing
    case insurance
    case financing
    case toll
    case parking
    case accessories
    case fine
    case wash
    case other

    var id: String { rawValue }

    /// Nome exibido. Livre para mudar/traduzir.
    var label: String {
        switch self {
        case .ipva: return "IPVA"
        case .licensing: return "Licenciamento"
        case .insurance: return "Seguro"
        case .financing: return "Financiamento"
        case .toll: return "Pedágio"
        case .parking: return "Estacionamento"
        case .accessories: return "Acessórios"
        case .fine: return "Multa"
        case .wash: return "Lavagem"
        case .other: return "Outra"
        }
    }

    var icon: String {
        switch self {
        case .ipva: return "building.columns.fill"
        case .licensing: return "doc.text.fill"
        case .insurance: return "checkmark.shield.fill"
        case .financing: return "creditcard.fill"
        case .toll: return "road.lanes"
        case .parking: return "parkingsign.circle.fill"
        case .accessories: return "bag.fill"
        case .fine: return "exclamationmark.triangle.fill"
        case .wash: return "bubbles.and.sparkles.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

@Model
final class Expense {
    /// ID estável (gerado no app) usado como PK no Supabase.
    var id: UUID = UUID()
    var date: Date
    /// Valor pago (R$). Sempre > 0 — o form não salva sem valor.
    var amount: Double
    /// Chave de `ExpenseCategory`. Desconhecida (build mais novo) fica como veio,
    /// nunca é regravada com o fallback.
    var categoryRaw: String
    var notes: String

    // Soft Revision — mesma tripla de FuelLog/MaintenanceLog.
    /// Última alteração da linha — base do last-write-wins no sync.
    var updatedAt: Date = Date()
    /// Contador de edições (0 = nunca alterado após criar).
    var revision: Int = 0
    /// Exclusão lógica: nil = viva. Leituras usam `Motorcycle.activeExpenses`.
    var deletedAt: Date?

    var createdAt: Date

    /// Relação inversa: cada despesa pertence a uma moto.
    var motorcycle: Motorcycle?

    init(
        date: Date = Date(),
        amount: Double,
        category: ExpenseCategory,
        notes: String = "",
        motorcycle: Motorcycle? = nil,
        createdAt: Date = Date()
    ) {
        self.date = date
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.motorcycle = motorcycle
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension Expense {
    /// Categoria lida da chave. Desconhecida → `.other`, só para a tela.
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Rótulo da categoria. Chave desconhecida sai crua (dado intacto), nunca
    /// vira "Outra" — mesmo contrato do export e dos custos.
    var categoryLabel: String {
        ExpenseCategory(rawValue: categoryRaw)?.label ?? categoryRaw
    }

    /// Título da linha no histórico: a categoria, ou as observações quando a
    /// categoria é "Outra" (ali o texto É o que identifica a despesa).
    var displayTitle: String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if categoryRaw == ExpenseCategory.other.rawValue, !trimmed.isEmpty {
            return trimmed.components(separatedBy: .newlines).first ?? trimmed
        }
        return categoryLabel
    }

    /// Marca a linha como editada: incrementa `revision` e carimba `updatedAt`.
    func markUpdated(now: Date = Date()) {
        revision += 1
        updatedAt = now
    }

    /// Exclusão lógica (swipe e cascata da moto). Idempotente.
    func softDelete(now: Date = Date()) {
        guard deletedAt == nil else { return }
        deletedAt = now
        updatedAt = now
    }
}
