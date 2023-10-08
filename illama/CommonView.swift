//
//  CommonView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI
import DeviceKit
import UIOnboarding
import fishhook

// mock llama_file
class FakeFile {
    let rangeInFile: Range<Int>
    let internalFile: UnsafeMutablePointer<FILE>
    let mmapOffsetFromPage: Int
    static let MagicFileno: Int32 = 0xdeadbee
    var mmapAddr: UnsafeMutableRawPointer? = nil

    // we only want to make one of these for now, or else we have to start tracking MagicFileno
    static var hasReferenceBeenTaken = false
    static let shared: FakeFile = FakeFile()
    static let pageSize = Int(Darwin.sysconf(Darwin._SC_PAGESIZE))
    
    var size: Int {
        rangeInFile.count
    }

    private init() {
        let data = NSDataAsset(name: "llama-model")!.data
        // Read .car file into a Data object
        let carURL = Bundle.main.url(forResource: "Assets", withExtension: "car")!
        let offset = carURL.path(percentEncoded: false).withCString { cCarPath in
            data.withUnsafeBytes { key in
                findOffsetInFile(cCarPath, key.baseAddress!, min(data.count, 1024*1024*5))
            }
        }
        self.rangeInFile = (offset ..< (offset + data.count))
        print("Found data at \(self.rangeInFile)")

        // This offset has to be a multiple of the page size (see: https://man7.org/linux/man-pages/man2/mmap.2.html)
        // We don't want to rely on the file being magically aligned,
        // so we'll mmap to the nearest page boundary and then offset
        // every mmap call and fix up every mmap related syscall
        mmapOffsetFromPage = rangeInFile.lowerBound % FakeFile.pageSize

        // perform fopen on the car file
        self.internalFile = OriginalFunctions.fopen(carURL.path, "r")
    }
    
    func ftell() -> size_t {
        let fullFileOffset = OriginalFunctions.ftell(internalFile)
        return fullFileOffset - rangeInFile.lowerBound
    }
    
    func fseek(offset: size_t, whence: Int32) -> Int32 {
        switch whence {
        case SEEK_END:
            // Seeking to the end, only seek to real end
            return OriginalFunctions.fseek(internalFile, rangeInFile.upperBound, SEEK_SET)
        case SEEK_SET:
            // Adjust the seek offset
            let adjustedOffset = offset + rangeInFile.lowerBound
            if adjustedOffset < rangeInFile.lowerBound {
                // return as if fseek failed
                return 1
            } else if adjustedOffset > rangeInFile.upperBound {
                // return as if fseek failed
                return 1
            } else {
                // seek to the adjusted offset
                return OriginalFunctions.fseek(internalFile, adjustedOffset, SEEK_SET)
            }
        case SEEK_CUR:
            // no check for performance reasons
            // Don't have to adjust the offset, it's already adjusted
            return OriginalFunctions.fseek(internalFile, offset, SEEK_CUR)
        default:
            fatalError("invalid whence")
        }
    }

    func fread(_ ptr: UnsafeMutableRawPointer, _ size: size_t, _ nitems: size_t) -> size_t {
        return OriginalFunctions.fread(ptr, size, nitems, internalFile)
    }
    
    func mmap(_ addr: UnsafeMutableRawPointer?, _ len: size_t, _ prot: Int32, _ flags: Int32, _ fd: Int32, _ offset: off_t) -> UnsafeMutableRawPointer? {
        assert(fd == FakeFile.MagicFileno)
        let actualFd = OriginalFunctions.fileno(internalFile)
        // if they're doing weird stuff, think about it then
        assert(offset == 0)
        assert(mmapAddr == nil)
        let realOffset = rangeInFile.lowerBound
        // align to lowest page size
        let pageAlignmentOffset = (realOffset % FakeFile.pageSize)
        let adjustedOffset = realOffset - pageAlignmentOffset
        guard let returnAddr = OriginalFunctions.mmap(addr, len, prot, flags, actualFd, off_t(adjustedOffset)) else { return nil }
        let fakemmapaddr = returnAddr.advanced(by: pageAlignmentOffset)
        mmapAddr = fakemmapaddr
        return fakemmapaddr
    }

    // madvise
    func madvise(_ addr: UnsafeMutableRawPointer, _ len: size_t, _ advice: Int32) -> Int32 {
        // fix addr
        let adjustedAddr = addr.advanced(by: -mmapOffsetFromPage)
        return OriginalFunctions.madvise(addr, len, advice)
    }

    // munmap
    func munmap(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
        // fix addr
        let adjustedAddr = addr.advanced(by: -mmapOffsetFromPage)
        return OriginalFunctions.munmap(addr, len)
    }

