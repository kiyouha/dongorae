//
//  dongoraeApp.swift
//  dongorae
//
//  Created by 김영한 on 3/23/25.
//

import SwiftUI

@main
struct dongoraeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
