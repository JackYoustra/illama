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
}

struct SettingsView: View {
    @AppStorage(AppStorageKey.settingsPage.rawValue) private var page = SettingsPage.markdown
    @AppStorage(AppStorageKey.markdownType.rawValue) private var markdownSupport: MarkdownType? = MarkdownType.markdownUI
    @State private var text: Result<String, Error>? = nil
    
    enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
        case markdown
        
        var id: Self {
            self
        }
    }
    
    var body: some View {
        VStack {
            Picker("Settings Page", selection: $page) {
                Text("Markdown")
                    .tag(SettingsPage.markdown)
            }
            switch page {
            case .markdown:
                MarkdownPicker()
                Divider()
                switch text {
                case .success(let text):
                    ScrollView {
                        MarkdownTextDisplay(text: text)
                            .padding(.horizontal)
                    }
                        .environment(\.markdownSupport, $markdownSupport)
                case .failure(let failure):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 72.0))
                        Text("Error")
                            .font(.title)
                        Text(failure.localizedDescription)
                            .font(.caption)
                    }
                case nil:
                    ProgressView()
                }
            }
        }.pickerStyle(.segmented)
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
