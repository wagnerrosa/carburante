//
//  ExpenseFormView.swift
//  Carburante
//
//  Cadastro e edição de outra despesa (IPVA, seguro, pedágio… — Custos v2).
//  Form nativo, mesmo padrão do `MaintenanceFormView`: data + categoria, valor,
//  observações. Registro grátis, sempre. "Repetir" (lista) abre como nova
//  despesa a partir de outra: mesma categoria, valor e observações, data de
//  hoje — lavagem do mês, parcela, estacionamento mensal em 1 toque + Salvar.
//  Paliativo da recorrência de verdade (PLAN/despesas-recorrentes.md).
//

import SwiftUI
import SwiftData

struct ExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle
    /// Nil = nova despesa. Não-nil = edição.
    var expense: Expense?
    /// "Repetir": nova despesa preenchida com esta (data = hoje). Ignorado na
    /// edição.
    var template: Expense?
    /// De onde abriu, p/ analytics: "costs" (tela Custos), "expense_list" ou
    /// "expense_repeat".
    var entryPoint: String = "expense_list"

    @State private var date: Date = Date()
    @State private var category: ExpenseCategory = .ipva
    @State private var amount: Double?
    @State private var notes: String = ""
    @State private var saveError: String?
    /// Confirmação de descarte (Cancelar/swipe-down com dados digitados).
    @State private var showDiscardConfirm = false
    @FocusState private var fieldFocused: Bool

    private var isEditing: Bool { expense != nil }

    /// Há investimento do usuário a proteger? Novo: valor ou observação
    /// digitados; edição e "Repetir": divergência do carregado (o preenchido
    /// pelo Repetir não é do usuário — Cancelar fecha sem perguntar).
    private var hasChanges: Bool {
        if let expense {
            return date != expense.date || category != expense.category
                || amount != expense.amount || notes != expense.notes
        }
        if let template {
            return !Calendar.current.isDateInToday(date) || category != template.category
                || amount != template.amount || notes != template.notes
        }
        return amount != nil || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool { (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Registro do que já foi pago: passado livre, futuro não. Uma
                    // despesa com data futura (outro fuso) continua editável.
                    DatePicker("Data", selection: $date,
                               in: ...max(Date(), expense?.date ?? .distantPast),
                               displayedComponents: [.date])
                    Picker("Categoria", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section {
                    UnitField(label: "Valor", unit: "R$",
                              leadingUnitFor: AppFormat.numberInput(amount, placeholder: "0,00")) {
                        TextField("Valor", value: $amount, format: .number, prompt: Text("0,00"))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                    }
                }

                Section("Observações") {
                    // Em "Outra" o texto é o que identifica a despesa na lista.
                    TextField(category == .other ? "O que foi (ex.: capa de chuva)" : "Opcional",
                              text: $notes, axis: .vertical)
                        .lineLimit(1...6)
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            // Criação = "Nova X"; edição = só o objeto (Cancelar/Salvar já dizem).
            .navigationTitle(isEditing ? "Despesa" : "Nova despesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if hasChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { fieldFocused = false }
                }
            }
            .onAppear(perform: load)
            // Protege dados digitados contra swipe-down acidental.
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog(isEditing ? "Descartar alterações?" : "Descartar esta despesa?",
                                isPresented: $showDiscardConfirm,
                                titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { dismiss() }
                Button("Continuar editando", role: .cancel) {}
            }
        }
    }

    private func load() {
        if let expense {
            date = expense.date
            category = expense.category
            amount = expense.amount
            notes = expense.notes
        } else if let template {
            category = template.category
            amount = template.amount
            notes = template.notes
        } else if let last = motorcycle.activeExpenses.max(by: { $0.createdAt < $1.createdAt }) {
            // Pré-preenche a categoria da última despesa (pedágio, estacionamento
            // costumam repetir) — o piloto confirma, não procura.
            category = last.category
        }
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasEditing = expense != nil
        // Conta antes do insert: 1ª despesa da moto?
        let isFirst = !wasEditing && motorcycle.activeExpenses.isEmpty

        if let expense {
            expense.date = date
            // Só regrava se mudou: categoria desconhecida (build mais novo)
            // aparece como "Outra" no form, e regravar trocaria a chave real.
            if expense.category != category { expense.category = category }
            expense.amount = value
            expense.notes = trimmedNotes
            // Soft Revision: registra a edição (revision++ / updatedAt p/ o sync).
            expense.markUpdated()
        } else {
            modelContext.insert(Expense(date: date, amount: value, category: category,
                                        notes: trimmedNotes, motorcycle: motorcycle))
        }
        do {
            try modelContext.save()
        } catch {
            saveError = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()

        if !wasEditing {
            Analytics.expenseCreated(
                category: category,
                isFirst: isFirst,
                isBackdated: !Calendar.current.isDateInToday(date),
                hasNotes: !trimmedNotes.isEmpty,
                entryPoint: entryPoint
            )
        }

        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        dismiss()
    }
}
