import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacFontImportView: View {
    @ObservedObject var model: FontLibrarySettingsModel
    @State private var choosingLocation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기존 한글 글꼴 가져오기").font(.title2.weight(.semibold))
            Text("가져올 위치를 선택하고, 발견된 글꼴을 확인해 주세요.").foregroundStyle(.secondary)
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            switch model.phase {
            case .source: sourceChoices
            case .discovering:
                ProgressView(model.cancelling ? "검색 취소 중…" : "글꼴 찾는 중…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .candidates: candidateList
            case .importing:
                VStack(spacing: 16) {
                    ProgressView()
                    Text(model.cancelling ? "가져오기 취소 중…" : "선택한 \(model.selected.count)개 파일을 가져오는 중…")
                    Text("취소해도 이미 보관된 글꼴은 유지됩니다.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results: resultList
            }
            Divider()
            HStack {
                if model.phase == .candidates || model.phase == .source {
                    Button("한글 앱 또는 글꼴 폴더 선택…", action: chooseLocation)
                        .disabled(choosingLocation)
                }
                Spacer()
                if model.busy {
                    Button(model.cancelling ? "취소 중…" : "취소") { model.cancel() }.disabled(model.cancelling)
                } else {
                    Button(model.phase == .results ? "완료" : "닫기") { model.dismissImport() }
                        .keyboardShortcut(.cancelAction)
                    if model.phase == .candidates {
                        Button("\(model.selected.count)개 가져오기") { model.importSelected() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.selected.isEmpty || choosingLocation)
                    }
                }
            }
        }
        .padding(24).frame(width: 680, height: 500)
        .interactiveDismissDisabled(model.busy || choosingLocation)
        .onDisappear { model.dismissImport() }
    }

    private var sourceChoices: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("이 Mac의 한글").font(.headline)
                    Text("설치된 한글 앱의 문서용 글꼴을 찾습니다. 위치 선택이 필요할 수 있습니다.")
                        .foregroundStyle(.secondary)
                    Button("한글 글꼴 찾기") { model.scanApplications() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mac에 설치한 글꼴").font(.headline)
                    Text("사용자 및 공용 글꼴 폴더를 찾습니다. 한컴 제공 글꼴과는 구분됩니다.")
                        .foregroundStyle(.secondary)
                    Button("Mac 설치 글꼴 찾기") { model.scanInstalled() }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            Spacer()
        }
    }
    private var candidateList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.discovery.notices.isEmpty {
                Text("일부 위치를 읽지 못했거나 검색 범위가 제한됐습니다. 찾는 글꼴이 없다면 앱이나 폴더를 직접 선택해 주세요.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if model.discovery.unsupportedHFTCount > 0 {
                Text("HFT 글꼴 \(model.discovery.unsupportedHFTCount)개는 현재 지원하지 않습니다.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Text("발견한 파일 \(model.discovery.candidates.count)개").font(.headline)
                Spacer()
                Button("전체 선택") { model.selectAll(true) }
                Button("선택 해제") { model.selectAll(false) }
            }
            if model.discovery.candidates.isEmpty {
                Text("가져올 글꼴을 찾지 못했습니다.\n한글 앱이나 글꼴 폴더를 직접 선택해 주세요.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.discovery.sources) { source in
                        Section(header: Text(source.name + (source.version.map { " · \($0)" } ?? ""))) {
                            ForEach(model.discovery.candidates.filter { $0.source.id == source.id }) { candidate in
                                Toggle(isOn: Binding(get: { model.selected.contains(candidate.id) }, set: { model.setSelected(candidate.id, $0) })) {
                                    HStack {
                                        Text(candidate.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(candidate.byteCount), countStyle: .file))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Text("TTF·OTF를 우선 지원합니다. TTC·가변 글꼴은 가져온 뒤 적용 제한을 확인해 주세요.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var resultList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("글꼴 가져오기 결과").font(.headline)
            Text("문서 표시·출력 적용은 준비 중입니다.").foregroundStyle(.secondary)
            List(Array(model.results.enumerated()), id: \.offset) { _, result in
                HStack {
                    Text(model.discovery.candidates.first { $0.id == result.candidateID }?.url.lastPathComponent ?? "글꼴 파일")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(resultLabel(result)).foregroundStyle(.secondary)
                }
            }
            Text("보관됨 \(model.results.filter { $0.status == .added || $0.status == .selectionRequired }.count)개 · 이미 있음 \(model.results.filter { $0.status == .alreadyPresent }.count)개 · 전체 결과 \(model.results.count)개")
                .font(.caption)
        }
    }
    private func resultLabel(_ result: FontImportItemResult) -> String {
        if result.publication == .visibleDurabilityUnconfirmed { return "저장 결과 확인 필요" }
        if result.nextAction == .reviewSupportLimits { return "보관됨 · 적용 제한" }
        switch result.status {
        case .added: return "보관됨"
        case .alreadyPresent: return "이미 있음"
        case .selectionRequired: return "보관됨 · 선택 필요"
        case .unsupported: return "지원하지 않음"
        case .corrupt: return "파일 확인 필요"
        case .readFailure: return "읽기 실패"
        case .storageFailure: return "저장 실패"
        case .cancelled: return "취소됨"
        }
    }
    private func chooseLocation() {
        guard !choosingLocation, !model.busy else { return }
        choosingLocation = true
        let panel = NSOpenPanel()
        panel.title = "한글 앱 또는 글꼴 폴더 선택"
        panel.prompt = "선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.applicationBundle, .folder]
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            choosingLocation = false
            model.selectedLocations(response == .OK ? panel.urls : nil)
        }
    }
}
