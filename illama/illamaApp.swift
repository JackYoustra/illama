//
//  illamaApp.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI
import SwiftData

@main
struct illamaApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Item.self)
    }
}
