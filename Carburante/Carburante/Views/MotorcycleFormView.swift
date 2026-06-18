//
//  MotorcycleFormView.swift
//  Carburante
//
//  Cadastro e edição de moto. Form nativo (HIG). Sem libs externas.
//

import SwiftUI
import SwiftData

struct MotorcycleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Nil = cadastro novo. Não-nil = edição.
    var motorcycle: Motorcycle?

    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var country: String = "Brasil"
    @State private var currentOdometer: Double = 0

    private var isEditing: Bool { motorcycle != nil }

    private var canSave: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let yearRange = Array(1950...Calendar.current.component(.year, from: Date()) + 1).reversed()

    var body: some View {
        NavigationStack {
            Form {
                Section("Moto") {
                    TextField("Marca", text: $make)
                        .textInputAutocapitalization(.words)
                    TextField("Modelo", text: $model)
                        .textInputAutocapitalization(.words)
                    Picker("Ano", selection: $year) {
                        ForEach(yearRange, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    TextField("País", text: $country)
                        .textInputAutocapitalization(.words)
                }

                Section("Hodômetro") {
                    HStack {
                        TextField("Quilometragem atual", value: $currentOdometer, format: .number)
                            .keyboardType(.decimalPad)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Moto" : "Nova Moto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let m = motorcycle else { return }
        make = m.make
        model = m.model
        year = m.year
        country = m.country
        currentOdometer = m.currentOdometer
    }

    private func save() {
        let trimmedMake = make.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        let trimmedCountry = country.trimmingCharacters(in: .whitespaces)

        if let m = motorcycle {
            m.make = trimmedMake
            m.model = trimmedModel
            m.year = year
            m.country = trimmedCountry
            m.currentOdometer = currentOdometer
        } else {
            let new = Motorcycle(
                make: trimmedMake,
                model: trimmedModel,
                year: year,
                country: trimmedCountry,
                currentOdometer: currentOdometer
            )
            modelContext.insert(new)
        }
        dismiss()
    }
}

#Preview("Nova") {
    MotorcycleFormView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
