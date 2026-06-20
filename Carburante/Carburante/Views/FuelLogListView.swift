//
//  FuelLogListView.swift
//  Carburante
//
//  Histórico de abastecimentos de uma moto — ordem cronológica decrescente.
//  Tocar item edita; swipe exclui.
//

import SwiftUI
import SwiftData

struct FuelLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var motorcycle: Motorcycle
    @State private var editingLog: FuelLog?
    @State private var showingAdd = false

    private var logs: [FuelLog] {
        motorcycle.fuelLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum abastecimento", systemImage: "fuelpump")
                } description: {
                    Text("Registre o primeiro abastecimento desta moto.")
                } actions: {
                    Button("Registrar abastecimento") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(logs) { log in
                        Button {
                            editingLog = log
                        } label: {
                            FuelLogRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Abastecimentos")
        .navigationBarTitleDisplayMode(.inline)
        // Histórico desta moto usa o tema da própria moto.
        .tint(motorcycle.themeColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Adicionar abastecimento", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            FuelLogFormView(motorcycle: motorcycle)
        }
        .sheet(item: $editingLog) { log in
            FuelLogFormView(motorcycle: motorcycle, fuelLog: log)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(logs[index])
        }
        try? modelContext.save()
    }
}

private struct FuelLogRow: View {
    let log: FuelLog

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: "fuelpump.fill", size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(AppFormat.dateTime(log.date))
                        .font(.headline)
                    Spacer()
                    Text(AppFormat.km(log.odometer))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text(AppFormat.liters(log.liters))
                    Text("•")
                    Text(AppFormat.currency(log.totalCost))
                    Spacer()
                    Text(log.fuelType.rawValue)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .monospacedDigit()

                if let place = log.placeLabel {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
