//
//  MaintenanceListView.swift
//  Carburante
//
//  Histórico de manutenções de uma moto — ordem cronológica decrescente.
//

import SwiftUI
import SwiftData

struct MaintenanceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var motorcycle: Motorcycle
    @State private var editingLog: MaintenanceLog?
    @State private var showingAdd = false

    private var logs: [MaintenanceLog] {
        motorcycle.maintenanceLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Nenhuma manutenção",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Registre uma manutenção para acompanhar o histórico.")
                )
            } else {
                List {
                    ForEach(logs) { log in
                        Button {
                            editingLog = log
                        } label: {
                            MaintenanceRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Manutenções")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Adicionar manutenção", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            MaintenanceFormView(motorcycle: motorcycle)
        }
        .sheet(item: $editingLog) { log in
            MaintenanceFormView(motorcycle: motorcycle, maintenanceLog: log)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(logs[index])
        }
    }
}

private struct MaintenanceRow: View {
    let log: MaintenanceLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(log.type.rawValue, systemImage: log.type.icon)
                    .font(.headline)
                Spacer()
                Text("\(log.mileage, format: .number) km")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(log.date, format: .dateTime.day().month().year())
                if log.cost > 0 {
                    Text("•")
                    Text("R$ \(log.cost, format: .number.precision(.fractionLength(2)))")
                }
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
