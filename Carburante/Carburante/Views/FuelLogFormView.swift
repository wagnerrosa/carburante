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

    @State private var date: Date = Date()
    @State private var odometer: Double = 0
    @State private var liters: Double = 0
    @State private var totalCost: Double = 0
    @State private var fuelType: FuelType = .gasolinaComum
    @State private var validationMessage: String?

    /// Maior hodômetro já registrado p/ a moto (inclui o atual da moto).
    private var lastOdometer: Double {
        let logsMax = motorcycle.fuelLogs.map(\.odometer).max() ?? 0
        return max(logsMax, motorcycle.currentOdometer)
    }

    private var pricePerLiter: Double? {
        guard liters > 0 else { return nil }
        return totalCost / liters
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Abastecimento") {
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        TextField("Hodômetro", value: $odometer, format: .number)
                            .keyboardType(.decimalPad)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Litros", value: $liters, format: .number)
                            .keyboardType(.decimalPad)
                        Text("L").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Valor total", value: $totalCost, format: .number)
                            .keyboardType(.decimalPad)
                        Text("R$").foregroundStyle(.secondary)
                    }
                    Picker("Combustível", selection: $fuelType) {
                        ForEach(FuelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
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
            .navigationTitle("Novo Abastecimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
        }
    }

    private func save() {
        let errors = FuelLogValidator.validate(
            odometer: odometer,
            liters: liters,
            totalCost: totalCost,
            lastOdometer: lastOdometer > 0 ? lastOdometer : nil
        )
        guard errors.isEmpty else {
            validationMessage = message(for: errors)
            return
        }

        let log = FuelLog(
            date: date,
            odometer: odometer,
            liters: liters,
            totalCost: totalCost,
            fuelType: fuelType,
            motorcycle: motorcycle
        )
        modelContext.insert(log)
        // Avança o hodômetro da moto se este for mais recente.
        if odometer > motorcycle.currentOdometer {
            motorcycle.currentOdometer = odometer
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
