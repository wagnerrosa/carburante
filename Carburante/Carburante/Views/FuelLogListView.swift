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
    /// "Adicionar histórico": abastecimento antigo (fluxo com data primeiro).
    @State private var showingHistory = false

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
            ConsumptionCalculator.segments(from: motorcycle.consumptionEntries)
                .map { ($0.endOdometer, $0.kmPerLiter) },
            uniquingKeysWith: { _, new in new }
        )
    }

    /// Média global de consumo — referência para a seta de tendência.
    private var averageKmPerLiter: Double? {
        motorcycle.consumptionSummary.averageKmPerLiter
    }

    /// Combustível mais usado nesta moto. A linha só nomeia o combustível
    /// quando foge dele — repetir "Gasolina comum" em toda linha era ruído.
    /// Empate → o do abastecimento mais recente (estável entre renders).
    private var usualFuelType: FuelType? {
        Dictionary(grouping: logs, by: \.fuelType)
            .max { a, b in
                (a.value.count, a.value.map(\.date).max() ?? .distantPast)
                    < (b.value.count, b.value.map(\.date).max() ?? .distantPast)
            }?
            .key
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
                    Button {
                        showingHistory = true
                    } label: {
                        Label("Adicionar histórico", systemImage: "clock.arrow.circlepath")
                    }
                }
            } else {
                let kmpl = kmPerLiterByOdometer
                let avg = averageKmPerLiter
                let usualFuel = usualFuelType
                List {
                    ForEach(monthGroups) { group in
                        Section {
                            ForEach(group.logs) { log in
                                Button {
                                    editingLog = log
                                } label: {
                                    FuelLogRow(log: log,
                                               kmPerLiter: kmpl[log.odometer],
                                               averageKmPerLiter: avg,
                                               showsFuelType: log.fuelType != usualFuel)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { delete($0, in: group.logs) }
                        } header: {
                            MonthHeader(title: group.title, totalCost: group.totalCost)
                        }
                    }
                    // Secundário e no fim: o `+` segue sendo o caminho do dia a dia.
                    Section {
                        Button {
                            showingHistory = true
                        } label: {
                            Label("Adicionar histórico", systemImage: "clock.arrow.circlepath")
                        }
                    } footer: {
                        Text("Abastecimentos antigos ficam no histórico da moto, fora do consumo e das conquistas.")
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
        .sheet(isPresented: $showingHistory) {
            FuelLogFormView(motorcycle: motorcycle, entryPoint: "history_fuel_list", isHistoryEntry: true)
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

        var title: String { AppFormat.monthTitle(id) }

        var totalCost: Double { logs.reduce(0) { $0 + $1.totalCost } }
    }
}

/// Linha do histórico — 2 linhas, coluna numérica à direita (padrão Apple
/// Card/Fitness). Consumo é o valor primário (core do app); o resto é contexto.
/// Hora, local e foto ficam no form (tocar a linha) — lista é pra escanear.
private struct FuelLogRow: View {
    let log: FuelLog
    /// km/l deste abastecimento (nil se não fecha um segmento medível).
    var kmPerLiter: Double?
    /// Média global — referência para a seta de tendência.
    var averageKmPerLiter: Double?
    /// Combustível foge do usual da moto → nomeia na linha 2.
    var showsFuelType: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    /// 1 linha no tamanho normal (coluna limpa); em acessibilidade o texto
    /// quebra em vez de truncar — ler vale mais que alinhar.
    private var lineLimit: Int? { typeSize.isAccessibilitySize ? nil : 1 }

    private var trend: ConsumptionTrend? {
        kmPerLiter.flatMap { ConsumptionTrend.of(kmPerLiter: $0, average: averageKmPerLiter) }
    }

    /// Tamanhos de acessibilidade: a coluna da direita desce para baixo da
    /// esquerda em vez de espremer/quebrar os números.
    private var lineLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    private var details: String {
        var parts = [AppFormat.liters(log.liters), AppFormat.km(log.odometer)]
        if showsFuelType { parts.append(log.fuelType.shortLabel) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            lineLayout {
                HStack(spacing: 6) {
                    Text(AppFormat.weekdayDay(log.date))
                        .font(.headline)
                        .lineLimit(lineLimit)
                    // Sinais discretos: registrado depois do fato / tem foto.
                    MetadataGlyphs(isHistorical: log.isHistorical,
                                   hasPhoto: log.odometerPhotoURL != nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                consumption
            }

            lineLayout {
                Text(details)
                    .lineLimit(lineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(AppFormat.currency(log.totalCost))
                    .lineLimit(lineLimit)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toque para editar")
    }

    /// km/l grande + unidade menor (padrão Fitness). Sem medição: "Parcial"
    /// (tanque não cheio) ou "—" (1º cheio / antes da 1ª leitura).
    @ViewBuilder
    private var consumption: some View {
        if let kmPerLiter {
            RowValue(value: AppFormat.kmPerLiterValue(kmPerLiter), unit: "km/l",
                     leadingSymbol: trend?.symbolName, lineLimit: lineLimit)
        } else {
            Text(log.isFullTank ? "—" : "Parcial")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(lineLimit)
        }
    }

    private var accessibilityText: String {
        var parts = [AppFormat.dateLong(log.date)]
        if let kmPerLiter {
            var c = "\(AppFormat.kmPerLiterValue(kmPerLiter)) quilômetros por litro"
            if let trend { c += ", \(trend.accessibilityDescription)" }
            parts.append(c)
        } else if !log.isFullTank {
            parts.append("Tanque parcial")
        }
        parts.append(AppFormat.currency(log.totalCost))
        parts.append("\(AppFormat.liters(log.liters)), hodômetro \(AppFormat.km(log.odometer))")
        if showsFuelType { parts.append(log.fuelType.rawValue) }
        if log.isHistorical { parts.append("Histórico") }
        if log.odometerPhotoURL != nil { parts.append("Com foto do hodômetro") }
        return parts.joined(separator: ". ")
    }
}

private extension FuelType {
    /// Nome curto p/ a linha do histórico (cabe ao lado de L e km).
    var shortLabel: String {
        switch self {
        case .gasolinaComum: "Gasolina"
        case .gasolinaAditivada: "Aditivada"
        case .etanol: "Etanol"
        case .diesel: "Diesel"
        case .gnv: "GNV"
        }
    }
}
