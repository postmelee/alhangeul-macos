import SwiftUI

@MainActor
final class AppExecutionAnalyticsSettingsModel: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let runtime: AppExecutionAnalyticsRuntime

    init(runtime: AppExecutionAnalyticsRuntime = .shared) {
        self.runtime = runtime
        isEnabled = runtime.isCollectionEnabled
    }

    func setEnabled(_ isEnabled: Bool) {
        runtime.setCollectionEnabled(isEnabled)
        self.isEnabled = runtime.isCollectionEnabled
    }
}

struct AppExecutionAnalyticsSettingsView: View {
    @ObservedObject var model: AppExecutionAnalyticsSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("개인정보")
                .font(.title2.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(
                        "익명 사용 추이 공유",
                        isOn: Binding(
                            get: { model.isEnabled },
                            set: model.setEnabled
                        )
                    )

                    Text("앱의 최초 실행과 버전 전환 시 발생 날짜, 이전·현재 버전, 확인 가능한 업데이트 경로만 전송합니다.")
                    Text("앱은 문서 내용·파일명·경로, 계정, 기기 또는 사용자 식별자를 전송 데이터에 포함하지 않습니다.")
                    Text("수집 요청은 Cloudflare를 통해 처리되지만 네트워크 정보는 알한글의 분석 저장소에 보관하지 않습니다.")
                    Text("네트워크를 통해 수집 서버에 도달한 익명 이벤트이며 전체 설치 수나 고유 사용자 수를 뜻하지 않습니다.")
                    Text("오프라인 이벤트는 최대 30일 보관되며 최초 전송 시도 후에는 최대 6일 동안 재시도합니다.")
                    Text("끄면 보관 중인 이벤트가 즉시 삭제되고 이후 이벤트 전송이 중단됩니다.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } label: {
                Text("익명 사용 추이")
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
