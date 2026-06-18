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
            Section {
                Button {
                    showingFuelLog = true
                } label: {
                    Label("Novo abastecimento", systemImage: "fuelpump")
                }
                LabeledContent("Abastecimentos", value: "\(motorcycle.fuelLogs.count)")
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
}
