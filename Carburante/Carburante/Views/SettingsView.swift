//
//  SettingsView.swift
//  Carburante
//
//  Ajustes do app. No MVP, o foco é o controle de privacidade exigido pela App
//  Store: ligar/desligar o compartilhamento de dados de uso (analytics). Padrão
//  nativo (Form + Toggle), sem libs.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Compartilhar dados de uso (analytics). Default true — analytics de produto
    /// anônimo é opt-out (sem ATT/IDFA). A fonte de verdade do opt-out é aplicada
    /// ao PostHog em `CarburanteApp` no launch e aqui na mudança.
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                AccountView()

                Section {
                    Toggle("Compartilhar dados de uso", isOn: $analyticsEnabled)
                        .onChange(of: analyticsEnabled) { _, on in
                            Analytics.setEnabled(on)
                        }
                    // Exigido pela App Store (5.1.1): política acessível de dentro do app.
                    Link("Política de privacidade", destination: Self.privacyPolicyURL)
                } header: {
                    Text("Privacidade")
                } footer: {
                    Text("Estatísticas anônimas de uso ajudam a melhorar o app. Nunca coletamos localização, valores ou quilometragem exatos — só eventos agregados. Você pode desligar a qualquer momento.")
                }

                Section {
                    LabeledContent("Versão", value: appVersion)
                } footer: {
                    Text("Nomes e logotipos de fabricantes de motos são marcas comerciais ou registradas de seus respectivos detentores e aparecem no app só para identificar a sua moto. O Carburante é independente e não tem afiliação, patrocínio ou endosso de nenhum fabricante.")
                }
            }
            .navigationTitle("Ajustes")
            // Sheet sem botão de fechar dependia só do swipe-down.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    /// Mesma URL informada no App Store Connect (campo Privacy Policy URL).
    static let privacyPolicyURL = URL(string: "https://wagnerrosa.com/carburante/privacidade/")!

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
}
