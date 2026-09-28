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
    /// "Adicionar histórico": manutenção feita antes (form em modo histórico).
    @State private var showingHistory = false
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
        motorcycle.activeMaintenanceLogs
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
                    // Moto usada: o passado (óleo/pneus/revisões antes do app).
                    Button {
                        showingHistory = true
                    } label: {
                        Label("Adicionar histórico", systemImage: "clock.arrow.circlepath")
                    }
                }
            } else {
                List {
                    if !statuses.isEmpty {
                        Section {
                            ForEach(statuses) { status in
                                Button {
                                    scheduledAdd = status
                                } label: {
                                    ScheduledRow(status: status)
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
                        Section {
                            ForEach(group.logs) { log in
                                Button {
                                    editingLog = log
                                } label: {
                                    MaintenanceRow(log: log)
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
                        Text("Trocas de óleo, pneus e revisões feitas antes de usar o app.")
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
        .sheet(isPresented: $showingHistory) {
            MaintenanceFormView(motorcycle: motorcycle, isHistoryEntry: true)
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
        // Captura tipo/revisão ANTES de deletar (depois some da leitura).
        let analytics = logs.map { (type: $0.type, wasRevisao: $0.type == .revisao) }
        for log in logs {
            // Exclusão LÓGICA por ação do usuário (Soft Revision). Cascata:
            // excluir uma revisão soft-deleta seus itens (ligados por UUID, sem
            // cascade automático do SwiftData). `children` já filtra deletados.
            for child in log.children { child.softDelete() }
            log.softDelete()
        }
        try? modelContext.save()
        // Delete agora SINCRONIZA (antes só o notify rodava; o delete físico não
        // propagava). Push manda a linha com `deletedAt` → cruza pros devices.
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
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

        var title: String { AppFormat.monthTitle(id) }

        /// Só logs de topo: o custo de uma revisão fica no pai (itens = 0).
        var totalCost: Double { logs.reduce(0) { $0 + $1.cost } }
    }
}

/// Linha da seção "Programadas": status agendado de um tipo com barra de
/// progresso (km ou tempo, o mais próximo). Barra cinza em dia; cor só quando
/// há atenção (`MaintenanceStatus.indicatorColor`). O tile diz qual serviço.
private struct ScheduledRow: View {
    let status: MaintenanceStatus

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Em acessibilidade o prazo desce para baixo do nome (não espreme).
    private var headerLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    var body: some View {
        let color = status.indicatorColor
        HStack(spacing: 12) {
            IconTile(systemName: status.type.icon, tint: status.type.tint, size: 38)
            VStack(alignment: .leading, spacing: 5) {
                headerLayout {
                    Text(status.displayName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(status.remainingShort)
                        .font(.subheadline)
                        .foregroundStyle(status.isOverdue ? color : .secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
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

/// Linha do histórico — mesmo padrão de `FuelLogRow` (Apple Card/Fitness):
/// 2 linhas, coluna numérica à direita. O tile fica porque VARIA (cor + símbolo
/// = qual serviço). Valor primário = km do serviço (âncora do próximo
/// intervalo); dinheiro embaixo à direita, no mesmo lugar dos abastecimentos.
/// Notas ficam no form (tocar a linha) — lista é pra escanear.
private struct MaintenanceRow: View {
    let log: MaintenanceLog

    @Environment(\.dynamicTypeSize) private var typeSize

    /// 1 linha no tamanho normal; em acessibilidade quebra em vez de truncar.
    private var lineLimit: Int? { typeSize.isAccessibilitySize ? nil : 1 }

    /// Em acessibilidade a coluna da direita desce para baixo da esquerda.
    private var lineLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    /// Revisão = registro composto: única linha com 3ª linha (o que incluiu).
    private var includedItems: String? {
        log.type == .revisao && !log.includedItemsLabel.isEmpty ? log.includedItemsLabel : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: log.type.icon, tint: log.type.tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                lineLayout {
                    HStack(spacing: 6) {
                        Text(log.displayName)
                            .font(.headline)
                            .lineLimit(lineLimit)
                            // Sem isso a List mede a linha curta e trunca em AX.
                            .fixedSize(horizontal: false, vertical: true)
                        MetadataGlyphs(isHistorical: log.isHistorical)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    RowValue(value: AppFormat.odometer(log.mileage), unit: "km",
                             lineLimit: lineLimit)
                }

                lineLayout {
                    Text(AppFormat.weekdayDay(log.date))
                        .lineLimit(lineLimit)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if log.cost > 0 {
                        Text(AppFormat.currency(log.cost))
                            .lineLimit(lineLimit)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                if let includedItems {
                    Text("Inclui: \(includedItems)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(lineLimit)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toque para editar")
    }

    private var accessibilityText: String {
        var parts = [log.displayName, AppFormat.dateLong(log.date),
                     "Hodômetro \(AppFormat.km(log.mileage))"]
        if log.cost > 0 { parts.append(AppFormat.currency(log.cost)) }
        if let includedItems { parts.append("Inclui \(includedItems)") }
        if log.isHistorical { parts.append("Histórico") }
        return parts.joined(separator: ". ")
    }
}
