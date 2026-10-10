//
//  PremiumPaywallView.swift
//  Carburante
//
//  Tela de assinatura do Carburante Premium (PLAN/premium-mvp.md §4). Tela
//  nativa da Apple (`SubscriptionStoreView`): ela já traz preço, período,
//  renovação automática, "Restaurar compras" e os links de termos e
//  privacidade que a revisão exige (diretriz 3.1.2). Nosso só o cabeçalho.
//
//  Contextual, nunca no launch: abre pela linha em Ajustes (e, nos próximos
//  passos, na 2ª moto, em Custos completos e nos ícones de conquista).
//  Identidade do Carburante, não da moto — "Apoie o Carburante" fala do app
//  (DESIGN.md §1, exceção 3, como o onboarding).
//

import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// Termos de uso = EULA padrão da Apple (o mesmo link vai na descrição da loja).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        // Anual primeiro: é o plano que já vem marcado.
        SubscriptionStoreView(productIDs: [PremiumEntitlement.yearlyID, PremiumEntitlement.monthlyID]) {
            PremiumHeader()
        }
        // Planos lado a lado: os dois cabem sem rolar.
        .subscriptionStoreControlStyle(.compactPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: Self.termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: SettingsView.privacyPolicyURL, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, result in
            guard case .success(.success(let verification)) = result,
                  case .verified(let transaction) = verification else { return }
            await transaction.finish()
            await PremiumService.shared.refresh()
            Haptics.success()
            dismiss()
        }
        .tint(BrandTheme.carburante)
    }
}

/// Arte + promessa + os três benefícios. Curto: a tela da Apple embaixo já
/// ocupa metade da altura.
private struct PremiumHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image("Onboarding/wheel")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)
                    .accessibilityHidden(true)
                Text("Carburante Premium")
                    .font(.title2.weight(.bold))
                Text("Sem anúncios. Seus dados não são vendidos. O Premium mantém o Carburante.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Benefit(symbol: "motorcycle",
                        title: "Garagem ilimitada",
                        detail: "Quantas motos quiser.")
                Benefit(symbol: "chart.bar.xaxis",
                        title: "Custos completos",
                        detail: "Gasolina e manutenção, por mês e por km.")
                Benefit(symbol: "medal",
                        title: "Ícones de conquista",
                        detail: "Sua medalha vira o ícone do app.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

private struct Benefit: View {
    let symbol: String
    let title: String
    let detail: String
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Tamanhos de acessibilidade: ícone em cima do texto (lado a lado, o
    /// símbolo gigante come a largura do título).
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
    }

    var body: some View {
        layout {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                // Coluna fixa lado a lado (a moto é mais larga que os outros
                // símbolos e desalinhava os textos); empilhado, largura livre.
                .frame(width: typeSize.isAccessibilitySize ? nil : 36,
                       alignment: typeSize.isAccessibilitySize ? .leading : .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PremiumPaywallView()
}
