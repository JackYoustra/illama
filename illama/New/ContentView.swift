//
//  ContentView.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI

enum SelectionID: Codable, Hashable {
    case chat(UUID)
    case settings(UUID?)
    
    var uuid: UUID? {
        switch self {
        case .chat(let id):
            return id
        case .settings(let deferredChatID):
            return deferredChatID
        }
    }
    
    var isChat: Bool {
        switch self {
        case .chat:
            return true
        case .settings:
            return false
        }
    }
    
    var isSettings: Bool {
        switch self {
        case .chat:
            return false
        case .settings:
            return true
        }
    }
}

enum Selection: Codable, Hashable, Identifiable {
    case chat(UUID)
    case settings(deferredChatID: UUID?)
    
    var id: SelectionID {
        switch self {
        case .chat(let id):
            return .chat(id)
        case .settings(let deferredChatID):
            return .settings(deferredChatID)
        }
    }
    
    var uuid: UUID? {
        switch self {
        case .chat(let id):
            return id
        case .settings(let deferredChatID):
            return deferredChatID
        }
    }
    
    var isChat: Bool {
        switch self {
        case .chat:
            return true
        case .settings:
            return false
        }
    }
    
    var isSettings: Bool {
        switch self {
        case .chat:
            return false
        case .settings:
            return true
        }
    }
}

struct DataString: Codable {
    let content: String
    let stop: Bool
}

#if swift(>=5.9)

import SwiftData

@available(iOS 17.0, *)
extension Chat: Identifiable {}

@available(iOS 17.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Chat]
    @SceneStorage(AppStorageKey.selectedChatID.rawValue) private var selectedItem: Selection? = nil
    @State private var isStartAConversationVisibleInDetail: Bool = false
    
    var settingsOn: Binding<Bool> {
        Binding {
            selectedItem?.isSettings ?? false
        } set: { newValue in
            if newValue {
                selectedItem = .settings(deferredChatID: selectedItem?.uuid)
            } else {
                if case let .settings(.some(id)) = selectedItem {
                    selectedItem = .chat(id)
                } else {
                    selectedItem = nil
                }
            }
        }
    }
    
    var listSelectedChat: Binding<UUID?> {
        Binding {
            selectedItem?.uuid
        } set: { newValue in
            if let newValue = newValue {
                selectedItem = .chat(newValue)
            } else {
                selectedItem = nil
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            Group {
                if items.isEmpty, !isStartAConversationVisibleInDetail {
                    startAConversationView()
                } else {
                    List(selection: listSelectedChat) {
                        ForEach(items, id: \.id) { item in
                            NavigationMenuItem(item: item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: settingsOn) {
                        Image(systemName: "gear")
                    }
                }
            }
        } detail: {
            if case .some(.settings) = selectedItem {
                SettingsView()
            } else if case let .some(.chat(chatID)) = selectedItem, let item = items.first(where: { $0.id == chatID }) {
                ChatView(chat: item)
            } else {
                startAConversationView()
                    .onAppear {
                        isStartAConversationVisibleInDetail = true
                    }
                    .onDisappear {
                        isStartAConversationVisibleInDetail = false
                    }
            }
        }
    }
    
    private func startAConversationView() -> some View {
        VStack {
            Text("🦙")
                .animation(.spring)
//                .modifier(InfiniteRotation())
            Button("Start a conversation") {
                addItem()
            }
        }
        .font(.system(size: 144.0))
        .minimumScaleFactor(0.1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addItem() {
        withAnimation {
            let newItem = Chat(timestamp: .now)
            modelContext.insert(newItem)
            try! modelContext.save()
            selectedItem = .chat(newItem.id)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
                try! modelContext.save()
            }
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    ContentView()
        .modelContainer(for: Chat.self, inMemory: true)
}

#endif
