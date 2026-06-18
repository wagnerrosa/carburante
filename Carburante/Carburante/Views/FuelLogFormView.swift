//
//  FuelLogFormView.swift
//  Carburante
//
//  Novo abastecimento — entrada manual (sem OCR no MVP Fase 2).
//  OCR (Fase 6) vai pré-preencher estes mesmos campos.
//

import SwiftUI
import SwiftData

struct FuelLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle
    /// Nil = novo abastecimento. Não-nil = edição.
    var fuelLog: FuelLog?

    @State private var date: Date = Date()
    @State private var odometer: Double?
    @State private var liters: Double?
    @State private var totalCost: Double?
    @State private var fuelType: FuelType = .gasolinaComum
    @State private var isFullTank: Bool = true
    @State private var validationMessage: String?

    private var isEditing: Bool { fuelLog != nil }

    /// É o primeiro abastecimento da moto (ignorando o próprio log em edição)?
    private var isFirstFuelUp: Bool {
        motorcycle.fuelLogs.allSatisfy { $0.persistentModelID == fuelLog?.persistentModelID }
    }

    /// Maior hodômetro registrado p/ a moto, ignorando o próprio log em edição.
    private var lastOdometer: Double {
        let logsMax = motorcycle.fuelLogs
            .filter { $0.persistentModelID != fuelLog?.persistentModelID }
            .map(\.odometer).max() ?? 0
        return max(logsMax, motorcycle.currentOdometer)
    }

    private var pricePerLiter: Double? {
        guard let l = liters, l > 0, let c = totalCost else { return nil }
        return c / l
    }

    /// Placeholder do hodômetro: último valor conhecido, deixa claro que é leitura total.
    private var odometerPrompt: String {
        lastOdometer > 0 ? "Último: \(Int(lastOdometer))" : "Hodômetro atual"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        TextField("Hodômetro atual", value: $odometer, format: .number, prompt: Text(odometerPrompt))
                            .keyboardType(.decimalPad)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Litros", value: $liters, format: .number, prompt: Text("Litros"))
                            .keyboardType(.decimalPad)
                        Text("L").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Valor total", value: $totalCost, format: .number, prompt: Text("Valor total"))
                            .keyboardType(.decimalPad)
                        Text("R$").foregroundStyle(.secondary)
                    }
                    Picker("Combustível", selection: $fuelType) {
                        ForEach(FuelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Toggle("Tanque cheio", isOn: $isFullTank)
                } header: {
                    Text("Abastecimento")
                } footer: {
                    if isFirstFuelUp {
                        Text("Encha o tanque neste primeiro registro para começar a medir o consumo.")
                    } else {
                        Text("Desligue se você não encheu o tanque. Abastecimentos parciais são somados e o consumo é fechado no próximo tanque cheio.")
                    }
                }

                if let ppl = pricePerLiter {
                    Section {
                        LabeledContent("Preço por litro") {
                            Text("R$ \(ppl, format: .number.precision(.fractionLength(3)))")
                        }
                    }
                }

                if let msg = validationMessage {
                    Section {
                        Label(msg, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Abastecimento" : "Novo Abastecimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let log = fuelLog else { return }
        date = log.date
        odometer = log.odometer
        liters = log.liters
        totalCost = log.totalCost
        fuelType = log.fuelType
        isFullTank = log.isFullTank
    }

    private func save() {
        // Campo vazio (nil) → 0, reprovado pela validação (positivos obrigatórios).
        let odo = odometer ?? 0
        let lit = liters ?? 0
        let cost = totalCost ?? 0

        let errors = FuelLogValidator.validate(
            odometer: odo,
            liters: lit,
            totalCost: cost,
            lastOdometer: lastOdometer > 0 ? lastOdometer : nil
        )
        guard errors.isEmpty else {
            validationMessage = message(for: errors)
            return
        }

        if let log = fuelLog {
            log.date = date
            log.odometer = odo
            log.liters = lit
            log.totalCost = cost
            log.fuelType = fuelType
            log.isFullTank = isFullTank
        } else {
            let log = FuelLog(
                date: date,
                odometer: odo,
                liters: lit,
                totalCost: cost,
                fuelType: fuelType,
                isFullTank: isFullTank,
                motorcycle: motorcycle
            )
            modelContext.insert(log)
        }
        // Avança o hodômetro da moto se este for mais recente.
        if odo > motorcycle.currentOdometer {
            motorcycle.currentOdometer = odo
        }
        dismiss()
    }

    private func message(for errors: [FuelLogValidationError]) -> String {
        errors.compactMap { err in
            switch err {
            case .odometerNotPositive: return "Hodômetro deve ser maior que zero."
            case .odometerBelowLast(let last):
                return "Hodômetro não pode ser menor que o último (\(Int(last)) km)."
            case .litersNotPositive: return "Litros deve ser maior que zero."
            case .costNegative: return "Valor não pode ser negativo."
            }
        }.joined(separator: " ")
    }
}
