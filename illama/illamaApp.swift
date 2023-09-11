//
//  illamaApp.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI
#if swift(>=5.9)
import SwiftData
#endif

@main
struct illamaApp: App {

    var body: some Scene {
        if #available(iOS 17.0, *) {
            return WindowGroup {
                CommonView()
            }
#if swift(>=5.9)
            .modelContainer(for: Chat.self)
#endif
        } else {
            // Fallback on earlier versions
            return WindowGroup {
                CommonView()
            }
        }
    }
}
