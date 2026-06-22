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

    /// km/l por abastecimento que FECHA um segmento full-to-full, casado por
    /// odômetro. Logs sem medição (1º cheio, parcial) não entram → sem pílula.
    private var kmPerLiterByOdometer: [Double: Double] {
        Dictionary(
            ConsumptionCalculator.segments(from: motorcycle.fuelLogs.map(\.asFuelEntry))
                .map { ($0.endOdometer, $0.kmPerLiter) },
            uniquingKeysWith: { _, new in new }
        )
    }

    /// Média global de consumo — referência para a cor/seta da pílula.
    private var averageKmPerLiter: Double? {
        motorcycle.consumptionSummary.averageKmPerLiter
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
                let kmpl = kmPerLiterByOdometer
                let avg = averageKmPerLiter
                List {
                    ForEach(logs) { log in
                        Button {
                            editingLog = log
                        } label: {
                            FuelLogRow(log: log,
                                       kmPerLiter: kmpl[log.odometer],
                                       averageKmPerLiter: avg)
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
        // Persiste a exclusão primeiro para o array `fuelLogs` já excluir os
        // registros apagados, então reconcilia o hodômetro (excluir o mais
        // recente cai para o próximo maior, ou para o baseline — nunca zera).
        try? modelContext.save()
        motorcycle.reconcileOdometer()
        try? modelContext.save()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
    }
}

private struct FuelLogRow: View {
    let log: FuelLog
    /// km/l deste abastecimento (nil se não fecha um segmento medível).
    var kmPerLiter: Double?
    /// Média global — referência para cor/seta da pílula.
    var averageKmPerLiter: Double?

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
                    if let kmPerLiter {
                        VariationPill(kmPerLiter: kmPerLiter, average: averageKmPerLiter)
                    } else {
                        Text(log.fuelType.rawValue)
                            .foregroundStyle(.secondary)
                    }
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

/// Pílula de variação de consumo (estilo app Bolsa): km/l do abastecimento +
/// seta ↑/↓ comparando à média. Verde ≥ média, vermelho < média. Usa seta
/// ALÉM da cor (acessível a daltônicos). Cor semântica — não segue o tema.
private struct VariationPill: View {
    let kmPerLiter: Double
    var average: Double?

    var body: some View {
        // Sem média (1 só segmento) → neutro, sem julgar acima/abaixo.
        let above = average.map { kmPerLiter >= $0 }
        let color: Color = above == nil ? .secondary : (above! ? .green : .red)
        let symbol = above == nil ? nil : (above! ? "arrow.up" : "arrow.down")

        HStack(spacing: 2) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.bold))
            }
            Text(AppFormat.kmPerLiter(kmPerLiter))
        }
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
    }
}
