//
//  PremiumPaywallView.swift
//  Carburante
//
//  Tela de assinatura do Carburante Premium (PLAN/premium-mvp.md §4). Tela
//  nativa da Apple (`SubscriptionStoreView`): ela já traz preço, período,
//  renovação automática, "Restaurar compras" e os links de termos e
//  privacidade que a revisão exige (diretriz 3.1.2). Nosso: o cabeçalho, o X e
//  o cartão de cada plano (preço cheio riscado + "Economize X%" no anual).
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
        // Planos em lista, um embaixo do outro, como a tela de assinaturas do
        // iOS ("Planos disponíveis") — DESIGN.md §0 — com o desconto do anual.
        .subscriptionStoreControlStyle(PlanPickerStyle())
        // Botão só "Assinar": preço e período já estão no plano marcado, e a
        // Apple escreve a renovação automática por extenso acima do botão (no
        // rótulo de duas linhas ela saía em letra miúda dentro dele).
        .subscriptionStoreButtonLabel(.action)
        // Termos e privacidade em cinza: link de apoio, não compete com o botão.
        .subscriptionStorePolicyForegroundStyle(.secondary, .secondary)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        // X nosso, sobreposto: o do sistema reservava uma faixa vazia no topo,
        // acima da roda. Mesmo visual do sistema (glass no iOS 26).
        .storeButton(.hidden, for: .cancellation)
        .overlay(alignment: .topTrailing) { CloseButton { dismiss() } }
        .subscriptionStorePolicyDestination(url: Self.termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: SettingsView.privacyPolicyURL, for: .privacyPolicy)
        .onAppear { Analytics.paywallViewed(trigger: reason.rawValue) }
        .onInAppPurchaseStart { product in
            Analytics.purchaseStarted(productID: product.id, trigger: reason.rawValue)
        }
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
            case .success(.success(.unverified)):
                // Transação que não passou na verificação da Apple: não dá direito.
                Analytics.purchaseFailed(productID: product.id, trigger: trigger, reason: "unverified")
            case .failure(let error):
                if case StoreKitError.userCancelled = error {
                    Analytics.purchaseCancelled(productID: product.id, trigger: trigger)
                } else {
                    Analytics.purchaseFailed(productID: product.id, trigger: trigger,
                                             reason: Analytics.purchaseFailureReason(error))
                }
            @unknown default:
                Analytics.purchaseFailed(productID: product.id, trigger: trigger, reason: "unknown_result")
            }
        }
        .tint(BrandTheme.carburante)
    }
}

/// Arte + título + frase + benefícios. A arte é a parte elástica: cresce com
/// a sobra de altura (sem buraco em tela grande) e fica no tamanho ideal
/// pequeno em tela pequena, para os planos caberem sem rolar — quando a tela
/// rola (texto grande), a altura proposta é nenhuma e vale o ideal, não o máximo. A frase é a promessa ("Apoie o
/// Carburante") ou, quando a tela abriu por um limite, o porquê dele.
private struct PremiumHeader: View {
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Image("Onboarding/wheel")
                .resizable()
                .scaledToFit()
                .frame(minHeight: 64, idealHeight: 64, maxHeight: 150)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                // "Premium" em chama, como o fim do título do onboarding.
                (Text("Carburante ") + Text("Premium").foregroundStyle(BrandTheme.flame))
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)

            // Lista "o que vem junto", padrão iCloud+ / Ajustes: tile colorido
            // + uma linha.
            VStack(alignment: .leading, spacing: 12) {
                Benefit(symbol: "motorcycle", text: "Garagem ilimitada")
                Benefit(symbol: "chart.bar.xaxis", text: "Custos completos, mês a mês")
                Benefit(symbol: "medal", text: "Sua medalha vira o ícone do app")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // Colado no topo, ao lado do X.
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Um benefício = tile + uma linha. Tamanhos de acessibilidade: o texto
/// quebra embaixo do tile (lado a lado, o tile gigante come a largura).
private struct Benefit: View {
    let symbol: String
    let text: String
    @Environment(\.dynamicTypeSize) private var typeSize

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            IconTile(systemName: symbol, tint: BrandTheme.carburante, size: 30)
                .accessibilityHidden(true)
            Text(text)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// X de fechar padrão do sistema: glass no iOS 26, círculo cinza antes.
private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.primary)
                .accessibilityLabel("Fechar")
            } else {
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Fechar")
            }
        }
        .padding(16)
    }
}

/// Lista de planos da Apple (`SubscriptionStorePicker` + `SubscriptionStoreButton`)
/// com o nosso cartão: no anual, o preço cheio (12× o mensal) riscado e o
/// "Economize X%". A compra continua toda na Apple.
private struct PlanPickerStyle: SubscriptionStoreControlStyle {
    func makeBody(configuration: Configuration) -> some View {
        let monthlyPrice = configuration.allOptions
            .first { $0.subscription?.subscriptionPeriod.unit == .month }?.price
        SubscriptionStorePicker(configuration) { option in
            PlanRow(option: option, monthlyPrice: monthlyPrice)
        } confirmation: { option in
            // Botão da Apple: já traz a renovação automática por extenso, acima.
            SubscriptionStoreButton(option)
        }
    }
}

private struct PlanRow: View {
    let option: SubscriptionStoreControlStyleConfiguration.PickerOption
    let monthlyPrice: Decimal?

    private var product: Product { option.subscription }

    /// Só no anual, e só se ele sair mais barato que 12× o mensal.
    private var savings: PlanSavings? {
        guard product.subscription?.subscriptionPeriod.unit == .year,
              let monthlyPrice else { return nil }
        return PlanSavings(monthly: monthlyPrice, yearly: product.price)
    }

    /// "R$ 69,90/ano" — preço da Apple (moeda da loja da conta) + período.
    static func pricePerPeriod(_ product: Product) -> String {
        let unit: String
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: unit = "/ano"
        case .month: unit = "/mês"
        case .week: unit = "/semana"
        case .day: unit = "/dia"
        default: unit = ""
        }
        return product.displayPrice + unit
    }

    private var name: some View {
        Text(product.displayName)
            .font(.title3.weight(.semibold))
    }

    @ViewBuilder private var badge: some View {
        if let savings {
            Text("Economize \(savings.percent)%")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.tint.opacity(0.15), in: .capsule)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Selo ao lado do nome; sem largura (texto grande), embaixo.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { name; badge }
                    VStack(alignment: .leading, spacing: 4) { name; badge }
                }
                HStack(spacing: 6) {
                    Text(Self.pricePerPeriod(product))
                    if let savings {
                        Text(savings.fullYearPrice.formatted(product.priceFormatStyle))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            Spacer(minLength: 0)
            Image(systemName: option.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(option.isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(option.isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var text = "\(product.displayName), \(Self.pricePerPeriod(product))"
        if let savings {
            text += ", em vez de \(savings.fullYearPrice.formatted(product.priceFormatStyle)). Economize \(savings.percent)%"
        }
        return text
    }
}

#Preview {
    PremiumPaywallView()
}
