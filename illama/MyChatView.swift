//
//  MyChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/25/23.
//

import SwiftUI
import MarkdownUI
import SwiftUIIntrospect

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
            return "sparkles"
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
    @FocusState private var textFocused: Bool
    @ScaledMetric(relativeTo: .body) var textboxSize = 36.0

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
            HStack(spacing: .zero) {
                TextEditor(text: $thing)
                    .focused($textFocused)
                    .frame(minHeight: textboxSize, maxHeight: 250.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .textFieldStyle(.roundedBorder)
                    .introspect(.textEditor, on: .iOS(.v14, .v15, .v16, .v17)) {
                        let textView = $0
                        textView.backgroundColor = .clear
                    }
                    .onSubmit {
                        submit()
                    }
                    .submitLabel(.send)
                    .overlay(alignment: Alignment.leading) {
                        if thing.isEmpty {
                            Text("Talk to 🦙")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 5)
                        }
                    }
                Group {
                    if chat.isAnswering {
                        Circle()
                            .foregroundStyle(.secondary)
                            .overlay {
                                ProgressView()
                                    .tint(Color.white)
                            }
                    } else {
                        Button {
                            submit()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
                .frame(height: textboxSize)
            }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 20).stroke(Color.secondary))
                .gesture(TapGesture().onEnded {
                    textFocused = true
                }, including: textFocused ? .none : .all)
        }.padding(.horizontal)
        .toolbar {
            HStack(spacing: .zero) {
                Menu {
                    Picker("Markdown", selection: $markdownSupport) {
                        ForEach(MarkdownType.allCases.map(Optional.some) + [nil], id: \.self) { type in
                            Label(type.name, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                } label: {
                    Text("🄼↓") + Text(Image(systemName: markdownSupport.systemImage))
                }
            }
        }.environment(\.markdownSupport, $markdownSupport)
    }
    
    func submit() {
        if !chat.isAnswering {
            chat.add(query: thing)
            thing = ""
        }
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
        }
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
        .navigationTitle(Text("My chat with fred"))
    }
}
