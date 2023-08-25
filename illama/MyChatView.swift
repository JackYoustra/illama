//
//  MyChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/25/23.
//

import SwiftUI
import MarkdownUI

enum MarkdownType: CaseIterable, Hashable, Identifiable {
    case system
    case markdownUI
    case docC
    case github
    
    var markdownTheme: MarkdownUI.Theme {
        switch self {
        case .docC: return .docC
        case .github: return .gitHub
        default:
            return .basic
        }
    }
    
    var id: Self {
        self
    }
}

extension Optional where Wrapped == MarkdownType {
    var systemImage: String {
        switch self {
        case .system:
            return "applelogo"
        case .markdownUI:
            return "star"
        case .docC:
            return "doc"
        case .github:
            return "terminal"
        case .none:
            return "textformat"
        }
    }
    
    var name: String {
        switch self {
        case .system:
            return "Apple"
        case .markdownUI:
            return "Enhanced"
        case .docC:
            return "DocC"
        case .github:
            return "GitHub"
        case .none:
            return "None"
        }
    }
}

private struct MarkdownSupport: EnvironmentKey {
    static let defaultValue: Binding<MarkdownType?> = .constant(.markdownUI)
}

extension EnvironmentValues {
    var markdownSupport: Binding<MarkdownType?> {
        get { self[MarkdownSupport.self] }
        set { self[MarkdownSupport.self] = newValue }
    }
}

struct MyChatView: View {
    @Bindable var chat: Chat
    @State private var thing: String = ""
    @State private var markdownSupport: MarkdownType? = .markdownUI

    @Namespace var bottomID
    
    var body: some View {
        VStack {
            if let conversation = chat.conversation {
                ScrollView(.vertical) {
                    ScrollViewReader { proxy in
                        LazyVStack {
                            ForEach(conversation.prior) { completedConversation in
                                CompletedConversationView(chat: completedConversation)
                            }.onChange(of: conversation.current) {
                                proxy.scrollTo(bottomID)
                            }
                            switch conversation.current {
                            case let .complete(exchange), let .progressing(exchange):
                                CompletedConversationView(chat: exchange)
                            case let .unanswered(message):
                                SingleMessageView(message: message, isSender: true)
                            }
                            // scrollable proxy
                            Color.clear.frame(height: 1.0)
                                .id(bottomID)
                        }
                    }
                }
            }
            Spacer()
            TextField("Chat box", text: $thing, prompt: Text("Talk to 🦙"))
                .onSubmit {
                    chat.add(query: thing)
                    thing = ""
                }
                .submitLabel(.send)
        }.toolbar {
            HStack(spacing: .zero) {
                Menu {
                    Picker("Markdown", selection: $markdownSupport) {
                        Label("Apple", systemImage: MarkdownType.system.systemImage)
                            .tag(Optional.some(MarkdownType.system))
                        Label("Enhanced", systemImage: MarkdownType.markdownUI.systemImage)
                            .tag(Optional.some(MarkdownType.markdownUI))
                        Label("DocC", systemImage: MarkdownType.docC.systemImage)
                            .tag(Optional.some(MarkdownType.docC))
                        Label("GitHub", systemImage: MarkdownType.github.systemImage)
                            .tag(Optional.some(MarkdownType.github))
                        Label("None", systemImage: Optional<MarkdownType>.none.systemImage)
                            .tag(Optional<MarkdownType>.none)
                    }
                } label: {
                    Text("🄼↓") + Text(Image(systemName: markdownSupport.systemImage))
                }
            }
        }.environment(\.markdownSupport, $markdownSupport)
    }
}

struct CompletedConversationView: View {
    let chat: CompletedConversation

    var body: some View {
        Group {
            SingleMessageView(message: chat.me, isSender: true)
            SingleMessageView(message: chat.llama, isSender: false)
        }
    }
}

struct SingleMessageView: View {
    @Environment(\.markdownSupport) var markdownSupport
    let message: SingleMessage
    let isSender: Bool
    
    @Namespace var ns
    
    static let timeFormatter = {
        let formatter = DateFormatter()

        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()
    
    var dateText: String {
        SingleMessageView.timeFormatter.string(from: message.timestamp)
    }
    
    var body: some View {
        HStack {
            if isSender {
                Spacer()
                dateTextView
                textView
            } else {
                textView
                dateTextView
                Spacer()
            }
        }.padding(.horizontal)
    }
    
    var dateTextView: some View {
        Text(dateText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    var textView: some View {
        Group {
            let v = markdownSupport.wrappedValue
            switch v {
            case .markdownUI, .docC, .github:
                Markdown(message.text)
                    .markdownTheme(v?.markdownTheme ?? .basic)
            case .system:
                Text(LocalizedStringKey(message.text))
            case .none:
                Text(message.text)
            }
        }
            .font(.body)
            .padding(8.0)
            .foregroundColor(isSender ? Color.white : Color.primary)
            .background(Color(uiColor: isSender ? .systemCyan : .systemFill), in: RoundedRectangle(cornerSize: CGSize(width: 8.0, height: 8.0)))
    }
}

import LoremSwiftum
import SwiftData

let previewContainer = try! ModelContainer(for: Chat.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

#Preview {
    _ = previewContainer
    return NavigationStack {
        MyChatView(chat:
                    Chat(
                        timestamp: .now,
                        messages:
                            (0..<4)
                            .map {
                                SingleMessage(text: Lorem.words(($0 + 1) * 4), timestamp: .now.advanced(by: TimeInterval($0 * 60)))
                            }
                    )
        ).modelContainer(previewContainer)
    }
}
