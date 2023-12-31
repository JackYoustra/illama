//
//  ModelDownloadView.swift
//  iLlama
//
//  Created by Jack Youstra on 12/29/23.
//

import Collections
import SwiftUI
import Perception
import CombineExt
import Combine

enum ModelType: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case smallLlama
    case mediumLlama
    
    var memoryRequirement: UInt64 {
        switch self {
        case .smallLlama: return 4 * 1024 * 1024 * 1024
        case .mediumLlama: return 8 * 1024 * 1024 * 1024
        }
    }
    
    var shouldMlock: Bool {
        // Only mlock on big for rn
        return ModelType.mediumLlama.memoryRequirementMet
    }
    
    var contextSize: UInt {
        switch self {
        case .smallLlama:
            if ProcessInfo.processInfo.physicalMemory > UInt64(4.1 * 1024 * 1024 * 1024) {
                return 1024
            } else {
                return 512
            }
        case .mediumLlama:
            return 2048
        }
    }
    
    var spaceRequirement: UInt64 {
        // (chunk count  + 1) * chunk size, for intermediate chunk, to be able to install
        (UInt64(chunkCount) + 1) * Self.blockSize
    }
    
    var finalizedSpace: UInt64 {
        switch self {
        case .smallLlama:
            return 1928446208
        case .mediumLlama:
            return 3282248320
        }
    }
    
    var memoryRequirementMet: Bool {
        ProcessInfo.processInfo.physicalMemory >= UInt64(Double(memoryRequirement) * 0.98)
    }
    
    var folderName: String {
        rawValue
    }
    
    var id: String {
        rawValue
    }
    
    var tagPrefix: String {
        "3b_q4_"
    }
    
    var chunkCount: UInt {
        4
    }
    
    static let blockSize: UInt64 = 500 * 1024 * 1024
    
    var bundleTags: [String] {
        assert(chunkCount < 26)
        return (0..<chunkCount).map {
            tagPrefix + String(Character(UnicodeScalar(UInt32(UInt8($0) + ("a" as Character).asciiValue!))!))
        }
    }
    
    var itemTitle: String {
        switch self {
        case .smallLlama:
            return "Small Llama"
        case .mediumLlama:
            return "Medium Llama"
        }
    }
}

extension ModelType {
    var targetFolder: URL {
        URL.documentsDirectory.appending(path: self.folderName, directoryHint: .isDirectory)
    }
    
    var finalizedLocation: URL {
        targetFolder.appending(path: "combined.bin")
    }
    
    var processingIsDone: Bool {
        if let possibleTargetSize = finalizedLocation.size(),
           possibleTargetSize == self.spaceRequirement {
            return true
        }
        return false
    }
}

extension URL {
    func size() -> UInt64? {
        try? (FileManager.default.attributesOfItem(atPath: self.path)[.size] as! UInt64)
    }
}

@Perceptible
class ModelsRegistry {
    var models: OrderedDictionary<ModelType, Models> = OrderedDictionary.init(
        uniqueKeysWithValues: ModelType.allCases.map { model in
            (model, Models(model))
        }
    )
}

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

@Perceptible
class Models: Identifiable {
    let type: ModelType
    var downloading: DownloadingStatus
    
    /// The following steps are taken for a download, one tag at a time
    /// 0) Do data check (reachability), memory check, etc. and necessary warnings
    /// 1) Download the tag from ODR: this is one tag at a time
    /// 2) Copy (clone if possible) tag set to persistent memory
    /// 3) Take cloned data and consolidate to one file, removing one at a time
    /// 4) Repeat for every tag
    enum DownloadingStatus: Sendable, Equatable {
        /// Haven't completed ODR download, on step 1
        case incomplete
        /// In-progress for ODR download, performing step 1-3
        case progressing(Double)
        /// Weren't able to download successfully 😢
        case failed
        /// We completed the download and the model is ready to use 😄
        case completed
        
        var isIncomplete: Bool {
            switch self {
            case .incomplete:
                return true
            default:
                return false
            }
        }
        
        var progression: Double? {
            switch self {
            case .progressing(let status):
                return status
            default:
                return nil
            }
        }
        
        var working: Bool {
            switch self {
            case .progressing:
                return true
            default:
                return false
            }
        }
    }
    
    
    init(_ type: ModelType) {
        self.type = type
        if FileManager.default.fileExists(atPath: type.finalizedLocation.path()) {
            if type.processingIsDone {
                self.downloading = .completed
            }
        }
        self.downloading = .incomplete
    }
    
    func advance() async {
        switch downloading {
        case .incomplete:
            await self.download()
        case .failed:
            await self.download()
        default:
            fatalError("Can't interact here!")
        }
    }

    private func download() async {
        let targetSize = type.finalizedLocation.size() ?? 0
        do {
            for (index, tag) in type.bundleTags.enumerated() {
                let currentCursorPosition = UInt64(index) * ModelType.blockSize
                if targetSize >= UInt64(index + 1) * ModelType.blockSize {
                    // we've already been here
                    continue
                }
                // we haven't been here!
                let resourceRequest = NSBundleResourceRequest(tags: [tag])
                let currentFraction = Double(index) / Double(type.bundleTags.count)
                // TODO: There's a set of common NSBundleResourceRequest errors in the docs
                // handle those
                let cancellation = resourceRequest.progress.publisher(for: \.fractionCompleted, options: .new)
                    .prepend(0.0)
                    .append(1.0)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] progress in
                        self?.downloading = .progressing(progress * currentFraction)
                    }
                try await resourceRequest.beginAccessingResources()
                // now copy over
                let targetFile = try FileHandle(forWritingTo: type.finalizedLocation)
                try targetFile.truncate(atOffset: currentCursorPosition)
                let resourceURL = resourceRequest.bundle.resourceURL!
                let resource = resourceURL.appendingPathComponent(tag)
                let data = try Data(contentsOf: resource)
                targetFile.seek(toFileOffset: currentCursorPosition)
                try targetFile.write(contentsOf: data)
                try targetFile.synchronize()
                let isAtExpectedSize = try targetFile.offset() == type.finalizedSpace
                assert(isAtExpectedSize)
                try targetFile.close()
                resourceRequest.endAccessingResources()
            }
        } catch {
            downloading = .failed
        }
    }

    var id: ModelType.ID {
        type.id
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
