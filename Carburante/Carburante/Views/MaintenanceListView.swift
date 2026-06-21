//
//  MaintenanceListView.swift
//  Carburante
//
//  Histórico de manutenções de uma moto — agrupado por mês, mais recente no
//  topo. Tile colorido por tipo (padrão Ajustes/Wallet/Diário).
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

    /// Manutenções agrupadas por mês, em ordem decrescente.
    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: logs) { log -> Date in
            cal.date(from: cal.dateComponents([.year, .month], from: log.date)) ?? log.date
        }
        return dict.keys.sorted(by: >).map { key in
            MonthGroup(id: key, logs: dict[key]?.sorted { $0.date > $1.date } ?? [])
        }
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView {
                    Label("Nenhuma manutenção", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Registre uma manutenção para acompanhar o histórico.")
                } actions: {
                    Button("Registrar manutenção") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(monthGroups) { group in
                        Section(group.title) {
                            ForEach(group.logs) { log in
                                Button {
                                    editingLog = log
                                } label: {
                                    MaintenanceRow(log: log)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { delete($0, in: group.logs) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manutenções")
        .navigationBarTitleDisplayMode(.inline)
        // Botões/links usam o tema desta moto; ícones de tipo (IconTile)
        // mantêm sua cor semântica própria.
        .tint(motorcycle.themeColor)
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

    private func delete(_ offsets: IndexSet, in groupLogs: [MaintenanceLog]) {
        for index in offsets {
            modelContext.delete(groupLogs[index])
        }
        try? modelContext.save()
    }

    /// Grupo de um mês para a `Section`.
    private struct MonthGroup: Identifiable {
        let id: Date
        let logs: [MaintenanceLog]

        var title: String {
            id.formatted(Date.FormatStyle().month(.wide).year().locale(AppFormat.locale))
                .capitalized
        }
    }
}

private struct MaintenanceRow: View {
    let log: MaintenanceLog

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: log.type.icon, tint: log.type.tint, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.type.rawValue)
                        .font(.headline)
                    Spacer()
                    Text(AppFormat.km(log.mileage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text(AppFormat.date(log.date))
                    if log.cost > 0 {
                        Text("•")
                        Text(AppFormat.currency(log.cost))
                    }
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
