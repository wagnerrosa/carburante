//
//  OnboardingView.swift
//  Carburante
//
//  Onboarding de primeira execução (fonte de verdade: PLAN/onboarding.md).
//  Objetivo: explicar o valor do app e levar o usuário ao cadastro da 1ª moto
//  com o mínimo de atrito. Quatro telas de valor + um CTA final.
//
//  HIG/nativo: TabView paginada (mesmo padrão do onboarding do sistema), ícone
//  grande + título + descrição, botão primário fixo no rodapé. Sem libs, sem
//  animações supérfluas, sem linguagem promocional. Light/Dark automáticos.
//  A accent color segue o tema global (.tint do RootTabView).
//

import SwiftUI

struct OnboardingView: View {
    /// Concluir (CTA principal) → cadastrar moto. Explorar → só fecha.
    let onRegisterMotorcycle: () -> Void
    let onExplore: () -> Void

    @State private var page = 0

    /// Telas de valor (as 4 do documento). O CTA é a última página, tratada à parte.
    private static let pages = OnboardingPage.allPages
    private var lastFeatureIndex: Int { Self.pages.count - 1 }
    /// Índice da página de CTA (logo após a última tela de valor).
    private var ctaIndex: Int { Self.pages.count }
    private var isCTA: Bool { page == ctaIndex }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $page) {
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, info in
                    OnboardingPageView(page: info)
                        .tag(index)
                }
                OnboardingCTAView()
                    .tag(ctaIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            // Pontos de página visíveis sobre qualquer fundo (claro/escuro).
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            footer
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Cabeçalho (Pular)

    private var header: some View {
        HStack {
            Spacer()
            // "Pular" é o caminho de saída direto (HIG): visível, discreto, sempre
            // disponível. Some na página de CTA, onde "Explorar" cumpre o papel.
            if !isCTA {
                Button("Pular") { onExplore() }
                    .font(.body)
                    .tint(.secondary)
            }
        }
        .frame(height: 28)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Rodapé (ações)

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            if isCTA {
                Button(action: onRegisterMotorcycle) {
                    Text("Cadastrar minha moto")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Explorar aplicativo", action: onExplore)
                    .controlSize(.large)
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Continuar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Modelo de uma tela de valor

/// Conteúdo de uma tela de onboarding. Telas comuns usam só ícone+título+texto
/// (+ bullets opcionais); a tela de consumo usa um layout próprio (stepper).
struct OnboardingPage: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let message: String
    /// Benefícios curtos (linhas com check). Vazio = sem lista.
    var bullets: [String] = []
    /// Tela especial do método Full-to-Full (renderiza o stepper).
    var isFullToFull = false

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "fuelpump.fill",
            title: "Sua moto, seus números",
            message: "Registre abastecimentos, acompanhe consumo, custos e manutenção da sua motocicleta em um só lugar."
        ),
        OnboardingPage(
            symbol: "camera.viewfinder",
            title: "Abasteça em poucos toques",
            message: "Use OCR para capturar informações do hodômetro e do comprovante. A localização é preenchida automaticamente.",
            bullets: [
                "OCR do hodômetro",
                "OCR do comprovante",
                "Localização automática",
                "Registro rápido",
            ]
        ),
        OnboardingPage(
            symbol: "gauge.with.dots.needle.67percent",
            title: "Entenda o consumo da sua moto",
            message: "O consumo é calculado usando o método Full-to-Full.",
            isFullToFull: true
        ),
        OnboardingPage(
            symbol: "wrench.and.screwdriver",
            title: "Cuide da sua moto",
            message: "Acompanhe trocas de óleo, pneus, freios, filtros, relação e revisões gerais.",
            bullets: [
                "Histórico completo",
                "Alertas automáticos",
                "Intervalos por quilometragem e tempo",
                "Próximas manutenções",
            ]
        ),
    ]
}

// MARK: - Tela de valor genérica

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                Image(systemName: page.symbol)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)

                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if page.isFullToFull {
                    FullToFullExplainer()
                        .padding(.top, 4)
                } else if !page.bullets.isEmpty {
                    OnboardingBullets(items: page.bullets)
                        .padding(.top, 4)
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            // Respiro para os pontos de página não colarem no conteúdo.
            .padding(.bottom, 36)
        }
    }
}

/// Lista de benefícios — linhas com check na cor do tema (padrão Ajustes).
private struct OnboardingBullets: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Explicação do Full-to-Full (atenção especial — PLAN/onboarding.md)

/// O coração do onboarding: por que o consumo NÃO aparece logo no 1º
/// abastecimento. Mostra o fluxo (cheio → rodar → cheio → consumo) como um
/// stepper vertical nativo + um aviso explícito de expectativa.
private struct FullToFullExplainer: View {
    private struct Step: Identifiable {
        let id = UUID()
        let symbol: String
        let text: String
        /// Passo final (resultado) — destaca na cor do tema.
        var isResult = false
    }

    private let steps: [Step] = [
        Step(symbol: "fuelpump.fill", text: "Tanque cheio"),
        Step(symbol: "road.lanes", text: "Rodar normalmente"),
        Step(symbol: "fuelpump.fill", text: "Próximo tanque cheio"),
        Step(symbol: "gauge.with.dots.needle.67percent", text: "Consumo calculado", isResult: true),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Fluxo vertical: ícone + texto por etapa, conectados por uma seta
            // ALINHADA À ESQUERDA, sob a coluna de ícones (largura 28) — a seta
            // segue o eixo dos ícones, não o centro do card. Senão a seta fica
            // solta no meio enquanto as etapas encostam na borda.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step)
                    if index < steps.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)  // mesma largura do ícone → centra no eixo
                            .padding(.vertical, 6)
                            .accessibilityHidden(true)
                    }
                }
            }

            // Aviso de expectativa — o ponto central do documento: o usuário não
            // deve esperar ver consumo logo após o primeiro abastecimento.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Os primeiros indicadores aparecem após abastecimentos suficientes para calcular o consumo corretamente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        // O VoiceOver lê o fluxo como uma frase única e direta.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Como o consumo é calculado: tanque cheio, rodar normalmente, próximo tanque cheio, consumo calculado. Os primeiros indicadores aparecem após abastecimentos suficientes.")
    }

    private func stepRow(_ step: Step) -> some View {
        HStack(spacing: 14) {
            Image(systemName: step.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(step.isResult ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 28)
            Text(step.text)
                .font(.body.weight(step.isResult ? .semibold : .regular))
                .foregroundStyle(step.isResult ? .primary : .primary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Página de CTA

private struct OnboardingCTAView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                Image(systemName: "motorcycle")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)

                Text("Pronto para começar?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cadastre sua moto para registrar o primeiro abastecimento.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }
}

#Preview {
    OnboardingView(onRegisterMotorcycle: {}, onExplore: {})
        .tint(BrandTheme.default)
}
