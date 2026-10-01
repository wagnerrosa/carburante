//
//  OnboardingView.swift
//  Carburante
//
//  Onboarding de primeira execução (fonte de verdade: PLAN/onboarding.md).
//  Objetivo: explicar o valor do app e levar o usuário ao cadastro da 1ª moto
//  com o mínimo de atrito. Quatro telas de valor + um CTA final.
//
//  HIG/nativo: TabView paginada (mesmo padrão do onboarding do sistema), arte
//  grande + título + descrição, botão primário fixo no rodapé. Sem libs, sem
//  animações supérfluas. Light/Dark automáticos.
//  Identidade do Carburante (não da moto): ainda não há moto cadastrada, então
//  é o único lugar com a cor e a arte da marca — vermelho + chama da landing,
//  objetos 3D da mesma família das medalhas (DESIGN.md §1, exceção 3).
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

    /// Nome estável do passo para analytics (índice → slug). CTA é o último.
    private func stepName(_ index: Int) -> String {
        let names = ["value_intro", "ocr", "full_to_full", "maintenance"]
        return index < names.count ? names[index] : "cta"
    }

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
        .tint(BrandTheme.carburante)
        .onAppear {
            Analytics.onboardingStarted()
            Analytics.onboardingStepViewed(stepIndex: 0, stepName: stepName(0))
        }
        .onChange(of: page) { _, newPage in
            Analytics.onboardingStepViewed(stepIndex: newPage, stepName: stepName(newPage))
        }
    }

    // MARK: - Cabeçalho (Pular)

    private var header: some View {
        HStack {
            Spacer()
            // "Pular" é o caminho de saída direto (HIG): visível, discreto, sempre
            // disponível. Some na página de CTA, onde "Explorar" cumpre o papel.
            if !isCTA {
                Button("Pular") {
                    Analytics.onboardingCompleted(exit: "skipped", lastStepIndex: page)
                    onExplore()
                }
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
                Button {
                    Analytics.onboardingCompleted(exit: "added_bike", lastStepIndex: page)
                    onRegisterMotorcycle()
                } label: {
                    Text("Cadastrar minha moto")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Explorar aplicativo") {
                    Analytics.onboardingCompleted(exit: "explored", lastStepIndex: page)
                    onExplore()
                }
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

/// Conteúdo de uma tela de onboarding: arte 3D + título + texto. A tela de
/// consumo acrescenta o passo a passo do tanque cheio a tanque cheio.
struct OnboardingPage: Identifiable {
    let id = UUID()
    /// Imageset em `Assets.xcassets/Onboarding/`.
    let art: String
    let title: String
    /// Fim do título no gradiente chama (como "de verdade." na landing).
    var flame: String? = nil
    let message: String
    /// Tela especial do método Full-to-Full (renderiza o stepper).
    var isFullToFull = false

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            art: "Onboarding/wheel",
            title: "Saiba quanto sua moto faz",
            flame: "de verdade.",
            message: "Consumo real, de tanque cheio a tanque cheio, e manutenção em dia."
        ),
        OnboardingPage(
            art: "Onboarding/station",
            title: "Abasteça em segundos",
            message: "Fotografe o painel e o comprovante: o app lê os números e você só confere. O local do posto entra sozinho."
        ),
        OnboardingPage(
            art: "Onboarding/stopwatch",
            title: "Tanque cheio a tanque cheio",
            message: "O jeito que não mente: o consumo é medido entre dois tanques cheios.",
            isFullToFull: true
        ),
        OnboardingPage(
            art: "Onboarding/oil",
            title: "Manutenção em dia",
            message: "Troca de óleo, pneus, relação, freios e revisão. O app avisa antes de vencer — por km ou por data, o que chegar primeiro."
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

                OnboardingArt(name: page.art)

                title
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
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            // Respiro para os pontos de página não colarem no conteúdo.
            .padding(.bottom, 36)
        }
    }

    /// Título com o fim em chama, quando houver ("…faz de verdade.").
    private var title: Text {
        guard let flame = page.flame else { return Text(page.title) }
        return Text(page.title + " ") + Text(flame).foregroundStyle(BrandTheme.flame)
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
                Text("O primeiro km/l aparece no segundo tanque cheio.")
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
        .accessibilityLabel("Como o consumo é calculado: tanque cheio, rodar normalmente, próximo tanque cheio, consumo calculado. O primeiro km/l aparece no segundo tanque cheio.")
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

                OnboardingArt(name: "Onboarding/flag")

                Text("Pronto para começar?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cadastre sua moto e registre o próximo abastecimento.")
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

// MARK: - Arte 3D

/// Objeto 3D da página (mesma família das medalhas e da landing). Decorativo:
/// o título já diz o assunto.
private struct OnboardingArt: View {
    let name: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 160)
            .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView(onRegisterMotorcycle: {}, onExplore: {})
}
