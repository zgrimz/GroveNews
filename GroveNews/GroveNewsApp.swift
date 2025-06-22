//
//  GroveNewsApp.swift
//  GroveNews
//
//  Created by Zachary W. Grimshaw on 6/21/25.
//

import SwiftUI

@main
struct GroveNewsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
