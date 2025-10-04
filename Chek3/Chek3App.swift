//
//  Chek3App.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI
import CoreData

@main
struct Chek3App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
