//
//  SettingsView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI

enum AppStorageKey: String, Codable {
    case settingsPage
    case markdownType
    case selectedChatID
    case showOnboarding
    case modelType
}

struct SettingsView: View {
    @AppStorage(AppStorageKey.settingsPage.rawValue) private var page = SettingsPage.markdown
    @AppStorage(AppStorageKey.markdownType.rawValue) private var markdownSupport: MarkdownType? = MarkdownType.markdownUI
    @AppStorage(AppStorageKey.modelType.rawValue) private var modelType = ModelType.smallLlama
    @State private var text: Result<String, Error>? = nil
    
    enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
        case markdown
        case advanced
        case about
        case icons
        
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
                Text("Icons")
                    .tag(SettingsPage.icons)
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
                Picker("Model Type", selection: $modelType) {
                    ForEach(ModelType.allCases) { type in
                        Text(type.itemTitle)
                            .tag(type)
                    }
                    Form(content: {
                        LabeledContent("Prompt", value: String(JsonInput.input.prompt))
                        Slider(value: .constant(Double(modelType.contextSize)), in: 512.0 ... 4096.0, label: {
                            Text("Context Size")
                        })
                        // Maybe stepper?
                        LabeledContent("Context size", value: String(modelType.contextSize))
                        Toggle("mlock", isOn: .constant(modelType.shouldMlock))
                    }).disabled(true)
                }
            case .about:
                Text("""
Hey! I'm Jack. My main job is working at [nanoflick](https://www.nanoflick.com/), but I wrote this app as a hackathon project and [wrote about it on my blog](https://www.jackyoustra.com/blog/llama-ios). I hope you enjoy it! It'll probably be tended to here and there, especially regarding the embarrasing inability to function on A12 chips and earlier. Before then, I hope you enjoy it!
""")
                Spacer()
                Button("Cool, but can you fling a llama") {
                    // TODO
                }.hidden()
            case .icons:
                AppIconGallery()
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