    // mlock
    func mlock(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
        // fix addr
        let adjustedAddr = addr.advanced(by: -mmapOffsetFromPage)
        return OriginalFunctions.mlock(addr, len)
    }

    // munlock
    func munlock(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
        // fix addr
        let adjustedAddr = addr.advanced(by: -mmapOffsetFromPage)
        return OriginalFunctions.munlock(addr, len)
    }

    deinit {
        Darwin.fclose(internalFile)
    }
}

typealias MyOpen = @convention(thin) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> UnsafeMutablePointer<FILE>
func my_open_impl(_ path: UnsafePointer<CChar>, _ mode: UnsafePointer<CChar>) -> UnsafeMutablePointer<FILE> {
    // assert opened for reading
    assert(String(cString: mode) == "r")
    // if the file is the model file, return a fake file
    if String(cString: path) == BundledModel.shared.path {
        // ensure that we only make one of these
        assert(!FakeFile.hasReferenceBeenTaken)
        FakeFile.hasReferenceBeenTaken = true
        return FakeFile.shared.internalFile
    } else {
        return OriginalFunctions.fopen(path, mode)
    }
}

// intercept ftell
typealias MyFtell = @convention(thin) (UnsafeMutablePointer<FILE>) -> size_t
func my_ftell_impl(_ file: UnsafeMutablePointer<FILE>) -> size_t {
    // if the file is the model file, return the offset of the fake file
    let filePtr = UnsafeMutablePointer<FILE>(file)
    if filePtr == FakeFile.shared.internalFile {
        return FakeFile.shared.ftell()
    } else {
        return OriginalFunctions.ftell(file)
    }
}

// intercept fseek
typealias MyFseek = @convention(thin) (UnsafeMutablePointer<FILE>, size_t, Int32) -> Int32
func my_fseek_impl(_ file: UnsafeMutablePointer<FILE>, _ offset: size_t, _ whence: Int32) -> Int32 {
    // if the file is the model file, return the offset of the fake file
    let filePtr = UnsafeMutablePointer<FILE>(file)
    if filePtr == FakeFile.shared.internalFile {
        return FakeFile.shared.fseek(offset: offset, whence: whence)
    } else {
        return OriginalFunctions.fseek(file, offset, whence)
    }
}

// intercept fread
typealias MyFread = @convention(thin) (UnsafeMutableRawPointer, size_t, size_t, UnsafeMutablePointer<FILE>) -> size_t
func my_fread_impl(_ ptr: UnsafeMutableRawPointer, _ size: size_t, _ nitems: size_t, _ stream: UnsafeMutablePointer<FILE>) -> size_t {
    // if the file is the model file, return the offset of the fake file
    if stream == FakeFile.shared.internalFile {
        return FakeFile.shared.fread(ptr, size, nitems)
    } else {
        return OriginalFunctions.fread(ptr, size, nitems, stream)
    }
}

// intercept ferror
typealias MyFerror = @convention(thin) (UnsafeMutablePointer<FILE>) -> Int32
func my_ferror_impl(_ file: UnsafeMutablePointer<FILE>) -> Int32 {
    // if the file is the model file, return OK
    if file == FakeFile.shared.internalFile {
        return 0
    } else {
        return OriginalFunctions.ferror(file)
    }
}

// intercept fileno
typealias MyFileno = @convention(thin) (UnsafeMutablePointer<FILE>) -> Int32
func my_fileno_impl(_ file: UnsafeMutablePointer<FILE>) -> Int32 {
    // if the file is the model file, return OK
    if file == FakeFile.shared.internalFile {
        return FakeFile.MagicFileno
    } else {
        return OriginalFunctions.fileno(file)
    }
}

// intercept mmap
typealias MyMmap = @convention(thin) (UnsafeMutableRawPointer?, size_t, Int32, Int32, Int32, off_t) -> UnsafeMutableRawPointer?
func my_mmap_impl(_ addr: UnsafeMutableRawPointer?, _ len: size_t, _ prot: Int32, _ flags: Int32, _ fd: Int32, _ offset: off_t) -> UnsafeMutableRawPointer? {
    // if the file is the model file, forward mmap, but fix up the fd first
    if fd == FakeFile.MagicFileno {
        print("Was taken")
        return FakeFile.shared.mmap(addr, len, prot, flags, fd, offset)
    } else {
        print("Was not taken")
        // otherwise, return the result of the call to std::mmap
        return OriginalFunctions.mmap(addr, len, prot, flags, fd, offset)
    }
}

