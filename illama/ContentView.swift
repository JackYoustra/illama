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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Chat]
    @State private var thing: String? = nil

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        ChatView(chat: item)
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
            Text(thing ?? "Loading")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Chat.preview
            modelContext.insert(newItem)
            try! modelContext.save()
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

#Preview {
    ContentView()
        .modelContainer(for: Chat.self, inMemory: true)
}
