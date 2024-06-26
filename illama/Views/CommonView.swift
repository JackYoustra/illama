//
//  CommonView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI
import DeviceKit
import UIOnboarding

let syncInitializationWork: () = {
    if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
    if UserDefaults.standard.value(forKey: AppStorageKey.markdownType.rawValue) == nil {
        // we need to store like in like because of strict coding
        UserDefaults.standard.setValue(Optional.some(MarkdownType.markdownUI).rawValue, forKey: AppStorageKey.markdownType.rawValue)
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

struct CommonView_Preview: PreviewProvider {
    static var previews: some View {
        CommonView()
    }
}

#Preview {
    CommonView()
}
