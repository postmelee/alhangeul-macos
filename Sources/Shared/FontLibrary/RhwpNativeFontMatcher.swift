import Foundation
import JavaScriptCore

/// 작업마다 별도 JS realm을 사용한다. pinned 공식 matcher는 metadata만 받고 I/O를 하지 않는다.
@MainActor
enum RhwpNativeFontMatcher {
    struct Request: Encodable, Sendable {
        let key: String
        let family: String
        let weight: Int
        let slant: String
    }
    struct Selection: Decodable, Sendable {
        let key: String
        let status: String
        let id: String?
        let postscriptName: String?
        let weight: Int?
        let slant: String?
    }
    enum Failure: Error { case invalid, tooLarge }
    private struct Input: Encodable {
        let identity: String
        let faces: [StudioFontFace]
        let requests: [Request]
    }
    private struct Output: Decodable { let identity: String; let selections: [Selection] }

    static func resolve(snapshot: StudioFontSupplySnapshot, requests: [Request]) throws -> [Selection] {
        guard snapshot.faces.count <= 25_000, requests.count <= 2048 else { throw Failure.tooLarge }
        guard snapshot.faces.allSatisfy(\.validMetadata), Set(requests.map(\.key)).count == requests.count else { throw Failure.invalid }
        let data = try JSONEncoder().encode(Input(identity: snapshot.identity, faces: snapshot.faces, requests: requests))
        guard data.count <= 32 * 1024 * 1024 else { throw Failure.tooLarge }
        guard let context = JSContext() else { throw Failure.invalid }
        // JavaScriptCoreにはDOM AbortControllerがない。metadata provider用のsignalだけを供給する。
        context.evaluateScript("""
        globalThis.AbortController = class {
          constructor() { this.signal = {aborted:false}; }
          abort() { this.signal.aborted = true; }
        };
        """)
        context.evaluateScript(RhwpNativeFontMatcherSource.script)
        guard context.exception == nil, let function = context.objectForKeyedSubscript("resolveNativeFonts"),
              !function.isUndefined else { throw Failure.invalid }
        function.call(withArguments: [String(decoding: data, as: UTF8.self)])
        // 모든 Promise는 metadata만으로 완료된다. JSC의 microtask drain 이후 결과를 읽는다.
        guard context.exception == nil, let result = context.objectForKeyedSubscript("nativeFontResult"),
              result.isString, let json = result.toString(), let output = try? JSONDecoder().decode(Output.self, from: Data(json.utf8)),
              output.identity == snapshot.identity, output.selections.map(\.key) == requests.map(\.key) else { throw Failure.invalid }
        return output.selections
    }
}
