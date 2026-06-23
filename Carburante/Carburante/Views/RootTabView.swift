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
    /// Onboarding concluído (ou pulado) — persiste localmente. Enquanto false, o
    /// fluxo de boas-vindas cobre o app. Default false → exibido na 1ª execução.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    /// Apresenta o cadastro de moto logo após o onboarding (CTA "Cadastrar minha
    /// moto") — leva o usuário direto ao caminho do 1º abastecimento.
    @State private var showRegisterMotorcycle = false

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
        // Onboarding de primeira execução: cobre tudo até concluir/pular.
        .fullScreenCover(isPresented: showOnboardingBinding) {
            OnboardingView(
                onRegisterMotorcycle: {
                    hasCompletedOnboarding = true
                    // Abre o cadastro de moto na próxima passada de runloop, depois
                    // do cover fechar (evita conflito de apresentação de sheets).
                    DispatchQueue.main.async { showRegisterMotorcycle = true }
                },
                onExplore: { hasCompletedOnboarding = true }
            )
            // Onboarding sem moto ativa → tema padrão do app.
            .tint(activeTint)
        }
        .sheet(isPresented: $showRegisterMotorcycle) {
            MotorcycleFormView()
        }
        .task {
            // Garante sessão anônima e envia os dados locais ao Supabase.
            await SyncService.shared.pushAll(from: modelContext)
        }
    }

    /// O cover aparece enquanto o onboarding não foi concluído; o callback de
    /// conclusão grava a flag, então o binding fecha sozinho.
    private var showOnboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
