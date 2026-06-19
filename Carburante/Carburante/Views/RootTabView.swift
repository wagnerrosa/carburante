//
//  RootTabView.swift
//  Carburante
//
//  Raiz do app: Dashboard + Motos. Padrão iOS (TabView). Manutenção
//  entra como aba na Fase 10.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Resumo", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                DashboardView()
            }
            Tab("Motos", systemImage: "motorcycle") {
                MotorcycleListView()
            }
        }
        // MVP Brasil-only: fixa pt-BR para entrada (vírgula decimal "12,5") e
        // saída (moeda/número/data), casando com AppFormat. Reavaliar no multi-país.
        .environment(\.locale, AppFormat.locale)
        .task {
            // Garante sessão anônima e envia os dados locais ao Supabase.
            await SyncService.shared.pushAll(from: modelContext)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
