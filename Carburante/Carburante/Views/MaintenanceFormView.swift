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
    @State private var notes: String = ""

    private var isEditing: Bool { maintenanceLog != nil }

    private var mileagePrompt: String {
        motorcycle.currentOdometer > 0 ? "Atual: \(Int(motorcycle.currentOdometer))" : "Hodômetro"
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
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Custo", value: $cost, format: .number, prompt: Text("Custo"))
                            .keyboardType(.decimalPad)
                        Text("R$").foregroundStyle(.secondary)
                    }
                }
                Section("Observações") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
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
                        .disabled((mileage ?? 0) <= 0)
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
        notes = log.notes
    }

    private func save() {
        let km = mileage ?? 0
        guard km > 0 else { return }
        let c = cost ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let log = maintenanceLog {
            log.date = date
            log.type = type
            log.mileage = km
            log.cost = c
            log.notes = trimmedNotes
        } else {
            let log = MaintenanceLog(
                date: date,
                mileage: km,
                cost: c,
                notes: trimmedNotes,
                type: type,
                motorcycle: motorcycle
            )
            modelContext.insert(log)
        }
        dismiss()
    }
}
