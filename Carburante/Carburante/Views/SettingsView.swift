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
                } header: {
                    Text("Privacidade")
                } footer: {
                    Text("Estatísticas anônimas de uso ajudam a melhorar o app. Nunca coletamos localização, valores ou quilometragem exatos — só eventos agregados. Você pode desligar a qualquer momento.")
                }

                Section {
                    LabeledContent("Versão", value: appVersion)
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
}
