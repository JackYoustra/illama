//
//  ModelDownloadView.swift
//  iLlama
//
//  Created by Jack Youstra on 12/29/23.
//

import Collections
import SwiftUI
import Perception

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
        if let possibleTargetSize = try? (FileManager.default.attributesOfItem(atPath: targetHolder.path)[.size] as! UInt64),
           possibleTargetSize == self.spaceRequirement {
            return true
        }
        return false
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
                ModelDownloadButton(model: model)
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
    
    /// The following steps are taken for a download:
    /// 1) Download the tag set from ODR: this is all the tags necessary to recreate the full bundle file
    /// 1a) Do data check (reachability), memory check, etc. and necessary warnings
    /// 2) Copy (clone if possible) tag set to persistent memory
    /// 3) Take cloned data and consolidate to one file, removing one at a time
    enum DownloadingStatus: Sendable, Equatable {
        /// Haven't queried or determined yet - unsure what step
        case unknown
        /// Haven't completed ODR download, on step 1
        case incomplete
        /// In-progress for ODR download, performing step 1
        case progressing(Double)
        /// Only resident - need to reconstruct full model via copying, done with step one, step 2 not started
        case residentOnlyPending
        /// Consolidating the data into a file, on step 2
        case consolidating(Double)
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
            case .progressing(let status), .consolidating(let status):
                return status
            default:
                return nil
            }
        }
        
        var working: Bool {
            switch self {
            case .unknown, .progressing, .consolidating:
                return true
            default:
                return false
            }
        }
    }
    
    let resourceRequest: NSBundleResourceRequest
    
    init(_ type: ModelType) {
        self.type = type
        resourceRequest = NSBundleResourceRequest(tags: Set(type.bundleTags))
        if FileManager.default.fileExists(atPath: type.targetHolder.path()) {
            if type.processingIsDone {
                self.downloading = .completed
            } else {
                self.downloading = .residentOnlyPending
            }
        } else {
            // pre-resident
            self.downloading = .unknown
            resourceRequest.conditionallyBeginAccessingResources { [weak self] isResident in
                self?.downloading = isResident ? .residentOnlyPending : .incomplete
            }
        }
    }
    
    func advance() {
        switch downloading {
        case .incomplete:
            self.download()
        case .residentOnlyPending:
            self.consolidate()
        case .failed:
            self.download()
        default:
            fatalError("Can't interact here!")
        }
    }

    private func download() {
        if downloading.isIncomplete {
            downloading = .progressing(0)
            // TODO: make all this async probably
            let cancellation = resourceRequest.progress.publisher(for: \.fractionCompleted, options: .new)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] progress in
                    self?.downloading = .progressing(progress)
                }
            resourceRequest.beginAccessingResources { [weak self] error in
                DispatchQueue.main.async {
                    cancellation.cancel()
                    guard let self else { return }
                    if let error {
                        self.downloading = .failed
                    } else {
                        self.downloading = .residentOnlyPending
                        self.consolidate()
                    }
                }
            }
        }
    }
    
    private func consolidate() {
        if self.downloading == .residentOnlyPending {
            // ensure that we haven't already consolidated!
            
            if type.processingIsDone {
                self.downloading = .completed
                return
            }
            
            self.downloading = .consolidating(0)
            let alreadyProcessedLockfile = LockfileBacked<UInt64>(type.target, preset: 0)
            do {
                if alreadyProcessedLockfile.contents > 0 {
                    // Find what stuff is already APFS-cloned copied
                    let alreadyCopied = try FileManager.default.contentsOfDirectory(at: type.target, includingPropertiesForKeys: [.nameKey]).map(\.lastPathComponent)
                    if alreadyCopied.count < self.type.chunkCount {
                        let resourcesURL = resourceRequest.bundle.resourceURL!
                        let resources = try FileManager.default.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: [.nameKey])
                            .sorted(by: { $0.path() < $1.path() })
                        for file in resources {
                            if !alreadyCopied.contains(file.lastPathComponent) {
                                // Copy, probably going to apfs clone, but no real way to guarantee. Shrug!
                                try FileManager.default.copyItem(at: file, to: type.target.appendingPathComponent(file.lastPathComponent))
                            }
                        }
                    }
                    
                    // release the resources, we have all of them copied and we don't need them anymore
                    resourceRequest.endAccessingResources()
                    
                }
                
                // consolidate files into the biggo omnibus file
                // this is a tricky part! Use files for synchronization
                // at this point, we don't have to think about ODRs any more, we're at step 3
                // don't support resuming - re-copying isn't particularly expensive.
                // Just start alllll over again
                let blockSize: UInt64 = 500 * 1024 * 1024
                let chunks = try FileManager.default.contentsOfDirectory(at: type.target, includingPropertiesForKeys: [.nameKey])
                    .sorted(by: { $0.path() < $1.path() })
                let isAtMultiple = alreadyProcessedLockfile.contents.remainderReportingOverflow(dividingBy: blockSize) == (0, false)
                let done = chunks.isEmpty
                // ensure that either the lockfile is at a multiple of the block size or all done
                assert(isAtMultiple || done)
                if !done {
                    // prep
                    let sizeOfTarget = try FileManager.default.attributesOfItem(atPath: type.targetHolder.path)[.size] as! UInt64
                    let targetFile = try FileHandle(forWritingTo: type.targetHolder)
                    defer { targetFile.closeFile() }
                    if sizeOfTarget != alreadyProcessedLockfile.contents {
                        assert(sizeOfTarget > alreadyProcessedLockfile.contents)
                        // Remove the excess from the file
                        try targetFile.truncate(atOffset: alreadyProcessedLockfile.contents)
                        // continue
                    }
                    
                    // concat files from targetHolder to target
                    for chunk in chunks {
                        try {
                            let chunkSize = try FileManager.default.attributesOfItem(atPath: chunk.path)[.size] as! UInt64
                            let chunkFile = try FileHandle(forReadingFrom: chunk)
                            chunkFile.closeFile()
                            let chunkData = chunkFile.readData(ofLength: Int(chunkSize))
                            targetFile.write(chunkData)
                            try targetFile.synchronize()
                            alreadyProcessedLockfile.contents += chunkSize
                        }()
                        // Remove the chunk
                        try FileManager.default.removeItem(at: chunk)
                    }
                    
                    // Remove the lockfile
                    try FileManager.default.removeItem(at: type.target.appendingPathComponent(".lock"))
                    self.downloading = .completed
                }
            } catch {
                self.downloading = .failed
            }
        }
    }

    var id: ModelType.ID {
        type.id
    }
}

