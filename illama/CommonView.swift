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
    let data: Data
    var offset: UInt64 = 0

    init() {
        data = NSDataAsset(name: "llama-model")!.data
    }
    
    func ftell() -> size_t {
        size_t(offset)
    }
    
    func fseek(offset: size_t, whence: Int32) -> size_t {
        switch whence {
        case SEEK_END:
            self.offset = UInt64(data.count) + UInt64(offset)
        case SEEK_SET:
            self.offset = UInt64(offset)
        case SEEK_CUR:
            self.offset += UInt64(offset)
        default:
            fatalError("invalid whence")
        }
        return 0
    }

    func fread(_ ptr: UnsafeMutableRawPointer, _ size: size_t, _ nitems: size_t) -> size_t {
        let count = size * nitems
        let end = Int(offset) + count
        let data = self.data[Int(offset)..<end]
        data.copyBytes(to: ptr.assumingMemoryBound(to: UInt8.self), count: count)
        self.offset += UInt64(count)
        return nitems
    }
}

typealias MyOpen = @convention(thin) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> OpaquePointer
func my_open_impl(_ path: UnsafePointer<CChar>, _ mode: UnsafePointer<CChar>) -> OpaquePointer {
    // assert opened for reading
    assert(String(cString: mode) == "r")
    // if the file is the model file, return a fake file
    if String(cString: path) == BundledModel.shared.path {
        return OpaquePointer(Unmanaged.passRetained(FakeFile()).toOpaque())
    } else {
        // forward the call to std::fopen (is this correct?)
        let result = my_open_impl(path, mode)
        // otherwise, return the result of the call to std::fopen
        return result
    }
}

// intercept ftell
typealias MyFtell = @convention(thin) (OpaquePointer) -> size_t
func my_ftell_impl(_ file: OpaquePointer) -> size_t {
    // if the file is the model file, return the offset of the fake file
    if let file = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(file)).takeUnretainedValue() as? FakeFile {
        return file.ftell()
    } else {
        // otherwise, return the result of the call to std::ftell
        return my_ftell_impl(file)
    }
}

// intercept fseek
typealias MyFseek = @convention(thin) (OpaquePointer, size_t, Int32) -> size_t
func my_fseek_impl(_ file: OpaquePointer, _ offset: size_t, _ whence: Int32) -> size_t {
    // if the file is the model file, return the offset of the fake file
    if let file = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(file)).takeUnretainedValue() as? FakeFile {
        return file.fseek(offset: offset, whence: whence)
    } else {
        // otherwise, return the result of the call to std::fseek
        return my_fseek_impl(file, offset, whence)
    }
}

// intercept fread
typealias MyFread = @convention(thin) (UnsafeMutableRawPointer, size_t, size_t, OpaquePointer) -> size_t
func my_fread_impl(_ ptr: UnsafeMutableRawPointer, _ size: size_t, _ nitems: size_t, _ stream: OpaquePointer) -> size_t {
    // if the file is the model file, return the offset of the fake file
    if let file = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(stream)).takeUnretainedValue() as? FakeFile {
        return file.fread(ptr, size, nitems)
    } else {
        // otherwise, return the result of the call to std::fread
        return my_fread_impl(ptr, size, nitems, stream)
    }
}

// intercept ferror
typealias MyFerror = @convention(thin) (OpaquePointer) -> Int32
func my_ferror_impl(_ file: OpaquePointer) -> Int32 {
    // if the file is the model file, return OK
    if let file = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(file)).takeUnretainedValue() as? FakeFile {
        return 0
    } else {
        // otherwise, return the result of the call to std::ferror
        return my_ferror_impl(file)
    }
}

// intercept fileno
let MagicFileno: Int32 = 0xdeadbee
typealias MyFileno = @convention(thin) (OpaquePointer) -> Int32
func my_fileno_impl(_ file: OpaquePointer) -> Int32 {
    // if the file is the model file, return OK
    if let file = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(file)).takeUnretainedValue() as? FakeFile {
        return MagicFileno
    } else {
        // otherwise, return the result of the call to std::ferror
        return my_fileno_impl(file)
    }
}

// intercept mmap
typealias MyMmap = @convention(thin) (UnsafeMutableRawPointer?, size_t, Int32, Int32, Int32, off_t) -> UnsafeMutableRawPointer?
func my_mmap_impl(_ addr: UnsafeMutableRawPointer?, _ len: size_t, _ prot: Int32, _ flags: Int32, _ fd: Int32, _ offset: off_t) -> UnsafeMutableRawPointer? {
    // if the file is the model file, forward mmap, but fix up the fd first
    if fd == MagicFileno {
        
    } else {
        // otherwise, return the result of the call to std::ferror
        return my_mmap_impl(addr, len, prot, flags, fd, offset)
    }
}

let interposeKeychain = {
    var stuff = [
        Interpose(symbolName: "fopen", targetFunction: unsafeBitCast(my_open_impl as MyOpen, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "ftell", targetFunction: unsafeBitCast(my_ftell_impl as MyFtell, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fseek", targetFunction: unsafeBitCast(my_fseek_impl as MyFseek, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fread", targetFunction: unsafeBitCast(my_fread_impl as MyFread, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "ferror", targetFunction: unsafeBitCast(my_ferror_impl as MyFerror, to: UnsafeMutableRawPointer.self)),
        Interpose(symbolName: "fileno", targetFunction: unsafeBitCast(my_fileno_impl as MyFileno, to: UnsafeMutableRawPointer.self)),
    ]
    interpose(symbols: &stuff)
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
