//
//  GarageView.swift
//  Carburante
//
//  Tab Garagem — o "perfil" da moto ativa, modelo mental Garmin Connect:
//  Resumo responde "como tá minha moto hoje?" (operacional, agora); Garagem
//  responde "o que já construí?" (orgulho, vitalício). Por isso a Garagem
//  NUNCA mostra média do mês / próxima troca — isso é Resumo.
//
//  Conteúdo: herói (moto ativa, tema da marca) + Recordes (PRs) + Totais
//  vitalícios + Medalhas (placeholder; design completo em PLAN/badges.md).
//  A ⚙️ no topo leva a Ajustes (a tab Ajustes morreu daqui). Trocar a moto
//  ativa aqui materializa a chave `activeMotorcycleID` (tema global reage).
//

import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    /// Mesma chave do Resumo/RootTabView — fonte única da moto ativa. Aqui é o
    /// único ponto que a SETA explicitamente (antes só caía no fallback `.first`).
    @AppStorage("activeMotorcycleID") private var activeMotorcycleID: String = ""

    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var pendingDeletion: Motorcycle?
    /// Medalha tocada → abre o sheet explicativo (estilo Apple Fitness / HIG).
    @State private var selectedBadge: BadgePresentation?
    /// Datas de conquista carimbadas (id→data), p/ o sheet mostrar "ganhou em …".
    @State private var earnedDates: [String: Date] = [:]

    /// Moto ativa = a da chave salva, ou a mais recente como fallback.
    private var activeMotorcycle: Motorcycle? {
        motorcycles.first { $0.id.uuidString == activeMotorcycleID } ?? motorcycles.first
    }

    /// As demais motos (para a seção "Outras motos" / troca de ativa).
    private var otherMotorcycles: [Motorcycle] {
        guard let active = activeMotorcycle else { return [] }
        return motorcycles.filter { $0.id != active.id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let moto = activeMotorcycle {
                    garageList(for: moto)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Garagem")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Adicionar moto", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MotorcycleFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedBadge) { presentation in
                BadgeDetailSheet(presentation: presentation)
            }
            .task { reconcileBadges() }
            .onChange(of: motorcycles) { reconcileBadges() }
            .confirmationDialog(
                deletionPrompt,
                isPresented: deletionDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Excluir", role: .destructive) { confirmDelete() }
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    // MARK: - Conteúdo principal

    @ViewBuilder
    private func garageList(for moto: Motorcycle) -> some View {
        List {
            heroSection(moto)
                // Tema da marca tinge o bloco da moto (mesma técnica das telas por-moto).
                .tint(moto.themeColor)

            if !otherMotorcycles.isEmpty {
                otherBikesSection
            }

            recordsSection(moto)
            totalsSection(moto)
            badgesSection
        }
    }

    // MARK: Herói

    @ViewBuilder
    private func heroSection(_ moto: Motorcycle) -> some View {
        Section {
            NavigationLink {
                MotorcycleProfileView(motorcycle: moto)
            } label: {
                HStack(spacing: 14) {
                    if let logo = moto.logoAsset {
                        BrandLogoTile(assetName: logo, size: 60)
                    } else {
                        IconTile(systemName: "motorcycle", tint: moto.themeColor, size: 60)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(moto.make) \(moto.model)")
                            .font(.title3.weight(.semibold))
                        Text(String(moto.year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(AppFormat.km(moto.currentOdometer))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Trocar moto ativa

    private var otherBikesSection: some View {
        Section("Outras motos") {
            ForEach(otherMotorcycles) { moto in
                Button {
                    // Materializa a troca: tema global do app (RootTabView) reage.
                    activeMotorcycleID = moto.id.uuidString
                    Haptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        if let logo = moto.logoAsset {
                            BrandLogoTile(assetName: logo, size: 32)
                        } else {
                            IconTile(systemName: "motorcycle", tint: moto.themeColor, size: 32)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(moto.make) \(moto.model)")
                                .foregroundStyle(.primary)
                            Text(AppFormat.km(moto.currentOdometer))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Excluir", role: .destructive) { pendingDeletion = moto }
                }
            }
        }
    }

    // MARK: Recordes (PRs)

    @ViewBuilder
    private func recordsSection(_ moto: Motorcycle) -> some View {
        let r = moto.records
        Section("Recordes") {
            if r.bestKmPerLiter == nil && r.longestSegment == nil && r.cheapestPricePerLiter == nil {
                Text("Registre mais abastecimentos para desbloquear recordes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let best = r.bestKmPerLiter {
                    StatRow(label: "Melhor consumo", value: AppFormat.kmPerLiter(best),
                            systemImage: "trophy.fill", iconColor: .yellow)
                }
                if let longest = r.longestSegment {
                    StatRow(label: "Maior trecho", value: AppFormat.km(longest),
                            systemImage: "road.lanes", iconColor: .blue)
                }
                if let cheap = r.cheapestPricePerLiter {
                    StatRow(label: "Litro mais barato", value: AppFormat.currencyPrecise(cheap),
                            systemImage: "drop.fill", iconColor: .green)
                }
            }
        }
    }

    // MARK: Totais vitalícios

    @ViewBuilder
    private func totalsSection(_ moto: Motorcycle) -> some View {
        let summary = moto.consumptionSummary
        Section("Totais") {
            StatRow(label: "Abastecimentos", value: String(moto.fuelLogCount))
            StatRow(label: "Distância", value: AppFormat.km(summary.totalDistance))
            StatRow(label: "Litros", value: AppFormat.liters(moto.totalLitersEver))
            StatRow(label: "Gasto", value: AppFormat.currency(moto.totalCostEver))
            if let avg = summary.averageKmPerLiter {
                StatRow(label: "Consumo médio", value: AppFormat.kmPerLiter(avg))
            }
            if let costPerKm = summary.costPerKm {
                StatRow(label: "Custo médio", value: "\(AppFormat.currencyPrecise(costPerKm))/km")
            }
        }
    }

    // MARK: Conquistas

    /// Seção única "Conquistas" (ver PLAN/badges.md). Estado locked/unlocked e
    /// VISIBILIDADE são derivados da frota via `BadgeEvaluator` (nada salvo):
    /// primeiros passos sempre aparecem; só as categorias já cadastradas entram,
    /// mostrando todos os seus níveis (desbloqueados + a perseguir).
    @ViewBuilder
    private var badgesSection: some View {
        let ctx = motorcycles.badgeFleetContext
        let visible = BadgeEvaluator.visibleBadges(ctx)
        let unlocked = BadgeEvaluator.unlockedIDs(ctx)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

        Section("Conquistas") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(visible) { badge in
                    let isUnlocked = unlocked.contains(badge.id)
                    Button {
                        selectedBadge = BadgePresentation(
                            badge: badge,
                            unlocked: isUnlocked,
                            earnedAt: isUnlocked ? earnedDates[badge.id] : nil
                        )
                        Haptics.selection()
                    } label: {
                        BadgeImageTile(
                            assetName: badge.assetName,
                            label: badge.title,
                            unlocked: isUnlocked,
                            usesBrandLogo: badge.usesBrandLogo
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Carimba a data dos badges desbloqueados (1ª vez) e recarrega o mapa de
    /// datas p/ o sheet. Sincroniza ao Supabase se algo novo foi gravado.
    private func reconcileBadges() {
        let ctx = motorcycles.badgeFleetContext
        let unlocked = BadgeEvaluator.unlockedIDs(ctx)
        let didInsert = BadgeAward.reconcile(unlockedIDs: unlocked, now: Date(), in: modelContext)
        earnedDates = BadgeAward.earnedDates(in: modelContext)
        if didInsert {
            Task { await SyncService.shared.pushAll(from: modelContext) }
        }
    }

    // MARK: Empty (zero motos)

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sua garagem está vazia", systemImage: "motorcycle")
        } description: {
            Text("Cadastre sua moto para começar.")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Cadastrar moto", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Exclusão com cascade (mesma lógica do antigo MotorcycleListView)

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var deletionPrompt: String {
        guard let moto = pendingDeletion else { return "" }
        let fuel = moto.fuelLogs.count
        let maint = moto.maintenanceLogs.count
        var parts: [String] = []
        if fuel > 0 { parts.append("\(fuel) abastecimento\(fuel == 1 ? "" : "s")") }
        if maint > 0 { parts.append("\(maint) manutenç\(maint == 1 ? "ão" : "ões")") }

        if parts.isEmpty {
            return "Excluir \(moto.displayName)?"
        }
        return "Excluir \(moto.displayName) e \(parts.joined(separator: " e "))? Esta ação não pode ser desfeita."
    }

    private func confirmDelete() {
        guard let moto = pendingDeletion else { return }
        let hadLogs = !moto.fuelLogs.isEmpty
        let count = moto.fuelLogs.count
        modelContext.delete(moto)
        try? modelContext.save()
        Haptics.warning()
        Analytics.motorcycleDeleted(hadFuelLogs: hadLogs, fuelLogCount: count,
                                    remainingBikeCount: motorcycles.count)
        pendingDeletion = nil
    }
}

#Preview {
    GarageView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
