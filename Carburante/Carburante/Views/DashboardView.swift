//
//  DashboardView.swift
//  Carburante
//
//  Tela inicial: indicadores principais da moto selecionada.
//  Consome ConsumptionCalculator (Fase 4). Próxima manutenção entra na Fase 10.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    @State private var selectedID: PersistentIdentifier?

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
                    ContentUnavailableView(
                        "Sem motos",
                        systemImage: "motorcycle",
                        description: Text("Cadastre uma moto na aba Motos para ver o resumo.")
                    )
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                if motorcycles.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        motorcyclePicker
                    }
                }
            }
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
        List {
            Section {
                LabeledContent("Moto", value: moto.displayName)
                LabeledContent("Hodômetro") {
                    Text("\(moto.currentOdometer, format: .number) km")
                }
            }

            Section("Consumo") {
                if let avg = summary.averageKmPerLiter {
                    metric("Consumo médio", "\(avg.formatted(.number.precision(.fractionLength(1)))) km/l")
                    metric("Distância medida", "\(summary.totalDistance.formatted(.number)) km")
                    if let cpk = summary.costPerKm {
                        metric("Custo por km", "R$ \(cpk.formatted(.number.precision(.fractionLength(2))))")
                    }
                } else {
                    Text("Registre dois abastecimentos com tanque cheio para medir o consumo.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            Section("Próxima manutenção") {
                if let status = moto.oilChangeStatus() {
                    LabeledContent("Troca de óleo") {
                        Text("\(status.dueMileage.formatted(.number)) km")
                    }
                    if status.isOverdue {
                        Label("Troca de óleo vencida", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    } else {
                        metric("Faltam", "\(status.kmRemaining.formatted(.number)) km")
                    }
                    metric("Prevista para", status.dueDate.formatted(.dateTime.day().month().year()))
                } else {
                    Text("Registre uma troca de óleo para prever a próxima.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            Section("Último abastecimento") {
                if let last = moto.latestFuelLog {
                    metric("Data", last.date.formatted(.dateTime.day().month().year()))
                    metric("Hodômetro", "\(last.odometer.formatted(.number)) km")
                    metric("Litros", "\(last.liters.formatted(.number)) L")
                    metric("Valor", "R$ \(last.totalCost.formatted(.number.precision(.fractionLength(2))))")
                } else {
                    Text("Nenhum abastecimento registrado.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
