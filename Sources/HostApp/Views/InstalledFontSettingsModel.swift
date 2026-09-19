import Combine
import Foundation

@MainActor
final class InstalledFontSettingsModel: ObservableObject {
    static let shared = InstalledFontSettingsModel()
    @Published private(set) var snapshot: InstalledFontSnapshot?
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private let makeService: @Sendable () async throws -> InstalledFontCatalogService
    private var service: InstalledFontCatalogService?
    private var observation: Task<Void, Never>?

    init(makeService: @escaping @Sendable () async throws -> InstalledFontCatalogService = {
        try await Task.detached { try InstalledFontCatalogService.live() }.value
    }) {
        self.makeService = makeService
    }

    deinit { observation?.cancel() }

    func prepare() async {
        guard !busy, service == nil else { return }
        busy = true
        defer { busy = false }
        do {
            let catalog = try await makeService()
            service = catalog
            let updates = await catalog.updates()
            observation = Task { [weak self] in
                for await value in updates {
                    guard !Task.isCancelled else { break }
                    self?.snapshot = value
                }
            }
            _ = try await catalog.prepare()
            message = nil
        } catch { message = "글꼴 목록을 준비하지 못했습니다. 다시 시도해 주세요." }
    }

    func refresh() async {
        if service == nil { await prepare(); return }
        await perform { catalog in _ = try await catalog.refresh() }
    }

    func setEnabled(_ enabled: Bool) async {
        await perform { catalog in _ = try await catalog.setEnabled(enabled) }
    }

    func selectLocation(_ url: URL?, replacing id: UUID? = nil) async {
        guard let url else { return } // 선택창 취소는 기존 권한과 목록을 보존한다.
        await perform { catalog in _ = try await catalog.grantAccess(to: url, replacing: id) }
    }

    private func perform(_ operation: (InstalledFontCatalogService) async throws -> Void) async {
        guard !busy, let service else { return }
        busy = true
        defer { busy = false }
        do {
            try await operation(service)
            message = nil
        } catch {
            message = "변경을 완료하지 못했습니다. 기존 설정을 확인한 뒤 다시 시도해 주세요."
        }
        // 반환 snapshot을 적용하지 않는다. 단일 updates 스트림 순서로만 화면을 갱신한다.
    }
}

extension InstalledFontFailure {
    var displayMessage: String {
        switch self {
        case .permissionDenied, .stalePermission, .permissionUnresolvable:
            return "읽기 권한 확인 필요"
        case .inactive, .missing: return "현재 설치 상태 확인 필요"
        case .conflict: return "같은 이름의 글꼴이 여러 개 있습니다"
        case .unsupported: return "아직 지원하지 않는 글꼴 형식"
        case .corrupt: return "글꼴 데이터를 확인할 수 없습니다"
        case .tooLarge: return "지원 크기를 초과한 글꼴"
        case .changed, .staleGeneration: return "목록 새로고침 필요"
        case .disabled: return "사용 꺼짐"
        case .notPrepared: return "목록 확인 중"
        case .busy: return "다른 요청 처리 중"
        case .cancelled: return "취소됨"
        case .storage, .incompatibleStorage: return "저장된 설정 확인 필요"
        case .catalogLimit: return "목록이 지원 범위를 초과했습니다"
        }
    }
}
