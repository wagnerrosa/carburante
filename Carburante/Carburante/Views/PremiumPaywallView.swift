//
//  PremiumPaywallView.swift
//  Carburante
//
//  Tela de assinatura do Carburante Premium (PLAN/premium-mvp.md §4). Tela
//  nativa da Apple (`SubscriptionStoreView`): ela já traz preço, período,
//  renovação automática, "Restaurar compras" e os links de termos e
//  privacidade que a revisão exige (diretriz 3.1.2). Nosso só o cabeçalho.
//
//  Contextual, nunca no launch: abre pela linha em Ajustes e no limite da
//  garagem (moto a mais, moto só para consulta — `GarageGated`); nos próximos
//  passos, em Custos completos e nos ícones de conquista.
//  Identidade do Carburante, não da moto — "Apoie o Carburante" fala do app
//  (DESIGN.md §1, exceção 3, como o onboarding).
//

import SwiftUI
import StoreKit

/// De onde a tela de assinatura abriu — muda a frase do cabeçalho. O rawValue
/// é o `trigger` do analytics (`paywall_viewed`, `purchase_*`): chave
/// congelada, não renomear.
enum PaywallReason: String {
    /// Linha "Carburante Premium" em Ajustes.
    case settings
    /// Tentou cadastrar mais uma moto com a garagem cheia.
    case secondBike = "second_bike"
    /// Tentou registrar numa moto só para consulta.
    case readOnlyBike = "read_only_bike"
    /// Tela Custos sem Premium.
    case costs
    /// Escolheu um ícone de conquista sem Premium.
    case icons

    var message: String {
        switch self {
        case .settings:
            "Sem anúncios. Seus dados não são vendidos. O Premium mantém o Carburante."
        case .secondBike:
            "No plano grátis, a garagem tem uma moto ativa. Vai trocar de moto? Coloque a atual à venda e cadastre a nova."
        case .readOnlyBike:
            "No plano grátis, uma moto fica ativa por vez. Esta fica só para consulta, com todo o histórico."
        case .costs:
            "O gasto do mês é grátis. Com o Premium, você vê o ano todo, o custo real por km e para onde vai o dinheiro."
        case .icons:
            "Com o Premium, a medalha que você conquistou vira o ícone do app."
        }
    }
}

struct PremiumPaywallView: View {
    var reason: PaywallReason = .settings
    @Environment(\.dismiss) private var dismiss

    /// Termos de uso = EULA padrão da Apple (o mesmo link vai na descrição da loja).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        // Anual primeiro: é o plano que já vem marcado.
        SubscriptionStoreView(productIDs: [PremiumEntitlement.yearlyID, PremiumEntitlement.monthlyID]) {
            PremiumHeader(message: reason.message)
        }
        // Planos lado a lado: os dois cabem sem rolar.
        .subscriptionStoreControlStyle(.compactPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: Self.termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: SettingsView.privacyPolicyURL, for: .privacyPolicy)
        .onAppear { Analytics.paywallViewed(trigger: reason.rawValue) }
        .onInAppPurchaseCompletion { product, result in
            let trigger = reason.rawValue
            switch result {
            case .success(.success(.verified(let transaction))):
                Analytics.purchaseCompleted(productID: transaction.productID, trigger: trigger)
                await transaction.finish()
                await PremiumService.shared.refresh()
                Haptics.success()
                dismiss()
            case .success(.userCancelled):
                Analytics.purchaseCancelled(productID: product.id, trigger: trigger)
            case .success(.pending):
                Analytics.purchasePending(productID: product.id, trigger: trigger)
            default:
                // Erro do StoreKit ou transação que não passou na verificação.
                Analytics.purchaseFailed(productID: product.id, trigger: trigger)
            }
        }
        .tint(BrandTheme.carburante)
    }
}

/// Arte + frase + os três benefícios. Curto: a tela da Apple embaixo já ocupa
/// metade da altura. A frase é a promessa ("Apoie o Carburante") ou, quando a
/// tela abriu por um limite, o porquê dele.
private struct PremiumHeader: View {
    let message: String

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
                Text(message)
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
