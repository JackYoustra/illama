//
//  ContentView.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI
import SwiftData

struct DataString: Codable {
    let content: String
    let stop: Bool
}

@available(iOS 17.0, *)
extension Chat: Identifiable {}

extension UUID: RawRepresentable {
    public init?(rawValue: String) {
        self.init(uuidString: rawValue)
    }
    
    public var rawValue: String {
        uuidString
    }
}

extension Optional: RawRepresentable where Wrapped: RawRepresentable, Wrapped.RawValue == String {
    public init?(rawValue: String) {
        if rawValue.isEmpty {
            self = nil
        } else {
            self = .some(.init(rawValue: rawValue)!)
        }
    }
    
    public var rawValue: String {
        switch self {
        case let .some(wrapped):
            return wrapped.rawValue
        case .none:
            return ""
        }
    }
}

@available(iOS 17.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Chat]
    @AppStorage(AppStorageKey.selectedChatID.rawValue) private var selectedItem: Chat.ID? = nil

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items, id: \.id) { item in
                    NavigationMenuItem(item: item)
                }
                .onDelete(perform: deleteItems)
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
            }
        } detail: {
            VStack {
                Text("🦙")
                Button("Start a conversation") {
                    addItem()
                }
            }
            .font(.system(size: 144.0))
            .minimumScaleFactor(0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Chat(timestamp: .now)
            modelContext.insert(newItem)
            try! modelContext.save()
            selectedItem = newItem.id
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
