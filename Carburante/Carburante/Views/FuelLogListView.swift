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

    private var logs: [FuelLog] {
        motorcycle.fuelLogs.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Nenhum abastecimento",
                    systemImage: "fuelpump",
                    description: Text("Registre um abastecimento no perfil da moto.")
                )
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
        .sheet(item: $editingLog) { log in
            FuelLogFormView(motorcycle: motorcycle, fuelLog: log)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(logs[index])
        }
    }
}

private struct FuelLogRow: View {
    let log: FuelLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.date, format: .dateTime.day().month().year())
                    .font(.headline)
                Spacer()
                Text("\(log.odometer, format: .number) km")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(log.liters, format: .number) L")
                Text("•")
                Text("R$ \(log.totalCost, format: .number.precision(.fractionLength(2)))")
                Spacer()
                Text(log.fuelType.rawValue)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            if let place = log.placeLabel {
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
