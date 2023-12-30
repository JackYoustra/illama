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
    
    var memoryRequirement: UInt64 {
        switch self {
        case .smallLlama: return 4 * 1024 * 1024 * 1024
        }
    }
    
    var shouldMlock: Bool {
        switch self {
        case .smallLlama: return false
        }
    }
    
    var spaceRequirement: UInt64 {
        0
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
    
    var bundleTags: [String] {
        assert(chunkCount < 26)
        return (0..<chunkCount).map {
            tagPrefix + String(Character(UnicodeScalar(UInt32(UInt8($0) + ("a" as Character).asciiValue!))!))
        }
    }
}

extension ModelType {
    var target: URL {
        URL.documentsDirectory.appending(path: self.folderName, directoryHint: .isDirectory)
    }
    
    var targetHolder: URL {
        target.appending(path: "combined.bin")
    }
    
    var processingIsDone: Bool {
        if let possibleTargetSize = targetHolder.size(),
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
    var downloading: DownloadingStatus {
        didSet {
            if downloading == .completed {
                // cleanup
                resourceRequest.endAccessingResources()
            }
        }
    }
    
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
        if FileManager.default.fileExists(atPath: type.targetHolder.path()) {
            if type.processingIsDone {
                self.downloading = .completed
            }
        } else {
            self.downloading = .incomplete
        }
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
        let targetSize = type.targetHolder.size() ?? 0
        do {
            for (index, tag) in type.bundleTags.enumerated() {
                let blockSize: UInt64 = 500 * 1024 * 1024
                let currentCursorPosition = UInt64(index) * blockSize
                if targetSize >= UInt64(index + 1) * blockSize {
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
                let targetFile = try FileHandle(forWritingTo: type.targetHolder)
                try targetFile.truncate(atOffset: currentCursorPosition)
                let resourceURL = resourceRequest.bundle.resourceURL!
                let resource = resourceURL.appendingPathComponent(tag)
                let data = try Data(contentsOf: resource)
                targetFile.seek(toFileOffset: currentCursorPosition)
                try targetFile.write(contentsOf: data)
                try targetFile.synchronize()
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
    
    var body: some View {
        WithPerceptionTracking {
            contents
        }
    }
    
    var itemTitle: String {
        switch model.type {
        case .smallLlama:
            return "Small Llama"
        }
    }
    
    var contents: some View {
        HStack(alignment: .center) {
            Button {
                if model.downloading == .completed {
                    // select
                    completedTapped()
                } else {
                    Task {
                        await model.advance()
                    }
                }
            } label: {
                VStack {
                    Text(itemTitle)
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
    }
}
