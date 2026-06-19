//
//  MotorcycleListView.swift
//  Carburante
//
//  Lista de motos. Excluir uma moto cascateia (apaga abastecimentos +
//  manutenções), por isso pede confirmação explícita.
//

import SwiftUI
import SwiftData

struct MotorcycleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    @State private var showingAdd = false
    @State private var pendingDeletion: IndexSet?

    var body: some View {
        NavigationStack {
            Group {
                if motorcycles.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhuma moto", systemImage: "motorcycle")
                    } description: {
                        Text("Cadastre sua moto para começar.")
                    } actions: {
                        Button("Cadastrar moto") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(motorcycles) { moto in
                            NavigationLink {
                                MotorcycleProfileView(motorcycle: moto)
                            } label: {
                                HStack(spacing: 12) {
                                    IconTile(systemName: "motorcycle", tint: .blue, size: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(moto.displayName)
                                            .font(.headline)
                                        Text(AppFormat.km(moto.currentOdometer))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .onDelete { pendingDeletion = $0 }
                    }
                }
            }
            .navigationTitle("Motos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Adicionar moto", systemImage: "plus")
                    }
                }
                if !motorcycles.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MotorcycleFormView()
            }
            .confirmationDialog(
                deletionPrompt,
                isPresented: deletionDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Excluir", role: .destructive) { confirmDelete() }
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    /// Texto que explicita o cascade ("e seus N abastecimentos / M manutenções").
    private var deletionPrompt: String {
        guard let offsets = pendingDeletion else { return "" }
        let motos = offsets.map { motorcycles[$0] }
        let fuel = motos.reduce(0) { $0 + $1.fuelLogs.count }
        let maint = motos.reduce(0) { $0 + $1.maintenanceLogs.count }

        let name = motos.count == 1 ? motos[0].displayName : "\(motos.count) motos"
        var parts: [String] = []
        if fuel > 0 { parts.append("\(fuel) abastecimento\(fuel == 1 ? "" : "s")") }
        if maint > 0 { parts.append("\(maint) manutenç\(maint == 1 ? "ão" : "ões")") }

        if parts.isEmpty {
            return "Excluir \(name)?"
        }
        return "Excluir \(name) e \(parts.joined(separator: " e "))? Esta ação não pode ser desfeita."
    }

    private func confirmDelete() {
        guard let offsets = pendingDeletion else { return }
        for index in offsets {
            modelContext.delete(motorcycles[index])
        }
        try? modelContext.save()
        Haptics.warning()
        pendingDeletion = nil
    }
}

#Preview {
    MotorcycleListView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
