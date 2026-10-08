import Foundation

// Coordinator의 출력 resolver다. bytes/path는 받지 않는다.
enum RhwpStudioOutputFontBridgeScript {
    static let resolve = #"""
    const api = window.rhwpStudio?.fonts;
    const connection = window.__alhangeulFontConnection;
    if (typeof api?.resolveOutputRequests !== 'function' || typeof connection?.getOutputContext !== 'function')
      throw Error('Output font adapter unavailable');
    const result = await api.resolveOutputRequests(requests);
    const context = connection.getOutputContext(requests);
    if (!context || result.generation !== api.getState().generation
      || (result.revision !== null && result.revision !== context.revision)) throw Error('Stale output font context');
    const unavailable = new Set(context.unavailable);
    const selections = result.selections.map(row =>
      row.status === 'absent' && unavailable.has(row.key) ? {...row, status:'unavailable'} : row);
    return JSON.stringify({identity:context.identity, revision:context.revision, generation:result.generation, selections});
    """#
}