fileprivate var lockfilecount = 0

class LockfileBacked<Content: Codable> {
    private let lockfile: URL
    let jsonEncoder = JSONEncoder()
    var contents: Content {
        didSet {
            writeback()
        }
    }

    init(_ url: URL, preset: Content) {
        if lockfilecount != 0 {
            print("WARNING: MORE THAN ONE LOCKFILE OPEN")
        }
        lockfilecount += 1
        lockfile = url.appendingPathComponent(".lock")
        let jsonDecoder = JSONDecoder()
        contents = (try? jsonDecoder.decode(Content.self, from: Data(contentsOf: lockfile, options: .uncached))) ?? preset
        writeback()
    }
    
    func writeback() {
        try? jsonEncoder.encode(contents).write(to: lockfile, options: .atomic)
    }
    
    deinit {
        lockfilecount -= 1
    }
}

struct ModelDownloadButton: View {
    let model: Models
    
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
                model.advance()
            } label: {
                VStack {
                    Text(itemTitle)
                    Text(String(format: "%0.2f GB", Double(model.type.spaceRequirement) / 1024 * 1024 * 1024))
                        .font(.caption)
                }
            }
            Spacer()
            switch model.downloading {
            case .unknown:
                // act like they've never asked before
                ProgressView()
            case .incomplete:
                Image(systemName: "arrow.down.circle")
            case .progressing(let double):
                ProgressView("Downloading", value: double)
            case .residentOnlyPending:
                Image(systemName: "arrow.down.circle")
            case .consolidating(let double):
                ProgressView("Installing", value: double)
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
