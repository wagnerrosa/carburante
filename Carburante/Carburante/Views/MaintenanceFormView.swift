//
//  MaintenanceFormView.swift
//  Carburante
//
//  Cadastro e edição de manutenção. Form nativo.
//

import SwiftUI
import SwiftData

struct MaintenanceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle
    /// Nil = nova manutenção. Não-nil = edição.
    var maintenanceLog: MaintenanceLog?
    /// Tipo inicial p/ nova manutenção (ex.: tocar numa linha "Programadas").
    /// Ignorado em edição.
    var initialType: MaintenanceType?

    @State private var date: Date = Date()
    @State private var type: MaintenanceType = .oleo
    @State private var mileage: Double?
    @State private var cost: Double?
    @State private var intervalKm: Double? = MaintenanceType.oleo.defaultIntervalKm
    @State private var intervalMonths: Int? = MaintenanceType.oleo.defaultIntervalMonths
    @State private var notes: String = ""
    /// Itens marcados numa Revisão Geral (combo). Cada um vira um log-filho que
    /// reinicia o contador do seu tipo. Fase B — ver PLAN/manutencao-programada.md.
    @State private var revisaoItems: Set<MaintenanceType> = []
    @State private var saveError: String?
    /// Evita que o `onChange(of: type)` (disparado ao carregar) sobrescreva os
    /// valores carregados/iniciais com os defaults do tipo.
    @State private var didLoad = false
    @FocusState private var fieldFocused: Bool

    private var isEditing: Bool { maintenanceLog != nil }

    private var mileagePrompt: String {
        motorcycle.currentOdometer > 0 ? "Atual: \(AppFormat.odometer(motorcycle.currentOdometer))" : "Hodômetro"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data", selection: $date, displayedComponents: [.date])
                    Picker("Tipo", selection: $type) {
                        ForEach(MaintenanceType.allCases) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    HStack {
                        TextField("Hodômetro", value: $mileage, format: .number, prompt: Text(mileagePrompt))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Custo", value: $cost, format: .number, prompt: Text("Custo"))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("R$").foregroundStyle(.secondary)
                    }
                }

                // Revisão Geral não tem contador próprio (é ação que reinicia os
                // itens incluídos, não meta agendável) → sem seção de intervalo.
                if type != .revisao {
                    Section {
                        HStack {
                            Text("A cada")
                            TextField(
                                "Intervalo",
                                value: $intervalKm,
                                format: .number,
                                prompt: Text(type.defaultIntervalKm.map(AppFormat.odometer) ?? "—")
                            )
                            .keyboardType(.numberPad)
                            .focused($fieldFocused)
                            .multilineTextAlignment(.trailing)
                            Text("km").foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("A cada")
                            TextField(
                                "Intervalo",
                                value: $intervalMonths,
                                format: .number,
                                prompt: Text(type.defaultIntervalMonths.map { "\($0)" } ?? "—")
                            )
                            .keyboardType(.numberPad)
                            .focused($fieldFocused)
                            .multilineTextAlignment(.trailing)
                            Text("meses").foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Próxima manutenção")
                    } footer: {
                        Text("A cada quanto repetir esta manutenção — por km, por tempo, ou ambos (vence pelo que vier primeiro). Pré-preenchido com uma sugestão; ajuste conforme o manual da sua moto.")
                    }
                }

                if type == .revisao {
                    Section {
                        ForEach(MaintenanceType.revisaoComboTypes) { item in
                            Toggle(isOn: revisaoBinding(for: item)) {
                                Label(item.rawValue, systemImage: item.icon)
                            }
                        }
                    } header: {
                        Text("Itens executados")
                    } footer: {
                        // Revisão sem itens não reinicia contador nenhum nem
                        // aparece em Programadas (não é agendável) → o serviço se
                        // perderia. Exige ≥1 item (ver canSave).
                        Text(revisaoItems.isEmpty
                             ? "Marque ao menos um item executado."
                             : "Marque o que foi feito nesta revisão — cada item reinicia o próprio contador, na mesma data e km. O custo total fica na revisão.")
                        .foregroundStyle(revisaoItems.isEmpty ? .orange : .secondary)
                    }
                }

                Section("Observações") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                        .lineLimit(1...6)
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Manutenção" : "Nova Manutenção")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
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
            // Trocar o tipo repõe os intervalos com os defaults do novo tipo
            // (só após o carregamento inicial, p/ não apagar valores carregados).
            .onChange(of: type) { _, newType in
                guard didLoad else { return }
                intervalKm = newType.defaultIntervalKm
                intervalMonths = newType.defaultIntervalMonths
            }
        }
    }

    private func load() {
        defer { didLoad = true }
        if let log = maintenanceLog {
            date = log.date
            type = log.type
            mileage = log.mileage
            cost = log.cost
            intervalKm = log.effectiveIntervalKm
            intervalMonths = log.effectiveIntervalMonths
            notes = log.notes
            // Pré-marca os itens já incluídos nesta revisão (logs-filhos).
            revisaoItems = Set(log.children.map(\.type))
        } else if let initialType {
            type = initialType
            intervalKm = initialType.defaultIntervalKm
            intervalMonths = initialType.defaultIntervalMonths
        }
    }

    private func revisaoBinding(for item: MaintenanceType) -> Binding<Bool> {
        Binding(
            get: { revisaoItems.contains(item) },
            set: { isOn in
                if isOn { revisaoItems.insert(item) } else { revisaoItems.remove(item) }
            }
        )
    }

    private var canSave: Bool {
        guard (mileage ?? 0) > 0 else { return false }
        // Revisão Geral precisa de ≥1 item: sem item não reinicia contador nem
        // aparece em Programadas (não é agendável) → o serviço se perderia.
        if type == .revisao, revisaoItems.isEmpty { return false }
        return true
    }

    private func save() {
        let km = mileage ?? 0
        guard km > 0 else { return }
        let c = cost ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // Em branco → nil → cai no padrão do tipo (effectiveInterval*). Valores
        // > 0 personalizam este registro e os seguintes do mesmo tipo.
        let ik = (intervalKm ?? 0) > 0 ? intervalKm : nil
        let im = (intervalMonths ?? 0) > 0 ? intervalMonths : nil

        let parent: MaintenanceLog
        if let log = maintenanceLog {
            log.date = date
            log.type = type
            log.mileage = km
            log.cost = c
            log.notes = trimmedNotes
            log.intervalKm = ik
            log.intervalMonths = im
            parent = log
        } else {
            let log = MaintenanceLog(
                date: date,
                mileage: km,
                cost: c,
                notes: trimmedNotes,
                type: type,
                intervalKm: ik,
                intervalMonths: im,
                motorcycle: motorcycle
            )
            modelContext.insert(log)
            parent = log
        }
        // Combo Revisão Geral: sincroniza os logs-filhos com a seleção. Se o tipo
        // deixou de ser revisão (edição), remove os filhos órfãos.
        if type == .revisao {
            syncRevisaoChildren(parent: parent)
        } else {
            for child in parent.children { modelContext.delete(child) }
        }
        do {
            try modelContext.save()
        } catch {
            saveError = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        // Registrar/editar uma manutenção reinicia o intervalo do tipo →
        // recalcula os lembretes de todos os tipos.
        let statuses = motorcycle.maintenanceStatuses()
        Task { await NotificationService.shared.rescheduleMaintenance(statuses: statuses) }
        dismiss()
    }

    /// Cria/atualiza/remove os logs-filhos de uma Revisão Geral conforme os itens
    /// marcados. Cada filho herda a data e o km do pai (reinicia o contador do
    /// tipo), custo 0 (o custo da visita fica no pai → sem dupla contagem) e
    /// intervalos nil (cai no padrão do tipo).
    private func syncRevisaoChildren(parent: MaintenanceLog) {
        let existing = parent.children
        let plan = RevisaoCombo.plan(
            selected: revisaoItems,
            existing: Set(existing.map(\.type))
        )
        for item in plan.toCreate {
            let child = MaintenanceLog(
                date: parent.date, mileage: parent.mileage, cost: 0, notes: "",
                type: item, intervalKm: nil, intervalMonths: nil,
                partOfMaintenanceID: parent.id, motorcycle: motorcycle
            )
            modelContext.insert(child)
        }
        for item in plan.toKeep {
            if let child = existing.first(where: { $0.type == item }) {
                child.date = parent.date
                child.mileage = parent.mileage
            }
        }
        for item in plan.toDelete {
            if let child = existing.first(where: { $0.type == item }) {
                modelContext.delete(child)
            }
        }
    }
}
