//
//  MotorcycleProfileView.swift
//  Carburante
//
//  Perfil da moto — identidade (cadastro) + navegação. O consumo NÃO mora
//  aqui (é o lar do Resumo) — o perfil é só dados da moto + atalhos pros
//  históricos, sem duplicar o dashboard. Ação (abastecer) e navegação ficam
//  visualmente distintas: ação = Button com tile; navegação = NavigationLink.
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
}
