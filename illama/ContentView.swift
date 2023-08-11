//
//  ContentView.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import SwiftUI
import SwiftData

actor ThingyThing {
    var thing: ()? = nil
    
    static let shared = ThingyThing()
    
    func initialize() async throws {
        if thing != nil {
            thing = try await run_llama()
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var thing: String? = nil

    var body: some View {
        NavigationSplitView {
            Text(thing ?? "Loading")
                .task {
                    try! await ThingyThing.shared.initialize()
                    print("Model loaded")
                    thing = "Model loaded"
                }
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
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
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
