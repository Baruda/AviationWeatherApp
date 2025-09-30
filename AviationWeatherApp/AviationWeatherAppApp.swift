//
//  AviationWeatherAppApp.swift
//  AviationWeatherApp
//
//  Created by Francis Ibok on 30/09/2025.
//

import SwiftUI

@main
struct AviationWeatherAppApp: App {
    let persistence = PersistenceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,persistence.container.viewContext )
        }
    }
}
