//
//  CommonView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI

final class BundledModel {
    static let shared = BundledModel()
    let path: String
    let contextSize: Int
    let shouldMlock: Bool

    private init() {
        let p = [
            "open-llama-3b-q4_0",
            "ggml-model-q3_k_m",
        ].lazy.compactMap {
            Bundle.main.path(forResource: $0, ofType: "bin")
        }.first!
        path = p
        // Mlock if have more or equal to 8gb
        shouldMlock = ProcessInfo.processInfo.physicalMemory > UInt64(7.9 * 1024 * 1024 * 1024)
        // Context size is 512 for openllama, 2048 for normal (for now)
        if p.contains("open") {
            contextSize = 512
        } else {
            contextSize = 2048
        }
    }
}

struct CommonView: View {
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                OldContentView()
            }
        }.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
    }
}

#Preview {
    CommonView()
}