// intercept madvise
typealias MyMadvise = @convention(thin) (UnsafeMutableRawPointer, size_t, Int32) -> Int32
func my_madvise_impl(_ addr: UnsafeMutableRawPointer, _ len: size_t, _ advice: Int32) -> Int32 {
    // if the file is the model file, forward madvise, but fix up the addr first
    if let mmapAddr = FakeFile.shared.mmapAddr, addr >= mmapAddr {
        return FakeFile.shared.madvise(addr, len, advice)
    } else {
        // otherwise, return the result of the call to std::madvise
        return OriginalFunctions.madvise(addr, len, advice)
    }
}

// intercept munmap
typealias MyMunmap = @convention(thin) (UnsafeMutableRawPointer, size_t) -> Int32
func my_munmap_impl(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
    // if the file is the model file, forward munmap, but fix up the addr first
    if let mmapAddr = FakeFile.shared.mmapAddr, addr >= mmapAddr {
        return FakeFile.shared.munmap(addr, len)
    } else {
        return OriginalFunctions.munmap(addr, len)
    }
}

// intercept mlock
typealias MyMlock = @convention(thin) (UnsafeMutableRawPointer, size_t) -> Int32
func my_mlock_impl(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
    // if the file is the model file, forward mlock, but fix up the addr first
    if let mmapAddr = FakeFile.shared.mmapAddr, addr >= mmapAddr {
        return FakeFile.shared.mlock(addr, len)
    } else {
        return OriginalFunctions.mlock(addr, len)
    }
}

// intercept munlock
typealias MyMunlock = @convention(thin) (UnsafeMutableRawPointer, size_t) -> Int32
func my_munlock_impl(_ addr: UnsafeMutableRawPointer, _ len: size_t) -> Int32 {
    // if the file is the model file, forward munlock, but fix up the addr first
    if let mmapAddr = FakeFile.shared.mmapAddr, addr >= mmapAddr {
        return FakeFile.shared.munlock(addr, len)
    } else {
        return OriginalFunctions.munlock(addr, len)
    }
}

var a: ((UnsafeMutablePointer<FILE>?, Int, Int32) -> Int32)? = nil

enum OriginalFunctions {
    static var fopen: MyOpen {
        unsafeBitCast(interposeKeychain["fopen"]!.original, to: MyOpen.self)
    }

    static var ftell: MyFtell {
        unsafeBitCast(interposeKeychain["ftell"]!.original, to: MyFtell.self)
    }

    static var fseek: MyFseek {
        unsafeBitCast(interposeKeychain["fseek"]!.original, to: MyFseek.self)
    }

    static var fread: MyFread {
        unsafeBitCast(interposeKeychain["fread"]!.original, to: MyFread.self)
    }

    static var ferror: MyFerror {
        unsafeBitCast(interposeKeychain["ferror"]!.original, to: MyFerror.self)
    }

    static var fileno: MyFileno {
        unsafeBitCast(interposeKeychain["fileno"]!.original, to: MyFileno.self)
    }

    static var mmap: MyMmap {
        unsafeBitCast(interposeKeychain["mmap"]!.original, to: MyMmap.self)
    }

    static var madvise: MyMadvise {
        unsafeBitCast(interposeKeychain["madvise"]!.original, to: MyMadvise.self)
    }

    static var munmap: MyMunmap {
        unsafeBitCast(interposeKeychain["munmap"]!.original, to: MyMunmap.self)
    }

    static var mlock: MyMlock {
        unsafeBitCast(interposeKeychain["mlock"]!.original, to: MyMlock.self)
    }

    static var munlock: MyMunlock {
        unsafeBitCast(interposeKeychain["munlock"]!.original, to: MyMunlock.self)
    }
}

