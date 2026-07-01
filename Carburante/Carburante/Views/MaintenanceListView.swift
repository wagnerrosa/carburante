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
    /// Status a registrar ao tocar numa linha "Programadas" (abre o form
    /// prefixado com o tipo e, p/ pneu, a posição).
    @State private var scheduledAdd: MaintenanceStatus?
    /// Revisões com itens, aguardando confirmação de exclusão em cascata.
    @State private var pendingDelete: [MaintenanceLog] = []
    @State private var showDeleteConfirm = false

    /// Histórico mostra só os logs de topo: os filhos de uma Revisão Geral ficam
    /// dentro do pai (linha "Inclui: …"), não como linhas avulsas — uma revisão
    /// de 5 itens é 1 linha, não 6. Os filhos seguem existindo (sincronizam,
    /// reiniciam contadores); aqui é só apresentação.
    private var logs: [MaintenanceLog] {
        motorcycle.maintenanceLogs
            .filter { !$0.isPartOfRevisao }
            .sorted { $0.date > $1.date }
    }

    /// Status agendados por tipo (só os com ≥1 registro), por urgência.
    private var statuses: [MaintenanceStatus] {
        motorcycle.maintenanceStatuses()
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
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Registrar manutenção", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                List {
                    if !statuses.isEmpty {
                        Section {
                            ForEach(statuses) { status in
                                Button {
                                    scheduledAdd = status
                                } label: {
                                    ScheduledRow(status: status, themeColor: motorcycle.themeColor)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Programadas")
                        } footer: {
                            Text("Toque para registrar a próxima.")
                        }
                    }
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
        .sheet(item: $scheduledAdd) { status in
            MaintenanceFormView(
                motorcycle: motorcycle,
                initialType: status.type,
                initialTirePosition: status.position
            )
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Excluir tudo", role: .destructive) { performDelete(pendingDelete) }
            Button("Cancelar", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Os itens incluídos na revisão também serão excluídos.")
        }
    }

    private var confirmTitle: String {
        let children = pendingDelete.reduce(0) { $0 + $1.children.count }
        return children == 1
            ? "Excluir revisão e 1 item incluído?"
            : "Excluir revisão e \(children) itens incluídos?"
    }

    private func delete(_ offsets: IndexSet, in groupLogs: [MaintenanceLog]) {
        let targets = offsets.map { groupLogs[$0] }
        // Excluir uma revisão com itens é destrutivo em cascata → confirma.
        if targets.contains(where: { $0.type == .revisao && !$0.children.isEmpty }) {
            pendingDelete = targets
            showDeleteConfirm = true
        } else {
            performDelete(targets)
        }
    }

    private func performDelete(_ logs: [MaintenanceLog]) {
        // Captura tipo/revisão ANTES de deletar (depois o objeto some).
        let analytics = logs.map { (type: $0.type, wasRevisao: $0.type == .revisao) }
        for log in logs {
            // Cascata: excluir uma revisão remove seus itens (ligados por UUID,
            // sem cascade automático do SwiftData).
            for child in log.children { modelContext.delete(child) }
            modelContext.delete(log)
        }
        try? modelContext.save()
        for a in analytics {
            Analytics.maintenanceDeleted(type: a.type, wasRevisao: a.wasRevisao)
        }
        pendingDelete = []
        // Excluir manutenção muda os contadores → recalcula os lembretes.
        let statuses = motorcycle.maintenanceStatuses()
        Task { await NotificationService.shared.rescheduleMaintenance(statuses: statuses) }
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

/// Linha da seção "Programadas": status agendado de um tipo com barra de
/// progresso (km ou tempo, o mais próximo). Cor semântica só quando há atenção.
private struct ScheduledRow: View {
    let status: MaintenanceStatus
    let themeColor: Color

    private var color: Color {
        if status.isOverdue { return .red }
        return status.progress >= 0.8 ? .orange : themeColor
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: status.type.icon, tint: status.type.tint, size: 38)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(status.displayName).font(.headline)
                    Spacer()
                    Text(status.remainingShort)
                        .font(.subheadline)
                        .foregroundStyle(status.isOverdue ? color : .secondary)
                        .monospacedDigit()
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.quaternaryLabel))
                        Capsule().fill(color)
                            .frame(width: proxy.size.width * status.progress)
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)

                if !status.dueDescription.isEmpty {
                    Text(status.dueDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
        .accessibilityValue("\(status.remainingShort). \(status.dueDescription)")
    }
}

private struct MaintenanceRow: View {
    let log: MaintenanceLog

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: log.type.icon, tint: log.type.tint, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.displayName)
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

                // Revisão geral lista os itens incluídos. Filhos não aparecem no
                // histórico (filtrados em `logs`), então não há linha "Parte da
                // revisão geral" — só o pai, com o resumo dos itens.
                if log.type == .revisao, !log.includedItemsLabel.isEmpty {
                    Label("Inclui: \(log.includedItemsLabel)", systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
