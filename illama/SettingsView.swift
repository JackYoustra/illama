//
//  SettingsView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI

enum AppStorageKey: String {
    case settingsPage
    case markdownType
    case selectedChatID
    case showOnboarding
}

struct SettingsView: View {
    @AppStorage(AppStorageKey.settingsPage.rawValue) private var page = SettingsPage.markdown
    @AppStorage(AppStorageKey.markdownType.rawValue) private var markdownSupport: MarkdownType? = MarkdownType.markdownUI
    @State private var text: Result<String, Error>? = nil
    
    enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
        case markdown
        case advanced
        case about
        
        var id: Self {
            self
        }
    }
    
    var body: some View {
        VStack {
            Picker("Settings Page", selection: $page) {
                Text("Markdown")
                    .tag(SettingsPage.markdown)
                Text("Advanced")
                    .tag(SettingsPage.advanced)
                Text("About")
                    .tag(SettingsPage.about)
            }
            switch page {
            case .markdown:
                MarkdownPicker()
                Divider()
                switch text {
                case .success(let text):
                    ScrollView {
                        MarkdownTextDisplay(text: text)
                    }
                        .environment(\.markdownSupport, $markdownSupport)
                case .failure(let failure):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 72.0))
                        Text("Error loading sample")
                            .font(.title)
                        Text(failure.localizedDescription)
                            .font(.caption)
                    }
                case nil:
                    ProgressView()
                }
            case .advanced:
                Text("Caution: Changing these settings could cause your app to crash.")
                Text("🛠️ under construction, modification coming soon 🛠️")
                Form(content: {
                    LabeledContent("Prompt", value: String(JsonInput.input.prompt))
//                    Slider(value: .constant(BundledModel.shared.contextSize), in: 512 ..< 4096, label: {
//                        Text("Context Size")
//                    })
                    // Maybe stepper?
                    LabeledContent("Context size", value: String(BundledModel.shared.contextSize))
                    Toggle("mlock", isOn: .constant(BundledModel.shared.shouldMlock))
                }).disabled(true)
            case .about:
                Text("""
Hey! I'm Jack. My main job is working at [nanoflick](https://www.nanoflick.com/), but I wrote this app as a hackathon project and [wrote about it on my blog](https://www.jackyoustra.com/blog/llama-ios). I hope you enjoy it! It'll probably be tended to here and there, especially regarding the embarrasing inability to function on A12 chips and earlier. Before then, I hope you enjoy it!
""")
                Spacer()
                Button("Cool, but can you fling a llama") {
                    // TODO
                }.hidden()
            }
        }.pickerStyle(.segmented)
        .padding(.horizontal)
        .task {
            let priorText = try? text?.get()
            if priorText == nil {
                do {
                    let contents = try String(contentsOf: Bundle.main.url(forResource: "sample", withExtension: "md")!)
                    text = .success(contents)
                } catch {
                    text = .failure(error)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
