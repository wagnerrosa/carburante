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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var motorcycle: Motorcycle
    @State private var showingEdit = false
    @State private var showingFuelLog = false
    @State private var showDeleteConfirm = false

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
                        IconTile(systemName: "fuelpump.fill")
                        Text("Novo abastecimento")
                    }
                }
            }

            Section {
                NavigationLink {
                    FuelLogListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "list.bullet",
                           title: "Abastecimentos", count: motorcycle.activeFuelLogs.count)
                }
                NavigationLink {
                    MaintenanceListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "wrench.and.screwdriver.fill",
                           title: "Manutenções", count: motorcycle.activeMaintenanceLogs.count)
                }
            }

            // Antes a exclusão só existia via swipe em "Outras motos" na Garagem —
            // a moto ativa (ou a única) não tinha como ser excluída. Aqui é o
            // lugar canônico (padrão Ajustes: destrutivo no fim do detalhe).
            Section {
                Button("Excluir moto", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(motorcycle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        // Perfil desta moto usa o tema da própria moto.
        .tint(motorcycle.themeColor)
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
        .confirmationDialog(
            motorcycle.deletionConfirmationText,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) { deleteMotorcycle() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    /// Mesma semântica da exclusão na Garagem (cascade físico + haptic + evento).
    /// Excluída a ativa, o Resumo/Garagem caem no fallback natural (`.first`).
    private func deleteMotorcycle() {
        let hadLogs = !motorcycle.activeFuelLogs.isEmpty
        let count = motorcycle.activeFuelLogs.count
        modelContext.delete(motorcycle)
        try? modelContext.save()
        Haptics.warning()
        let remaining = (try? modelContext.fetchCount(FetchDescriptor<Motorcycle>())) ?? 0
        Analytics.motorcycleDeleted(hadFuelLogs: hadLogs, fuelLogCount: count,
                                    remainingBikeCount: remaining)
        dismiss()
    }

    private func navRow(icon: String, title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon)
            Text(title)
            Spacer()
            Text(count.formatted())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
