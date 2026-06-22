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
        } else if let initialType {
            type = initialType
            intervalKm = initialType.defaultIntervalKm
            intervalMonths = initialType.defaultIntervalMonths
        }
    }

    private var canSave: Bool {
        (mileage ?? 0) > 0
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

        if let log = maintenanceLog {
            log.date = date
            log.type = type
            log.mileage = km
            log.cost = c
            log.notes = trimmedNotes
            log.intervalKm = ik
            log.intervalMonths = im
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
}
