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

    /// Marca selecionada no Picker. "Outra…" revela o campo livre `make`.
    @State private var selectedMake: String = MotorcycleMake.catalog.first ?? ""
    /// Marca efetiva persistida. Espelha o Picker, exceto quando "Outra…" → texto livre.
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var country: String = "Brasil"
    @State private var currentOdometer: Double = 0
    @State private var saveError: String?
    @FocusState private var odometerFocused: Bool

    private var isEditing: Bool { motorcycle != nil }

    /// "Outra…" → usa o texto livre; senão a própria marca do Picker.
    private var effectiveMake: String {
        selectedMake == MotorcycleMake.other ? make : selectedMake
    }

    private var isOther: Bool { selectedMake == MotorcycleMake.other }

    private var canSave: Bool {
        !effectiveMake.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && !country.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let yearRange = Array(1950...Calendar.current.component(.year, from: Date()) + 1).reversed()

    var body: some View {
        NavigationStack {
            Form {
                Section("Moto") {
                    Picker("Marca", selection: $selectedMake) {
                        ForEach(MotorcycleMake.catalog, id: \.self) { mk in
                            Text(mk).tag(mk)
                        }
                    }
                    if isOther {
                        TextField("Nome da marca", text: $make)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("Modelo", text: $model)
                        .textInputAutocapitalization(.words)
                    Picker("Ano", selection: $year) {
                        ForEach(yearRange, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    LabeledContent("País") {
                        TextField("País", text: $country)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("Hodômetro") {
                    HStack {
                        TextField("Quilometragem atual", value: $currentOdometer, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($odometerFocused)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { odometerFocused = false }
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let m = motorcycle else { return }
        if MotorcycleMake.isKnown(m.make) {
            selectedMake = m.make
            make = m.make
        } else {
            // Marca fora do catálogo → começa em "Outra…" com o texto preenchido.
            selectedMake = MotorcycleMake.other
            make = m.make
        }
        model = m.model
        year = m.year
        country = m.country
        currentOdometer = m.currentOdometer
    }

    private func save() {
        let trimmedMake = effectiveMake.trimmingCharacters(in: .whitespaces)
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

#Preview("Nova") {
    MotorcycleFormView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
