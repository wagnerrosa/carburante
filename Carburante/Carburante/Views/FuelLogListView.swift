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
        motorcycle.activeFuelLogs.sorted { $0.date > $1.date }
    }

    /// Abastecimentos agrupados por mês, em ordem decrescente — mesmo padrão do
    /// histórico de manutenções (os dois históricos leem igual).
    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: logs) { log -> Date in
            cal.date(from: cal.dateComponents([.year, .month], from: log.date)) ?? log.date
        }
        return dict.keys.sorted(by: >).map { key in
            MonthGroup(id: key, logs: dict[key]?.sorted { $0.date > $1.date } ?? [])
        }
    }

    /// km/l por abastecimento que FECHA um segmento full-to-full, casado por
    /// odômetro. Logs sem medição (1º cheio, parcial) não entram → sem pílula.
    private var kmPerLiterByOdometer: [Double: Double] {
        Dictionary(
            ConsumptionCalculator.segments(from: motorcycle.activeFuelLogs.map(\.asFuelEntry))
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
                    ForEach(monthGroups) { group in
                        Section(group.title) {
                            ForEach(group.logs) { log in
                                Button {
                                    editingLog = log
                                } label: {
                                    FuelLogRow(log: log,
                                               kmPerLiter: kmpl[log.odometer],
                                               averageKmPerLiter: avg)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { delete($0, in: group.logs) }
                        }
                    }
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
            FuelLogFormView(motorcycle: motorcycle, entryPoint: "fuel_list")
        }
        .sheet(item: $editingLog) { log in
            FuelLogFormView(motorcycle: motorcycle, fuelLog: log)
        }
    }

    /// `offsets` indexa o grupo do mês, não a lista inteira — resolve para o log
    /// antes de excluir (o índice global não bate mais com o agrupamento).
    private func delete(_ offsets: IndexSet, in group: [FuelLog]) {
        let targets = offsets.map { group[$0] }
        // O mais recente da lista inteira é o índice 0 de `logs` (data desc).
        let deletedMostRecent = logs.first.map { first in
            targets.contains { $0.id == first.id }
        } ?? false
        // Exclusão LÓGICA (Soft Revision): carimba `deletedAt` em vez de remover.
        // A leitura some (logs usa `activeFuelLogs`) e o sync propaga o delete a
        // outros devices — antes um delete físico só sumia local, nunca cruzava.
        for log in targets {
            log.softDelete()
        }
        Analytics.fuelDeleted(wasMostRecent: deletedMostRecent)
        // Reconcilia o hodômetro: `activeFuelLogs` já exclui os soft-deletados,
        // então excluir o mais recente cai para o próximo maior (ou baseline).
        motorcycle.reconcileOdometer()
        try? modelContext.save()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        // Excluir muda o "último abastecimento" e o km → recalcula os lembretes.
        let lastFuelDate = motorcycle.activeFuelLogs.map(\.date).max()
        let statuses = motorcycle.maintenanceStatuses()
        Analytics.evaluateOilOverdue(statuses: statuses, bikeID: motorcycle.id)
        Task {
            await NotificationService.shared.rescheduleAbsenceReminders(lastFuelDate: lastFuelDate)
            await NotificationService.shared.rescheduleMaintenance(statuses: statuses)
        }
    }

    /// Grupo de um mês para a `Section`.
    private struct MonthGroup: Identifiable {
        let id: Date
        let logs: [FuelLog]

        var title: String {
            id.formatted(Date.FormatStyle().month(.wide).year().locale(AppFormat.locale))
                .capitalized
        }
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
                // O combustível fica sempre nesta linha: antes a pílula de km/l
                // ocupava o lugar dele e a informação sumia justo nos logs que
                // fecham um segmento.
                HStack {
                    Text(AppFormat.liters(log.liters))
                    Text("•")
                    Text(AppFormat.currency(log.totalCost))
                    Text("•")
                    Text(log.fuelType.rawValue)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let kmPerLiter {
                        VariationPill(kmPerLiter: kmPerLiter, average: averageKmPerLiter)
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
