//
//  AppIconPickerView.swift
//  Carburante
//
//  "Ícone do app" (Ajustes): o padrão + um ícone por arte de medalha
//  (`AppIconCatalog`). Conquistada → toque troca o ícone (o iOS mostra o aviso
//  dele); bloqueada → arte apagada + cadeado. Também usado pelo atalho no
//  cartão da medalha.
//
//  Premium (PLAN/premium-mvp.md §3): sem assinatura, tocar num ícone de
//  conquista abre a tela de assinatura; assinando ali, o ícone escolhido já é
//  aplicado quando ela fecha. O padrão é sempre livre — inclusive para voltar
//  a ele depois que a assinatura acaba (o ícone em uso não é trocado sozinho:
//  o iOS mostraria o aviso de troca a qualquer hora).
//

import SwiftUI
import SwiftData
import UIKit

/// Miniatura de um ícone: o mesmo fundo escuro do `carburante.icon` com a arte
/// no centro, no formato de ícone do iOS. Prévia — o ícone real é do sistema.
struct AppIconPreview: View {
    let option: AppIconOption
    var size: CGFloat = 72

    private var art: Image {
        option.art.map { Image("Badges/\($0)") } ?? Image("Onboarding/wheel")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.displayP3, red: 0.22, green: 0.22, blue: 0.23),
                         Color(.displayP3, red: 0.05, green: 0.05, blue: 0.055)],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.7))
            art
                .resizable()
                .scaledToFit()
                .padding(size * 0.09)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.224, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Troca o ícone do app (o iOS exige app em primeiro plano e mostra o aviso).
enum AppIconChanger {
    static var current: AppIconOption {
        AppIconCatalog.option(forIconName: UIApplication.shared.alternateIconName)
    }

    /// Ícone que exige Premium e a pessoa não tem: abre a assinatura em vez de trocar.
    @MainActor
    static func needsPremium(_ option: AppIconOption) -> Bool {
        option != AppIconCatalog.defaultOption && !PremiumService.shared.isPremium
    }

    static func apply(_ option: AppIconOption) async -> Bool {
        guard UIApplication.shared.supportsAlternateIcons else { return false }
        do {
            try await UIApplication.shared.setAlternateIconName(option.iconName)
            Haptics.success()
            Analytics.appIconChanged(to: option.id)
            return true
        } catch {
            return false
        }
    }
}

/// Medalhas conquistadas da frota — a mesma conta da Garagem (avaliação atual
/// ∪ medalhas já ganhas, que nunca se perdem).
@MainActor
func unlockedIconArts(motorcycles: [Motorcycle], context: ModelContext) -> Set<String> {
    let earned = Set(BadgeAward.earnedDates(in: context).keys)
    let ids = BadgeEvaluator.unlockedIDs(motorcycles.badgeFleetContext, keeping: earned)
    return AppIconCatalog.unlockedArts(unlockedBadgeIDs: ids)
}

struct AppIconPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Motorcycle.activePredicate) private var motorcycles: [Motorcycle]
    @State private var current = AppIconChanger.current
    @State private var failed = false
    /// Ícone tocado sem Premium: aplicado se a assinatura sair.
    @State private var pending: AppIconOption?
    @State private var showPaywall = false

    var body: some View {
        let unlockedArts = unlockedIconArts(motorcycles: motorcycles, context: modelContext)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 20) {
                    ForEach(AppIconCatalog.options) { option in
                        let unlocked = AppIconCatalog.isUnlocked(option, unlockedArts: unlockedArts)
                        Button {
                            choose(option)
                        } label: {
                            cell(option, unlocked: unlocked)
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                    }
                }
                Text(PremiumService.shared.isPremium
                     ? "Cada medalha da Garagem libera um ícone. Os bloqueados aparecem apagados até você conquistar a medalha."
                     : "Os ícones de conquista são do Carburante Premium. Cada medalha da Garagem libera um ícone; os bloqueados aparecem apagados até você conquistar a medalha.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ícone do app")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Não foi possível trocar o ícone", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
        // onDismiss = depois que a folha sumiu: o iOS só troca o ícone (e
        // mostra o aviso) com a tela livre.
        .sheet(isPresented: $showPaywall, onDismiss: paywallClosed) {
            PremiumPaywallView(reason: .icons)
        }
    }

    private func paywallClosed() {
        guard let option = pending else { return }
        pending = nil
        if !AppIconChanger.needsPremium(option) { choose(option) }
    }

    private func cell(_ option: AppIconOption, unlocked: Bool) -> some View {
        let selected = option == current
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                AppIconPreview(option: option)
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
                    .overlay {
                        RoundedRectangle(cornerRadius: 72 * 0.224 + 4, style: .continuous)
                            // `.tint`, não `Color.accentColor` (este não segue o tema).
                            .strokeBorder(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear),
                                          lineWidth: 3)
                            .padding(-4)
                    }
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: 6, y: 6)
                }
            }
            Text(option.title)
                .font(.caption)
                .foregroundStyle(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(option.title)
        .accessibilityValue(selected ? "Em uso" : unlocked ? "" : "Bloqueado")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choose(_ option: AppIconOption) {
        guard option != current else { return }
        guard !AppIconChanger.needsPremium(option) else {
            pending = option
            showPaywall = true
            return
        }
        Task {
            if await AppIconChanger.apply(option) {
                current = option
            } else {
                failed = true
            }
        }
    }
}

/// Atalho no cartão de uma medalha conquistada: "Usar como ícone do app".
struct AppIconShortcut: View {
    let option: AppIconOption
    @State private var current = AppIconChanger.current
    @State private var showPaywall = false

    var body: some View {
        if option == current {
            Label("Este é o ícone do app", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            Button {
                if AppIconChanger.needsPremium(option) {
                    showPaywall = true
                } else {
                    apply()
                }
            } label: {
                HStack(spacing: 10) {
                    AppIconPreview(option: option, size: 28)
                    Text("Usar como ícone do app")
                }
            }
            .buttonStyle(.bordered)
            // Assinou na tela que abriu daqui: aplica o ícone que pediu.
            .sheet(isPresented: $showPaywall, onDismiss: {
                if !AppIconChanger.needsPremium(option) { apply() }
            }) {
                PremiumPaywallView(reason: .icons)
            }
        }
    }

    private func apply() {
        Task {
            if await AppIconChanger.apply(option) { current = option }
        }
    }
}
