//
//  MotorcycleListView.swift
//  Carburante
//
//  Lista de motos. Entrada do MVP enquanto não há dashboard (Fase 5).
//

import SwiftUI
import SwiftData

struct MotorcycleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if motorcycles.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma moto",
                        systemImage: "motorcycle",
                        description: Text("Cadastre sua moto para começar.")
                    )
                } else {
                    List {
                        ForEach(motorcycles) { moto in
                            NavigationLink {
                                MotorcycleProfileView(motorcycle: moto)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(moto.displayName)
                                        .font(.headline)
                                    Text("\(moto.currentOdometer, format: .number) km")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Motos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Adicionar moto", systemImage: "plus")
                    }
                }
                if !motorcycles.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MotorcycleFormView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(motorcycles[index])
        }
    }
}

#Preview {
    MotorcycleListView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
