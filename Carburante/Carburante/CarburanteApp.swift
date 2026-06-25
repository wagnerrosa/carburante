//
//  CarburanteApp.swift
//  Carburante
//
//  Created by Wagner Rosa on 17/06/26.
//

import SwiftUI
import SwiftData
import PostHog

@main
struct CarburanteApp: App {
    init() {
        let config = PostHogConfig(apiKey: PostHogSettings.apiKey, host: PostHogSettings.host)
        // Privacy: só navegação entre telas. Sem captura de taps/labels
        // individuais (app tem GPS/gastos/hodômetro — labels podem vazar dado
        // sensível). Session replay fica OFF (default).
        config.captureScreenViews = true
        config.captureElementInteractions = false
        PostHogSDK.shared.setup(config)
        // Respeita o opt-out do usuário (Ajustes → "Compartilhar dados de uso")
        // ANTES de qualquer evento. Default true (opt-out, não opt-in) p/
        // analytics anônimo de produto.
        let analyticsEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        Analytics.setEnabled(analyticsEnabled)
        Self.trackVersionUpdateIfNeeded()
    }

    /// Compara a versão do build com a última salva; emite `app_version_updated`
    /// na 1ª abertura após um update (não na 1ª instalação — sem "from").
    private static func trackVersionUpdateIfNeeded() {
        let key = "lastKnownAppVersion"
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let previous = UserDefaults.standard.string(forKey: key)
        if let previous, previous != current {
            Analytics.appVersionUpdated(from: previous, to: current)
        }
        UserDefaults.standard.set(current, forKey: key)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Motorcycle.self,
            FuelLog.self,
            MaintenanceLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
