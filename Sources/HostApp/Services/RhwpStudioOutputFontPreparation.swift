import Foundation
import WebKit

@MainActor
final class RhwpStudioOutputFontPreparation {
    private var task: Task<Void, Never>?
    private let fonts: RhwpStudioOutputFontJob?
    init(fonts: RhwpStudioOutputFontJob?) { self.fonts = fonts }
    func cancel() { task?.cancel(); task = nil }

    func prepare(_ view: WKWebView, completion: @escaping @MainActor @Sendable (Result<Any, Error>) -> Void) {
        cancel()
        task = Task { [fonts] in
            do {
                if let fonts {
                    let value = try await view.callAsyncJavaScript(Self.collectionScript,
                        arguments: [:], in: nil, contentWorld: .defaultClient)
                    guard let json = value as? String, let data = json.data(using: .utf8) else {
                        throw RhwpStudioOutputFontError.invalidRequest
                    }
                    let requests = try JSONDecoder().decode([RhwpStudioOutputFontRequest].self, from: data)
                    let nodes = try await fonts.prepare(requests)
                    try Task.checkCancellation()
                    let encoded = try JSONEncoder().encode(nodes)
                    let mappings = try JSONSerialization.jsonObject(with: encoded)
                    _ = try await view.callAsyncJavaScript(Self.applyScript,
                        arguments: ["mappings": mappings], in: nil, contentWorld: .defaultClient)
                }
                try Task.checkCancellation()
                guard let result = try await view.callAsyncJavaScript(RhwpStudioPagePDFHTML.pagePreparationScript,
                    arguments: [:], in: nil, contentWorld: .defaultClient) else {
                    throw RhwpStudioOutputFontError.invalidRequest
                }
                if let fonts { try await fonts.validate() }
                try Task.checkCancellation()
                completion(.success(result))
            } catch { completion(.failure(error)) }
        }
    }

    // computed CSS의 quoting/escape를 처리한다. matcher의 alias/style 선택은 복제하지 않는다.
    nonisolated static let familyParser = #"""
    const splitPDFFamilies = value => {
      const result = []; let current = '', quote = '', escaped = false;
      for (const c of value) {
        if (escaped) { current += c; escaped = false; continue; }
        if (c === '\\') { current += c; escaped = true; continue; }
        if (quote) { current += c; if (c === quote) quote = ''; continue; }
        if (c === '"' || c === "'") { current += c; quote = c; continue; }
        if (c === ',') { result.push(current); current = ''; } else current += c;
      }
      result.push(current);
      return result.map(name => {
        name = name.trim().replace(/^(['"])(.*)\1$/s, '$2');
        return name.replace(/\\([0-9a-fA-F]{1,6})(?:\s)?|\\([^\r\n])/g, (_, hex, escaped) => {
          if (!hex) return escaped;
          const cp = parseInt(hex, 16);
          return String.fromCodePoint(cp > 0 && cp <= 0x10ffff && !(cp >= 0xd800 && cp <= 0xdfff) ? cp : 0xfffd);
        });
      }).filter(Boolean);
    };
    const directPDFText = node => Array.from(node.childNodes).filter(n => n.nodeType === Node.TEXT_NODE)
      .map(n => n.textContent || '').join('');
    """#

    nonisolated static let collectionScript = familyParser + #"""
    const elements = document.querySelectorAll('svg text, svg tspan');
    if (elements.length > 65536) throw Error('PDF text node limit');
    const groups = new Map(), requests = [], refs = new Map();
    const nonce = String(Math.random()).slice(2);
    for (const node of elements) {
      if (!directPDFText(node)) continue;
      const style = getComputedStyle(node);
      const family = splitPDFFamilies(style.fontFamily)[0];
      const weight = Number.parseInt(style.fontWeight, 10);
      const slant = style.fontStyle.startsWith('oblique') ? 'oblique' : style.fontStyle;
      const hasUnsupportedStyle = style.fontStyle !== slant;
      if (!family || !Number.isInteger(weight)) throw Error('Invalid PDF font request');
      const hasStroke = style.stroke !== 'none' && Number.parseFloat(style.strokeWidth) > 0;
      const signature = JSON.stringify([family, weight, slant, hasStroke, hasUnsupportedStyle]);
      if (!groups.has(signature)) {
        if (requests.length >= 2048) throw Error('PDF font request limit');
        const key = nonce + '-' + requests.length;
        groups.set(signature, key); requests.push({key, family, weight, slant, hasStroke, hasUnsupportedStyle}); refs.set(key, []);
      }
      refs.get(groups.get(signature)).push(node);
    }
    // defaultClient world 전용 객체다. SVG data-*나 page world의 같은 이름은 사용하지 않는다.
    globalThis.__alhangeulPDFOutput = {refs, custom: new WeakSet()};
    return JSON.stringify(requests);
    """#

    nonisolated static let applyScript = #"""
    const state = globalThis.__alhangeulPDFOutput;
    if (!state || !Array.isArray(mappings) || mappings.length !== state.refs.size) throw Error('Stale PDF mapping');
    const faces = new Map();
    for (const row of mappings) {
      if (!state.refs.has(row.key)) throw Error('Unknown PDF mapping');
      if (!row.font) continue;
      const f = row.font;
      if (!faces.has(f.alias)) {
        const face = new FontFace(f.alias, `url("${f.url}")`, {weight:String(f.weight), style:f.slant});
        document.fonts.add(face); faces.set(f.alias, face);
      }
    }
    await Promise.all(Array.from(faces.values()).map(face => face.load()));
    if (Array.from(faces.values()).some(face => face.status !== 'loaded')) throw Error('PDF face unavailable');
    for (const row of mappings) {
      if (!row.font) continue;
      for (const node of state.refs.get(row.key)) {
        if (!node.isConnected) throw Error('Detached PDF text');
        node.style.setProperty('font-family', `"${row.font.alias}"`, 'important');
        node.style.setProperty('font-weight', String(row.font.weight), 'important');
        node.style.setProperty('font-style', row.font.slant, 'important');
        node.style.setProperty('font-synthesis', 'none', 'important');
        state.custom.add(node);
      }
    }
    await document.fonts.ready;
    return true;
    """#
}
