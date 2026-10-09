//
//  MotorcycleProfileView.swift
//  Carburante
//
//  Perfil da moto — identidade (cadastro) + navegação. O consumo NÃO mora
//  aqui (é o lar do Resumo) — o perfil é só dados da moto + atalhos pros
//  históricos, sem duplicar o dashboard. Ação (abastecer) e navegação ficam
//  visualmente distintas: ação = Button com tile; navegação = NavigationLink.
//

import SwiftUI
import SwiftData

struct MotorcycleProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var motorcycle: Motorcycle
    @State private var showingEdit = false
    @State private var showingFuelLog = false
    @State private var showingHistory = false
    @State private var showingFuelHistory = false
    @State private var showDeleteConfirm = false
    @State private var showSoldConfirm = false

    var body: some View {
        List {
            Section("Moto") {
                LabeledContent("Marca", value: motorcycle.make)
                LabeledContent("Modelo", value: motorcycle.model)
                LabeledContent("Ano", value: String(motorcycle.year))
                LabeledContent("País", value: motorcycle.country)
                // Na garagem não tem rótulo (estado ok = silêncio).
                if let label = motorcycle.status.label {
                    LabeledContent("Situação", value: label)
                }
            }
            Section("Hodômetro") {
                LabeledContent("Atual") {
                    Text(AppFormat.km(motorcycle.currentOdometer)).monospacedDigit()
                }
            }

            // Vendida = só consulta: sem novo registro.
            if !motorcycle.isSold {
                actionsSection
            }

            Section {
                NavigationLink {
                    FuelLogListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "list.bullet",
                           title: "Abastecimentos", count: motorcycle.activeFuelLogs.count)
                }
                NavigationLink {
                    MaintenanceListView(motorcycle: motorcycle)
                } label: {
                    navRow(icon: "wrench.and.screwdriver.fill",
                           title: "Manutenções", count: motorcycle.activeMaintenanceLogs.count)
                }
            }

            statusSection

            // Antes a exclusão só existia via swipe em "Outras motos" na Garagem —
            // a moto ativa (ou a única) não tinha como ser excluída. Aqui é o
            // lugar canônico (padrão Ajustes: destrutivo no fim do detalhe).
            Section {
                Button("Excluir moto", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(motorcycle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        // Perfil desta moto usa o tema da própria moto.
        .tint(motorcycle.themeColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            MotorcycleFormView(motorcycle: motorcycle)
        }
        .sheet(isPresented: $showingFuelLog) {
            FuelLogFormView(motorcycle: motorcycle, entryPoint: "motorcycle_profile")
        }
        .sheet(isPresented: $showingHistory) {
            MaintenanceFormView(motorcycle: motorcycle, isHistoryEntry: true)
        }
        .sheet(isPresented: $showingFuelHistory) {
            FuelLogFormView(motorcycle: motorcycle, entryPoint: "history_profile", isHistoryEntry: true)
        }
        .confirmationDialog(
            motorcycle.deletionConfirmationText,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) { deleteMotorcycle() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                showingFuelLog = true
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemName: "fuelpump.fill")
                    Text("Novo abastecimento")
                }
            }
            // Moto usada tem passado: registrar o que foi feito antes do app
            // (óleo, pneus, revisões) — PLAN/registro-retroativo.md.
            HistoryMenu {
                showingHistory = true
            } onFuel: {
                showingFuelHistory = true
            } label: {
                HStack(spacing: 12) {
                    IconTile(systemName: "clock.arrow.circlepath")
                    Text("Adicionar histórico")
                }
            }
        }
    }

    /// Situação da moto: as ações mudam conforme o estado; na garagem não há
    /// rótulo, só as ações (PLAN/premium-mvp.md §1).
    @ViewBuilder
    private var statusSection: some View {
        Section {
            switch motorcycle.status {
            case .active:
                Button { changeStatus(to: .forSale) } label: {
                    Label("Colocar à venda", systemImage: "tag")
                }
                Button { showSoldConfirm = true } label: {
                    Label("Marcar como vendida", systemImage: "checkmark.seal")
                }
            case .forSale:
                Button { changeStatus(to: .active) } label: {
                    Label("Tirar da venda", systemImage: "tag.slash")
                }
                Button { showSoldConfirm = true } label: {
                    Label("Marcar como vendida", systemImage: "checkmark.seal")
                }
            case .sold:
                Button { changeStatus(to: .active) } label: {
                    Label("Voltar para a garagem", systemImage: "arrow.uturn.backward")
                }
            }
        } footer: {
            switch motorcycle.status {
            case .active:
                Text("À venda, a moto continua sua até vender. Vendida, sai da garagem e o histórico fica guardado para consulta.")
            case .forSale:
                Text("Vendida, a moto sai da garagem e o histórico fica guardado para consulta.")
            case .sold:
                Text("A moto volta para a garagem e para o Resumo.")
            }
        }
        // Preso à seção (não à tela): no iOS 26 o diálogo vira um balão que
        // aponta para quem o declarou. Vender não apaga nada → sem
        // `role: .destructive` (PLAN/DESIGN.md §7).
        .confirmationDialog(
            "Marcar como vendida?",
            isPresented: $showSoldConfirm,
            titleVisibility: .visible
        ) {
            Button("Marcar como vendida") { changeStatus(to: .sold) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A moto sai da garagem. O histórico continua aqui, só para consulta.")
        }
    }

    /// Muda a situação + sync + haptic + evento. Vendida deixa de avisar: os
    /// lembretes (globais) passam para outra moto da garagem ou são cancelados.
    private func changeStatus(to newStatus: MotorcycleStatus) {
        let wasSold = motorcycle.isSold
        motorcycle.setStatus(newStatus)
        do {
            try modelContext.save()
        } catch {
            return
        }
        Haptics.success()
        // Vender (ou devolver à garagem) muda a moto de seção na Garagem: o
        // link que abriu este perfil passa a apontar para outra moto e o SwiftUI
        // trocava a tela sozinho. Fecha e volta para a Garagem, como ao excluir.
        if newStatus == .sold || wasSold { dismiss() }
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        let garage = (try? modelContext.fetch(FetchDescriptor<Motorcycle>(predicate: Motorcycle.garagePredicate))) ?? []
        Analytics.motorcycleStatusChanged(to: newStatus, garageBikeCount: garage.count)

        guard newStatus == .sold else { return }
        if let next = garage.first {
            let lastFuelDate = next.activeFuelLogs.map(\.date).max()
            let statuses = next.maintenanceStatuses()
            Task {
                await NotificationService.shared.rescheduleAbsenceReminders(lastFuelDate: lastFuelDate)
                await NotificationService.shared.rescheduleMaintenance(statuses: statuses)
            }
        } else {
            Task {
                NotificationService.shared.cancelAbsenceReminders()
                await NotificationService.shared.cancelMaintenanceReminders()
            }
        }
    }

    /// Mesma semântica da exclusão na Garagem (exclusão lógica em cascata + sync + haptic + evento).
    /// Excluída a ativa, o Resumo/Garagem caem no fallback natural (`.first`).
    private func deleteMotorcycle() {
        let hadLogs = !motorcycle.activeFuelLogs.isEmpty
        let count = motorcycle.activeFuelLogs.count
        motorcycle.softDelete()
        try? modelContext.save()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        Haptics.warning()
        let remaining = (try? modelContext.fetchCount(FetchDescriptor<Motorcycle>(predicate: Motorcycle.activePredicate))) ?? 0
        Analytics.motorcycleDeleted(hadFuelLogs: hadLogs, fuelLogCount: count,
                                    remainingBikeCount: remaining)
        dismiss()
    }

    private func navRow(icon: String, title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon)
            Text(title)
            Spacer()
            Text(count.formatted())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
