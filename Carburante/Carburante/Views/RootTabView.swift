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
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                DashboardView()
            }
            Tab("Motos", systemImage: "motorcycle") {
                MotorcycleListView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
