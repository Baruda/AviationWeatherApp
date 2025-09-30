//
//  AviationWeatherAppApp.swift
//  AviationWeatherApp
//
//  Created by Francis Ibok on 30/09/2025.
//

import SwiftUI

@main
struct AviationWeatherAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
