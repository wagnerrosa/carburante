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
        let config = PostHogConfig(projectToken: PostHogSettings.apiKey, host: PostHogSettings.host)
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
        Analytics.registerInstallProperties()
        Self.trackVersionUpdateIfNeeded()
        // Assinatura: lê o direito e passa a ouvir o StoreKit desde o launch.
        PremiumService.shared.start()
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
            BadgeAward.self,
            MotorcycleOwnership.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Store corrompido ou migração incompatível: em vez de crashar no
            // launch (fatalError deixava o app inabrível — pior caso p/ um
            // testador), tenta recuperar apagando o store local e recriando.
            // O store antigo é RENOMEADO (backup), não apagado: dado local não
            // sincronizado fica recuperável à mão; o pull no launch traz de
            // volta o que já subiu ao Supabase. Melhor que um app morto.
            Analytics.syncFailed(stage: "model_container", errorCode: SyncService.errorCode(error))
            if let recovered = Self.recreateContainerDroppingStore(schema: schema, configuration: modelConfiguration) {
                return recovered
            }
            // Último recurso: container em memória. O app abre e funciona nesta
            // sessão (offline); nada persiste em disco, mas não crasha.
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memoryContainer = try? ModelContainer(for: schema, configurations: [inMemory]) {
                return memoryContainer
            }
            fatalError("Could not create ModelContainer even in memory: \(error)")
        }
    }()

    /// Move o store default do SwiftData para um backup datado e tenta recriar o
    /// container. Chamado só quando a abertura normal falha (store corrompido/
    /// migração). Backup em vez de apagar: uma migração ruim numa atualização
    /// não destrói dado local ainda não sincronizado.
    private static func recreateContainerDroppingStore(
        schema: Schema, configuration: ModelConfiguration
    ) -> ModelContainer? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        // SwiftData grava default.store (+ -wal/-shm) em Application Support.
        let base = appSupport.appendingPathComponent("default.store")
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: base.path + suffix)
            guard fm.fileExists(atPath: url.path) else { continue }
            let backup = URL(fileURLWithPath: base.path + ".bak-\(stamp)" + suffix)
            do {
                try fm.moveItem(at: url, to: backup)
            } catch {
                // Sem conseguir mover, remove — senão o container novo não abre.
                try? fm.removeItem(at: url)
            }
        }
        return try? ModelContainer(for: schema, configurations: [configuration])
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
