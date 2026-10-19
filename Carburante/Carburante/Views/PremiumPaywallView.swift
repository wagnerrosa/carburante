//
//  PremiumPaywallView.swift
//  Carburante
//
//  Tela de assinatura do Carburante Premium (PLAN/premium-mvp.md §4). Tela
//  nativa da Apple (`SubscriptionStoreView`): ela já traz preço, período,
//  renovação automática e a compra. Nosso: o cabeçalho, o X, o Restaurar, o
//  cartão de cada plano (preço cheio riscado + "Economize X%" no anual) e os
//  links de Termos de Uso (EULA) e privacidade sob o botão (diretriz 3.1.2).
//
//  Contextual, nunca no launch: abre pela linha em Ajustes e no limite da
//  garagem (moto a mais, moto só para consulta — `GarageGated`), em Custos
//  completos, nos ícones de conquista e no 2º desafio criado ao mesmo tempo.
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
    /// Tentou criar um desafio com outro criado ainda em andamento.
    case challenges

    var message: String {
        switch self {
        case .settings:
            "O Carburante não tem anúncios e não vende seus dados. O Premium mantém o app assim."
        case .secondBike:
            "No plano grátis, a garagem tem uma moto ativa. Vai trocar de moto? Coloque a atual à venda e cadastre a nova."
        case .readOnlyBike:
            "No plano grátis, uma moto fica ativa por vez. Esta fica só para consulta, com todo o histórico."
        case .costs:
            "O gasto do mês é grátis. Com o Premium, você vê o ano todo, o custo real por km e para onde vai o dinheiro."
        case .icons:
            "Com o Premium, a medalha que você conquistou vira o ícone do app."
        case .challenges:
            "No plano grátis, você cria um desafio por vez. Com o Premium, cria vários ao mesmo tempo. Entrar em desafios é sempre grátis."
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
        // Termos e privacidade: links nossos sob o botão (`PolicyLinks`). A
        // linha do sistema ("Termos de Serviço e Política de Privacidade", uma
        // frase cinza entre os benefícios e os planos) não foi reconhecida
        // como link para a EULA na revisão da 1.1 (3.1.2(c), 2026-10-15).
        .storeButton(.hidden, for: .policies)
        // Restaurar e X nossos, em pílulas no topo: o X do sistema reservava
        // uma faixa vazia acima da roda, e o Restaurar grande no rodapé tirava
        // a altura do respiro do topo. Mesmo visual do sistema (glass no iOS 26).
        .storeButton(.hidden, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .overlay(alignment: .top) {
            HStack {
                RestoreButton { dismiss() }
                Spacer()
                CloseButton { dismiss() }
            }
            .padding(16)
            // Largura da tela: com texto de acessibilidade a tela da Apple
            // fica mais larga que o iPhone e as pílulas saíam pelas bordas.
            .containerRelativeFrame(.horizontal)
            // Como os botões de barra do sistema: letra limitada, para as
            // pílulas não engolirem a tela com texto de acessibilidade.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
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

/// Arte + título + frase + benefícios. A sobra de altura vira respiro em dois
/// pontos (topo e antes dos benefícios — antes dos planos o sistema já dá o
/// seu), nunca um buraco só;
/// em tela pequena cada um fica no mínimo e a arte encolhe, para os planos
/// caberem sem rolar. Tela baixa demais (iPhone SE; app de iPhone no iPad, que
/// roda nesse tamanho — foi onde a revisão da 1.1 não achou a EULA): sai a
/// arte e o cartão aperta; se ainda faltar, sai o cartão — os planos, o
/// Assinar e os links de Termos e Privacidade (3.1.2) seguem à vista. Quando a
/// tela rola (texto grande), a altura proposta é nenhuma e vale a versão
/// completa. A frase é a promessa ("Apoie o Carburante") ou, quando a tela
/// abriu por um limite, o porquê dele.
private struct PremiumHeader: View {
    let message: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            layout(art: true, benefits: true)
            layout(art: false, benefits: true)
            layout(art: false, benefits: false)
        }
    }

    private func layout(art: Bool, benefits: Bool) -> some View {
        VStack(spacing: 0) {
            if art {
                // Respiro do topo, na linha das pílulas Restaurar / X.
                Spacer(minLength: 24).frame(maxHeight: 56)

                Image("Onboarding/wheel")
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 64, idealHeight: 64, maxHeight: 88)
                    // A arte cresce até o máximo antes dos respiros.
                    .layoutPriority(1)
                    .accessibilityHidden(true)
                    .padding(.bottom, 12)
            } else {
                // Sem a arte, o título desce para baixo das pílulas (glass
                // de ~44 pt, a 16 do topo).
                Spacer(minLength: 64).frame(maxHeight: 72)
            }

            VStack(spacing: 8) {
                // "Premium" em chama, como o fim do título do onboarding.
                (Text("Carburante ") + Text("Premium").foregroundStyle(BrandTheme.flame))
                    .font((art ? Font.title : .title2).weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if benefits {
                Spacer(minLength: art ? 20 : 12).frame(maxHeight: 48)

                // Lista "o que vem junto", padrão iCloud+ / Ajustes: tile
                // colorido + uma linha. Sem a arte (tela baixa), mais justa.
                VStack(alignment: .leading, spacing: art ? 12 : 6) {
                    Benefit(symbol: "motorcycle", text: "Garagem ilimitada", compact: !art)
                    Benefit(symbol: "chart.bar.xaxis", text: "Custos completos, mês a mês", compact: !art)
                    Benefit(symbol: "medal", text: "Sua medalha vira o ícone do app", compact: !art)
                    if ChallengeFeature.isEnabled {
                        Benefit(symbol: "flag.checkered", text: "Vários desafios ao mesmo tempo", compact: !art)
                    }
                }
                .padding(art ? 14 : 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Um benefício = tile + uma linha. Tamanhos de acessibilidade: o texto
/// quebra embaixo do tile (lado a lado, o tile gigante come a largura).
private struct Benefit: View {
    let symbol: String
    let text: String
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            IconTile(systemName: symbol, tint: BrandTheme.carburante, size: compact ? 22 : 30)
                .accessibilityHidden(true)
            Text(text)
                .font((compact ? Font.subheadline : .body).weight(.medium))
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
    }
}

/// Restaurar compras (diretriz 3.1.1) numa pílula, simétrica ao X. Sincroniza
/// com a App Store; achou assinatura → fecha a tela, senão avisa.
private struct RestoreButton: View {
    let onRestored: () -> Void
    @State private var isRestoring = false
    @State private var alertMessage: String?

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                button.buttonStyle(.glass)
            } else {
                button.buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
        .tint(.primary)
        .disabled(isRestoring)
        .alert("Restaurar assinatura",
               isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var button: some View {
        Button { Task { await restore() } } label: {
            Text("Restaurar")
                .font(.subheadline.weight(.medium))
                .frame(height: 32)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return  // fechou o login da Apple: nada a dizer
        } catch {
            alertMessage = "Não foi possível falar com a App Store agora. Tente de novo."
            return
        }
        await PremiumService.shared.refresh()
        if PremiumService.shared.isPremium {
            onRestored()
        } else {
            alertMessage = "Nenhuma assinatura do Carburante Premium neste Apple ID."
        }
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
            VStack(spacing: 12) {
                SubscriptionStoreButton(option)
                PolicyLinks()
            }
        }
    }
}

/// Termos de Uso (EULA) e Política de Privacidade, com cara de link, logo
/// abaixo do Assinar — onde a revisão procura (diretriz 3.1.2(c)). Texto
/// grande: um embaixo do outro.
private struct PolicyLinks: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) { links }
            VStack(spacing: 8) { links }
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
        // Sem isso herdam o estilo do botão da loja (cápsula cheia).
        .buttonStyle(.borderless)
    }

    @ViewBuilder private var links: some View {
        Link("Termos de Uso (EULA)", destination: PremiumPaywallView.termsURL)
        Link("Política de Privacidade", destination: SettingsView.privacyPolicyURL)
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
