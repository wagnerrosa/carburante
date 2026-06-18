//
//  MotorcycleProfileView.swift
//  Carburante
//
//  Perfil da moto — detalhe + botão editar.
//

import SwiftUI
import SwiftData

struct MotorcycleProfileView: View {
    @Bindable var motorcycle: Motorcycle
    @State private var showingEdit = false
    @State private var showingFuelLog = false

    var body: some View {
        List {
            Section("Moto") {
                LabeledContent("Marca", value: motorcycle.make)
                LabeledContent("Modelo", value: motorcycle.model)
                LabeledContent("Ano", value: String(motorcycle.year))
                LabeledContent("País", value: motorcycle.country)
            }
            Section("Hodômetro") {
                LabeledContent("Atual") {
                    Text("\(motorcycle.currentOdometer, format: .number) km")
                }
            }
            consumptionSection
            Section {
                Button {
                    showingFuelLog = true
                } label: {
                    Label("Novo abastecimento", systemImage: "fuelpump")
                }
                NavigationLink {
                    FuelLogListView(motorcycle: motorcycle)
                } label: {
                    HStack {
                        Text("Abastecimentos")
                        Spacer()
                        Text("\(motorcycle.fuelLogs.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                NavigationLink {
                    MaintenanceListView(motorcycle: motorcycle)
                } label: {
                    HStack {
                        Label("Manutenções", systemImage: "wrench.and.screwdriver")
                        Spacer()
                        Text("\(motorcycle.maintenanceLogs.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(motorcycle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            MotorcycleFormView(motorcycle: motorcycle)
        }
        .sheet(isPresented: $showingFuelLog) {
            FuelLogFormView(motorcycle: motorcycle)
        }
    }

    @ViewBuilder
    private var consumptionSection: some View {
        let summary = motorcycle.consumptionSummary
        Section("Consumo") {
            if let avg = summary.averageKmPerLiter {
                LabeledContent("Consumo médio") {
                    Text("\(avg, format: .number.precision(.fractionLength(1))) km/l")
                }
                LabeledContent("Distância medida") {
                    Text("\(summary.totalDistance, format: .number) km")
                }
                if let cpk = summary.costPerKm {
                    LabeledContent("Custo por km") {
                        Text("R$ \(cpk, format: .number.precision(.fractionLength(2)))")
                    }
                }
            } else {
                Text("Registre dois abastecimentos com tanque cheio para medir o consumo.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }
}
