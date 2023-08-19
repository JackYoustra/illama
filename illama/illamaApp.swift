//
//  illamaApp.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI
import SwiftData
import Lumos
import CustomDump

extension NSCompositeAttributeDescription {
    @objc
    func mySchemaEqual(other: NSCompositeAttributeDescription) -> Bool {
        return true
//        return self.mySchemaEqual(other: other)
    }
}

let swapOut: () = {
    Lumos.for(NSCompositeAttributeDescription.self)
        .getInstanceMethod(selectorString: "_isSchemaEqual:")!
        .swapImplementation(with:
            Lumos
                .for(NSCompositeAttributeDescription.self)
                .getInstanceMethod(selector: #selector(NSCompositeAttributeDescription.mySchemaEqual(other:)))!
         )
}()

@main
struct illamaApp: App {

    var body: some Scene {
//        let _ = swapOut
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Chat.self, inMemory: true)
    }
}
