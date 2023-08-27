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
        if #available(iOS 17.0, *) {
            return WindowGroup {
                ContentView()
            }
            .modelContainer(for: Chat.self)
        } else {
            // Fallback on earlier versions
            return WindowGroup {
                OldContentView()
            }
        }
    }
}
