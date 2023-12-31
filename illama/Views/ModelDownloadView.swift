//
//  ModelDownloadView.swift
//  iLlama
//
//  Created by Jack Youstra on 12/29/23.
//

import SwiftUI
import Perception

struct ModelDownloadView: View {
    @SceneStorage("unsafeMode") var unsafeMode = false
    let registry: ModelsRegistry
    
    var body: some View {
        WithPerceptionTracking {
            contents
        }
    }
    
    var contents: some View {
        VStack {
            Text("We have many different models for you to choose from! Which do you want to check out?")
            ForEach(registry.models.values) { model in
                ModelDownloadButton(model: model) {
                    
                }
            }
            
            VStack {
                Toggle("Unsafe Mode", isOn: $unsafeMode)
                Text("By turning on unsafe mode, you agree that your app will probably crash when running any of the yellow-colored models.")
                    .font(.caption)
            }
        }
    }
}

struct ModelDownloadButton: View {
    let model: Models
    let completedTapped: () -> ()
    @State private var showMemoryWarning = false
    @State private var hasShownMemoryWarning = false
    
    var body: some View {
        WithPerceptionTracking {
            contents
        }
    }
    
    var contents: some View {
        HStack(alignment: .center) {
            Button {
                if !model.type.memoryRequirementMet, !hasShownMemoryWarning {
                    showMemoryWarning = true
                    hasShownMemoryWarning = true
                } else {
                    if model.downloading == .completed {
                        // select
                        completedTapped()
                    } else {
                        Task {
                            await model.advance()
                        }
                    }
                }
            } label: {
                VStack {
                    Text(model.type.itemTitle)
                    Text(String(format: "%0.2f GB", Double(model.type.spaceRequirement) / 1024 * 1024 * 1024))
                        .font(.caption)
                }
            }
            Spacer()
            switch model.downloading {
            case .incomplete:
                Image(systemName: "arrow.down.circle")
            case .progressing(let double):
                ProgressView(value: double)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
            case .completed:
                Image(systemName: "checkmark.circle")
            }
        }
        .background {
            if !model.type.memoryRequirementMet {
                Color.red
            }
        }
        .disabled(model.downloading.working)
        .fullScreenCover(isPresented: $showMemoryWarning) {
            VStack {
                Text("⚠️ Llama too big for Phone 🦙💪💥")
                    .font(.largeTitle)
                Text("Your phone doesn't have enough memory to safely run Big Llama! You can try running it anyway, in which case it will just use the storage as ram, but it's going to be really, really slow. Like, possibly one word per minute slow. I recommend checking out iLlama on the app store, and using that instead of Big Llama.")
                Spacer()
                Button("I'm using my disk as RAM even though it will make the app look like it's frozen. Please don't direct me to iLlama, just let me use Big Llama very very slowly 🐢 and maybe crash anyway") {
                    showMemoryWarning = false
                }
                Button {
                    Task {
                        let pre = "https://apps.apple.com/us/app/iLlama/id6465895152"
                        await UIApplication.shared.open(URL(string: pre)!, options: [:])
                    }
                } label: {
                    Text("Get iLlama")
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .font(.title)
                }.buttonStyle(.borderedProminent)
            }.buttonStyle(BorderedButtonStyle())
            .padding()
        }
    }
}
