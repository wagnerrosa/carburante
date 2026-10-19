//
//  ExpenseListView.swift
//  Carburante
//
//  Histórico das outras despesas de uma moto (IPVA, seguro, pedágio… — Custos
//  v2). Mesmo padrão de `MaintenanceListView` (PLAN/DESIGN.md §6): seção por
//  mês com o total no cabeçalho, tile colorido por categoria, tocar = editar,
//  swipe = exclusão lógica.
//

import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var motorcycle: Motorcycle
    @State private var editingExpense: Expense?
    @State private var showingAdd = false
    @Environment(\.garageAccess) private var garageAccess

    private var expenses: [Expense] {
        motorcycle.activeExpenses.sorted { $0.date > $1.date }
    }

    /// Despesas agrupadas por mês, em ordem decrescente.
    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: expenses) { expense -> Date in
            cal.date(from: cal.dateComponents([.year, .month], from: expense.date)) ?? expense.date
        }
        return dict.keys.sorted(by: >).map { key in
            MonthGroup(id: key, expenses: dict[key]?.sorted { $0.date > $1.date } ?? [])
        }
    }

    var body: some View {
        Group {
            if expenses.isEmpty {
                ContentUnavailableView {
                    Label("Nenhuma despesa", systemImage: "receipt")
                } description: {
                    Text("IPVA, seguro, pedágio, estacionamento… Registre para ver quanto a moto custa de verdade.")
                } actions: {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Adicionar despesa", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                List {
                    ForEach(monthGroups) { group in
                        Section {
                            ForEach(group.expenses) { expense in
                                Button {
                                    editingExpense = expense
                                } label: {
                                    ExpenseRow(expense: expense)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { delete($0, in: group.expenses) }
                            // Só para consulta: excluir também é editar.
                            .deleteDisabled(garageAccess.isReadOnly(motorcycle.id))
                        } header: {
                            MonthHeader(title: group.title, totalCost: group.total)
                        }
                    }
                }
            }
        }
        .navigationTitle("Outras despesas")
        .navigationBarTitleDisplayMode(.inline)
        // Botões/links usam o tema desta moto; os tiles de categoria mantêm a
        // cor semântica própria.
        .tint(motorcycle.themeColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Adicionar despesa", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            GarageGated(motorcycle) { ExpenseFormView(motorcycle: motorcycle) }
        }
        .sheet(item: $editingExpense) { expense in
            GarageGated(motorcycle) { ExpenseFormView(motorcycle: motorcycle, expense: expense) }
        }
    }

    private func delete(_ offsets: IndexSet, in groupExpenses: [Expense]) {
        let targets = offsets.map { groupExpenses[$0] }
        // Captura a categoria ANTES de deletar (depois some da leitura).
        let categories = targets.map(\.category)
        // Exclusão LÓGICA (Soft Revision): o push leva o `deletedAt` aos outros
        // devices; um delete físico voltaria no pull.
        for expense in targets { expense.softDelete() }
        try? modelContext.save()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        for category in categories { Analytics.expenseDeleted(category: category) }
    }

    /// Grupo de um mês para a `Section`.
    private struct MonthGroup: Identifiable {
        let id: Date
        let expenses: [Expense]

        var title: String { AppFormat.monthTitle(id) }
        var total: Double { expenses.reduce(0) { $0 + $1.amount } }
    }
}

/// Linha do histórico — padrão Wallet (transação): o quê à esquerda, o valor
/// em destaque à direita, a data embaixo. Aqui o número do domínio É o
/// dinheiro, então ele ocupa o lugar do valor primário (`RowValue` nas outras
/// listas). Observações ficam no form — exceto em "Outra", onde viram o título.
private struct ExpenseRow: View {
    let expense: Expense

    @Environment(\.dynamicTypeSize) private var typeSize

    /// 1 linha no tamanho normal; em acessibilidade quebra em vez de truncar.
    private var lineLimit: Int? { typeSize.isAccessibilitySize ? nil : 1 }

    /// Em acessibilidade a coluna da direita desce para baixo da esquerda.
    private var lineLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: expense.category.icon, tint: expense.category.tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                lineLayout {
                    Text(expense.displayTitle)
                        .font(.headline)
                        .lineLimit(lineLimit)
                        // Sem isso a List mede a linha curta e trunca em AX.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(AppFormat.currency(expense.amount))
                        .font(.title3.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .lineLimit(lineLimit)
                        .fixedSize(horizontal: lineLimit != nil, vertical: false)
                }

                Text(AppFormat.weekdayDay(expense.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toque para editar")
    }

    private var accessibilityText: String {
        [expense.displayTitle, AppFormat.dateLong(expense.date), AppFormat.currency(expense.amount)]
            .joined(separator: ". ")
    }
}
