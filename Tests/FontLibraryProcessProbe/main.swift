import Darwin
import Foundation

@main
struct FontLibraryProcessProbe {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 3 else { exit(64) }
        let command = args[1]
        let root = URL(fileURLWithPath: args[2], isDirectory: true)
        let phase = args.count > 4 ? FontLibraryWritePhase(rawValue: args[4]) : nil
        let store = FontLibraryStore(rootURL: root, fault: { value in
            if value == phase {
                if args.count > 5 {
                    let gate = args[5]
                    try Data([1]).write(to: URL(fileURLWithPath: gate + ".ready"))
                    while !FileManager.default.fileExists(atPath: gate) { usleep(10_000) }
                } else { _exit(71) }
            }
        })
        do {
            if command == "list" {
                print(try String(decoding: JSONEncoder().encode(await store.list()), as: UTF8.self))
            } else if command == "import", args.count >= 4 {
                let results = await store.importCandidates([.init(sourceURL: URL(fileURLWithPath: args[3]))])
                print(try String(decoding: JSONEncoder().encode(results), as: UTF8.self))
                if results[0].status == .storageFailure { exit(2) }
            } else { exit(64) }
        } catch {
            print("FAIL: \(error)")
            exit(1)
        }
    }
}
