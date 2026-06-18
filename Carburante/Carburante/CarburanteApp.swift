//
//  CarburanteApp.swift
//  Carburante
//
//  Created by Wagner Rosa on 17/06/26.
//

import SwiftUI
import SwiftData

@main
struct CarburanteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Motorcycle.self,
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
            MotorcycleListView()
        }
        .modelContainer(sharedModelContainer)
    }
}
