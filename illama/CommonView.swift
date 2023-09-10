//
//  CommonView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI
import DeviceKit
import UIOnboarding

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

let syncInitializationWork: () = {
    if UserDefaults.standard.value(forKey: AppStorageKey.markdownType.rawValue) == nil {
        UserDefaults.standard.setValue(MarkdownType.markdownUI.rawValue, forKey: AppStorageKey.markdownType.rawValue)
    }
}()

let vowels: [Character] = ["a","e","i","o","u"]

struct CommonView: View {
    @State private var showWarning = false
    @State private var hasShownWarning = false
    @AppStorage(AppStorageKey.showOnboarding.rawValue) private var showOnboarding: Bool = true
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                OldContentView()
            }
        }.task {
            _ = syncInitializationWork
        }.onAppear {
            #if os(iOS)
            if Device.current.cpu < .a13Bionic, !hasShownWarning {
                // old
                showWarning = true
                hasShownWarning = true
            }
            #endif
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showWarning) {
            VStack {
                Text("⚠️ Old Phone 🦙☠️")
                    .font(.largeTitle)
                Text("Apple has a bug where I can't write code that makes 🦙 run at bearable speeds on A12-Bionic or older. Your phone has a\(Device.current.cpu.description.first.map(vowels.contains) == true ? "n" : "") \(Device.current.cpu.description), which is older. You can try running this on a newer device. Alternatively, you can try [emailing me](mailto:jack@youstra.com) and I can probably find a way. It's just quite hard and I don't know how many people are going to run into this problem yet, so I'm going to hold off until enough (probably just a few) people email me.")
                Spacer()
                Button("alt-f4 me right now", role: .destructive) {
                    showWarning = false
                    exit(0)
                }
                Button("I want to roll the dice and probably crash") {
                    showWarning = false
                }
                Button("Email the developer, please") {
                    Task {
                        let subject = "Please fix illama's A12 support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        let body = "Hey, I'm writing because I really want to run illama on A12 processors or newer!".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        let pre = "mailto:jack@youstra?subject=\(subject)&body=\(body)"
                        await UIApplication.shared.open(URL(string: pre)!, options: [:])
                    }
                }
            }.buttonStyle(BorderedButtonStyle())
            .padding()
        }
    }
}

#Preview {
    CommonView()
}