let interposeKeychain: [String: Interpose] = {
    a = fseek
    DispatchQueue.main.async {
        print(a)
    }
    var stuff = [
        Interpose(symbolName: "fopen", targetFunction: unsafeBitCast(my_open_impl as MyOpen, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "ftell", targetFunction: unsafeBitCast(my_ftell_impl as MyFtell, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fseek", targetFunction: unsafeBitCast(my_fseek_impl as MyFseek, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fread", targetFunction: unsafeBitCast(my_fread_impl as MyFread, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "ferror", targetFunction: unsafeBitCast(my_ferror_impl as MyFerror, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fileno", targetFunction: unsafeBitCast(my_fileno_impl as MyFileno, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "mmap", targetFunction: unsafeBitCast(my_mmap_impl as MyMmap, to: UnsafeMutableRawPointer.self)),
    ]
    interpose(symbols: &stuff)
    return Dictionary(uniqueKeysWithValues: stuff.map { ($0.symbolName, $0) })
}()

struct Interpose {
    let symbolName: String
    let targetFunction: UnsafeMutableRawPointer
    var original: UnsafeMutableRawPointer?
}

func interpose(symbols: inout [Interpose]) {
    if symbols.isEmpty {
        return
    }
    let cStrings = symbols.map { Array($0.symbolName.utf8CString) }
    var replaced: ContiguousArray<UnsafeMutableRawPointer> = ContiguousArray(unsafeUninitializedCapacity: symbols.count, initializingWith: { buffer,initializedCount in initializedCount = symbols.count })
    replaced.withUnsafeMutableBytes { mutableRawBufferPointer in
        var rebindings = [rebinding]()
        for (i, elem) in symbols.enumerated() {
            if elem.symbolName.isEmpty {
                continue
            }
            let asp = UnsafePointer(cStrings[i])
            let chosen: UnsafeMutableRawPointer = mutableRawBufferPointer.baseAddress!.advanced(by: MemoryLayout<UnsafeMutableRawPointer>.stride * i)
            rebindings.append(chosen.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: 1) { pointer in
                rebinding(name: asp, replacement: symbols[i].targetFunction, replaced: pointer)
            })
        }
        rebind_symbols(&rebindings, rebindings.count)
    }
    for (i, elem) in symbols.enumerated() {
        if elem.symbolName.isEmpty {
            continue
        }
        symbols[i].original = replaced[i]
    }
}

final class BundledModel {
    static let shared = BundledModel()
    let path: String
    let contextSize: Int
    let shouldMlock: Bool
    let shouldWarn: Bool = false
    
    static let isBigEnoughForBigLlama = ProcessInfo.processInfo.physicalMemory > UInt64(7.9 * 1024 * 1024 * 1024)

    private init() {
        let p = "illama-intercept://llama-model"
        path = p
        // Mlock if have more or equal to 8gb
        shouldMlock = Self.isBigEnoughForBigLlama
        // Context size is 512 for openllama, 2048 for normal (for now)
        if ProcessInfo.processInfo.physicalMemory < UInt64(3.9 * 1024 * 1024 * 1024) {
            contextSize = 512
        } else {
            contextSize = 2048
        }
    }
}

let syncInitializationWork: () = {
    if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
    if UserDefaults.standard.value(forKey: AppStorageKey.markdownType.rawValue) == nil {
        // we need to store like in like because of strict coding
        UserDefaults.standard.setValue(Optional.some(MarkdownType.markdownUI).rawValue, forKey: AppStorageKey.markdownType.rawValue)
    }
}()

let vowels: [Character] = ["a","e","i","o","u"]

struct CommonView: View {
    @State private var showWarning = false
    @State private var hasShownWarning = false
    @State private var showMemoryWarning = false
    @State private var hasShownMemoryWarning = false
    @AppStorage(AppStorageKey.showOnboarding.rawValue) private var showOnboarding: Bool = true
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                OldContentView()
            }
        }.task {
            _ = syncInitializationWork
        }.onAppear {
            #if os(iOS)
            if Device.current.cpu < .a13Bionic, !hasShownWarning {
                // old
                showWarning = true
                hasShownWarning = true
            }
            if BundledModel.shared.shouldWarn {
                showMemoryWarning = true
                hasShownMemoryWarning = true
            }
            #endif
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showWarning) {
            VStack {
                Text("⚠️ Old Phone 🦙☠️")
                    .font(.largeTitle)
                Text("Apple has a bug where I can't write code that makes 🦙 run at bearable speeds on A12-Bionic or older. Your phone has a\(Device.current.cpu.description.first.map(vowels.contains) == true ? "n" : "") \(Device.current.cpu.description), which is older. You can try running this on a newer device. Alternatively, you can try [emailing me](mailto:jack@youstra.com) and I can probably find a way. It's just quite hard and I don't know how many people are going to run into this problem yet, so I'm going to hold off until enough (probably just a few) people email me.")
                Spacer()
                Button("alt-f4 me right now", role: .destructive) {
                    showWarning = false
                    exit(0)
                }
                Button("I want to roll the dice and probably crash") {
                    showWarning = false
                }
                Button("Email the developer, please") {
                    Task {
                        let subject = "Please fix illama's A12 support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        let body = "Hey, I'm writing because I really want to run illama on A12 processors or newer!".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        let pre = "mailto:jack@youstra?subject=\(subject)&body=\(body)"
                        await UIApplication.shared.open(URL(string: pre)!, options: [:])
                    }
                }
            }.buttonStyle(BorderedButtonStyle())
            .padding()
        }
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

struct CommonView_Preview: PreviewProvider {
    static var previews: some View {
        CommonView()
    }
}

#Preview {
    CommonView()
}
