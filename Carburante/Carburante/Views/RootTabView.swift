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
    @Query(sort: \Motorcycle.createdAt, order: .reverse) private var motorcycles: [Motorcycle]
    /// Mesma chave do Resumo — fonte única da moto ativa, define o tema global.
    @AppStorage("activeMotorcycleID") private var activeMotorcycleID: String = ""

    /// Cor de destaque global = tema da moto ativa (ou padrão sem moto).
    private var activeTint: Color {
        let moto = motorcycles.first { $0.id.uuidString == activeMotorcycleID } ?? motorcycles.first
        return moto?.themeColor ?? BrandTheme.default
    }

    var body: some View {
        TabView {
            Tab("Resumo", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                DashboardView()
            }
            Tab("Motos", systemImage: "motorcycle") {
                MotorcycleListView()
            }
        }
        // Tema global: tinge tudo que herda accent (tab bar, controles, links).
        // Telas de uma moto específica sobrepõem com a cor da própria moto.
        .tint(activeTint)
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
