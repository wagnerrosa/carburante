//
//  GarageGate.swift
//  Carburante
//
//  Liga o limite da garagem (`GarageLimit`, regra pura) às telas. O
//  `RootTabView` calcula o acesso uma vez (motos da garagem + Premium) e
//  entrega pelo environment. As sheets de registro passam por `GarageGated`,
//  que troca o formulário pelo paywall quando a moto está só para consulta ou
//  quando não cabe outra moto — uma porta só, cada tela continua abrindo a sua
//  sheet como antes (PLAN/premium-mvp.md §Riscos: "concentrar a decisão").
//

import SwiftUI

extension EnvironmentValues {
    /// Acesso da garagem no plano grátis. Default sem limite: preview e telas
    /// fora do `RootTabView` nunca travam por engano.
    @Entry var garageAccess: GarageLimit.Access = .unlimited
}

extension GarageLimit {
    /// Acesso calculado das motos do app (vendidas podem vir junto: a regra
    /// ignora). Lê o Premium do `PremiumService` — quem chama de dentro de um
    /// `body` passa a observar a assinatura.
    @MainActor
    static func access(for motorcycles: [Motorcycle], now: Date = .now) -> Access {
        access(for: motorcycles.map(Bike.init),
               isPremium: PremiumService.shared.isPremium,
               launch: effectiveLaunch,
               now: now)
    }

    /// Corte em uso. Em DEBUG, `-debugNoLegacyBikes YES` faz toda moto contar
    /// para o limite — o simulador só tem motos anteriores ao corte.
    private static var effectiveLaunch: Date {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "debugNoLegacyBikes") == "YES" { return .distantPast }
        #endif
        return premiumLaunch
    }
}

extension GarageLimit.Bike {
    init(_ motorcycle: Motorcycle) {
        let lastLog = (motorcycle.activeFuelLogs.map(\.createdAt)
                       + motorcycle.activeMaintenanceLogs.map(\.createdAt)).max()
        self.init(id: motorcycle.id,
                  status: motorcycle.status,
                  createdAt: motorcycle.createdAt,
                  lastActivity: max(motorcycle.createdAt, lastLog ?? .distantPast))
    }
}

extension GarageLimit.Access {
    /// Rótulo de situação da moto nas listas: o do estado (à venda, vendida)
    /// ou "Só consulta" quando o limite trava. Na garagem e livre: nada.
    func label(for motorcycle: Motorcycle) -> String? {
        motorcycle.status.label ?? (isReadOnly(motorcycle.id) ? "Só consulta" : nil)
    }
}

/// Conteúdo de uma sheet de registro: o formulário, ou o paywall quando a moto
/// está só para consulta (ou, no cadastro, quando não cabe outra moto).
///
/// A decisão vale para a sheet inteira: salvar a 1ª moto deixa a garagem
/// cheia, e o formulário não pode virar paywall enquanto a sheet fecha.
struct GarageGated<Content: View>: View {
    private let motorcycle: Motorcycle?
    private let content: Content
    @Environment(\.garageAccess) private var access
    @State private var decided: Bool?

    /// Registro ou edição numa moto.
    init(_ motorcycle: Motorcycle, @ViewBuilder content: () -> Content) {
        self.motorcycle = motorcycle
        self.content = content()
    }

    /// Cadastro de moto nova.
    init(@ViewBuilder newMotorcycle content: () -> Content) {
        self.motorcycle = nil
        self.content = content()
    }

    private var allowedNow: Bool {
        guard let motorcycle else { return access.canAddMotorcycle }
        return !access.isReadOnly(motorcycle.id)
    }

    var body: some View {
        let allowed = decided ?? allowedNow
        Group {
            if allowed {
                content
            } else {
                PremiumPaywallView(reason: motorcycle == nil ? .secondBike : .readOnlyBike)
            }
        }
        .onAppear { if decided == nil { decided = allowed } }
    }
}
