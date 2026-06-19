//
//  DashboardView.swift
//  Carburante
//
//  Resumo: número-herói (consumo médio) + faixa de status + grade de métricas
//  + card "Último abastecimento" (padrões Saúde/Fitness/Casa/Wallet). A ação
//  nº 1 — abastecer — fica a um toque: botão proeminente + "+" na toolbar.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    @State private var selectedID: PersistentIdentifier?
    @State private var showingFuelLog = false
    @State private var showingAddMoto = false

    /// Moto exibida: a selecionada, ou a primeira disponível.
    private var motorcycle: Motorcycle? {
        if let id = selectedID, let m = motorcycles.first(where: { $0.persistentModelID == id }) {
            return m
        }
        return motorcycles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let moto = motorcycle {
                    dashboard(for: moto)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Resumo")
            .toolbar {
                if motorcycle != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingFuelLog = true
                        } label: {
                            Label("Abastecer", systemImage: "plus")
                        }
                    }
                }
                if motorcycles.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        motorcyclePicker
                    }
                }
            }
            .sheet(isPresented: $showingFuelLog) {
                if let moto = motorcycle {
                    FuelLogFormView(motorcycle: moto)
                }
            }
            .sheet(isPresented: $showingAddMoto) {
                MotorcycleFormView()
            }
            .onChange(of: selectedID) { Haptics.selection() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nenhuma moto", systemImage: "motorcycle")
        } description: {
            Text("Cadastre sua moto para acompanhar consumo e manutenção.")
        } actions: {
            Button("Cadastrar moto") { showingAddMoto = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var motorcyclePicker: some View {
        Menu {
            Picker("Moto", selection: $selectedID) {
                ForEach(motorcycles) { moto in
                    Text(moto.displayName).tag(Optional(moto.persistentModelID))
                }
            }
        } label: {
            Label(motorcycle?.displayName ?? "Moto", systemImage: "chevron.up.chevron.down")
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func dashboard(for moto: Motorcycle) -> some View {
        let summary = moto.consumptionSummary
        let status = moto.oilChangeStatus()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status {
                    statusBanner(status)
                }

                heroBlock(summary, moto: moto)

                Button {
                    showingFuelLog = true
                } label: {
                    Label("Abastecer", systemImage: "fuelpump.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                metricsGrid(summary, moto: moto)

                if let status {
                    sectionTitle("Próxima manutenção")
                    maintenanceCard(status)
                }

                sectionTitle("Último abastecimento")
                lastFuelLogCard(moto)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Blocos

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusBanner(_ status: OilChangeStatus) -> some View {
        if status.isOverdue {
            StatusBanner(text: "Troca de óleo vencida",
                         systemImage: "exclamationmark.triangle.fill",
                         tint: .orange)
        } else {
            StatusBanner(text: "Manutenção em dia",
                         systemImage: "checkmark.seal.fill",
                         tint: .green)
        }
    }

    @ViewBuilder
    private func heroBlock(_ summary: ConsumptionSummary, moto: Motorcycle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(moto.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(summary.averageKmPerLiter.map {
                    $0.formatted(.number.precision(.fractionLength(1)).locale(AppFormat.locale))
                } ?? "—")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("km/l")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if summary.averageKmPerLiter == nil {
                Text("Registre dois abastecimentos com tanque cheio para medir o consumo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Consumo médio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricsGrid(_ summary: ConsumptionSummary, moto: Motorcycle) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(label: "Custo por km",
                       value: summary.costPerKm.map(AppFormat.currency) ?? "—",
                       systemImage: "brazilianrealsign.circle.fill",
                       tint: .green)
            MetricTile(label: "Distância medida",
                       value: AppFormat.km(summary.totalDistance),
                       systemImage: "ruler.fill",
                       tint: .blue)
            MetricTile(label: "Hodômetro",
                       value: AppFormat.km(moto.currentOdometer),
                       systemImage: "gauge.with.dots.needle.bottom.50percent",
                       tint: .indigo)
            MetricTile(label: "Abastecimentos",
                       value: moto.fuelLogs.count.formatted(),
                       systemImage: "fuelpump.fill",
                       tint: .orange)
        }
    }

    private func maintenanceCard(_ status: OilChangeStatus) -> some View {
        GroupedCard {
            VStack(spacing: 10) {
                LabeledContent("Próxima troca de óleo") {
                    Text(AppFormat.km(status.dueMileage)).monospacedDigit()
                }
                Divider()
                if status.isOverdue {
                    LabeledContent("Situação") {
                        Text("Vencida").foregroundStyle(.orange).fontWeight(.semibold)
                    }
                } else {
                    LabeledContent("Faltam") {
                        Text(AppFormat.km(status.kmRemaining)).monospacedDigit()
                    }
                }
                Divider()
                LabeledContent("Prevista para") {
                    Text(AppFormat.date(status.dueDate))
                }
            }
        }
    }

    @ViewBuilder
    private func lastFuelLogCard(_ moto: Motorcycle) -> some View {
        if let last = moto.latestFuelLog {
            NavigationLink {
                FuelLogListView(motorcycle: moto)
            } label: {
                GroupedCard {
                    HStack(spacing: 12) {
                        IconTile(systemName: "fuelpump.fill", tint: .green, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppFormat.dateTime(last.date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let place = last.placeLabel {
                                Text(place)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(AppFormat.km(last.odometer))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppFormat.currency(last.totalCost))
                                .font(.headline)
                                .monospacedDigit()
                            Text(AppFormat.liters(last.liters))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            GroupedCard {
                Text("Nenhum abastecimento registrado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
