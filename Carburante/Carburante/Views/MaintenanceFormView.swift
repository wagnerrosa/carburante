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

    @State private var date: Date = Date()
    @State private var type: MaintenanceType = .oleo
    @State private var mileage: Double?
    @State private var cost: Double?
    @State private var oilChangeIntervalKm: Double? = MaintenanceSchedule.defaultOilIntervalKm
    @State private var notes: String = ""
    @State private var saveError: String?
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

                if type == .oleo {
                    Section {
                        HStack {
                            TextField(
                                "Intervalo",
                                value: $oilChangeIntervalKm,
                                format: .number,
                                prompt: Text(AppFormat.odometer(MaintenanceSchedule.defaultOilIntervalKm))
                            )
                            .keyboardType(.numberPad)
                            .focused($fieldFocused)
                            Text("km").foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Próxima troca")
                    } footer: {
                        Text("Use a recomendação do fabricante da moto ou do óleo. O padrão é 3.000 km.")
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
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let log = maintenanceLog else { return }
        date = log.date
        type = log.type
        mileage = log.mileage
        cost = log.cost
        oilChangeIntervalKm = log.effectiveOilChangeIntervalKm
        notes = log.notes
    }

    private var canSave: Bool {
        guard (mileage ?? 0) > 0 else { return false }
        return type != .oleo || (oilChangeIntervalKm ?? 0) > 0
    }

    private func save() {
        let km = mileage ?? 0
        guard km > 0 else { return }
        let intervalKm = type == .oleo ? (oilChangeIntervalKm ?? 0) : nil
        guard type != .oleo || (intervalKm ?? 0) > 0 else { return }
        let c = cost ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let log = maintenanceLog {
            log.date = date
            log.type = type
            log.mileage = km
            log.cost = c
            log.notes = trimmedNotes
            log.oilChangeIntervalKm = intervalKm
        } else {
            let log = MaintenanceLog(
                date: date,
                mileage: km,
                cost: c,
                notes: trimmedNotes,
                type: type,
                oilChangeIntervalKm: intervalKm,
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
        dismiss()
    }
}
