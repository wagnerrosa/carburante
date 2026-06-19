//
//  MotorcycleProfileView.swift
//  Carburante
//
//  Perfil da moto — detalhe + editar. Ação (abastecer) e navegação (listas)
//  ficam visualmente distintas: ação = Button com tile colorido em Section
//  própria; navegação = NavigationLink com chevron nativo.
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
                    Text(AppFormat.km(motorcycle.currentOdometer)).monospacedDigit()
                }
            }

            consumptionSection

            Section {
                Button {
                    showingFuelLog = true
                } label: {
                    HStack(spacing: 12) {
                        IconTile(systemName: "fuelpump.fill", tint: .green)
                        Text("Novo abastecimento")
                    }
                }
            }

            Section {
                NavigationLink {
                    FuelLogListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "list.bullet", tint: .blue,
                           title: "Abastecimentos", count: motorcycle.fuelLogs.count)
                }
                NavigationLink {
                    MaintenanceListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "wrench.and.screwdriver.fill", tint: .orange,
                           title: "Manutenções", count: motorcycle.maintenanceLogs.count)
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

    private func navRow(icon: String, tint: Color, title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon, tint: tint)
            Text(title)
            Spacer()
            Text(count.formatted())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var consumptionSection: some View {
        let summary = motorcycle.consumptionSummary
        Section("Consumo") {
            if let avg = summary.averageKmPerLiter {
                LabeledContent("Consumo médio") {
                    Text(AppFormat.kmPerLiter(avg)).monospacedDigit()
                }
                LabeledContent("Distância medida") {
                    Text(AppFormat.km(summary.totalDistance)).monospacedDigit()
                }
                if let cpk = summary.costPerKm {
                    LabeledContent("Custo por km") {
                        Text(AppFormat.currency(cpk)).monospacedDigit()
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
