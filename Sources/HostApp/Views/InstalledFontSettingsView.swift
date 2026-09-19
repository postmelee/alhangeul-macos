import AppKit
import SwiftUI

struct InstalledFontSettingsView: View {
    @ObservedObject var model: InstalledFontSettingsModel
    @ObservedObject var library: FontLibrarySettingsModel
    @State private var showingLibrary = false
    @State private var query = ""
    @State private var showingOptions = false

    private var families: [(name: String, records: [InstalledFontRecord])] {
        let records = model.snapshot?.records ?? []
        return Dictionary(grouping: records, by: { $0.family.isEmpty ? $0.fullName : $0.family })
            .map { (name: $0.key, records: $0.value) }
            .filter { group in
                query.isEmpty || group.records.contains {
                    [$0.family, $0.fullName, $0.style, $0.postScriptName]
                        .contains { $0.localizedCaseInsensitiveContains(query) }
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("글꼴").font(.title2.weight(.semibold))
                    Text("Mac에 설치된 글꼴을 자동으로 찾습니다.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await model.refresh() } } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }.disabled(model.busy).help("새로 설치하거나 변경한 글꼴 목록을 다시 확인합니다.")
            }
            Label("문서에 적용하는 기능은 준비 중입니다.", systemImage: "info.circle")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("글꼴 이름 검색", text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("검색 지우기")
                }
            }.padding(9).background(Color.primary.opacity(0.05)).cornerRadius(7)
            HStack {
                Text(query.isEmpty ? "설치된 글꼴 \(families.count)개" : "검색 결과 \(families.count)개")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            if let message = model.message { Text(message).font(.callout) }
            if let snapshot = model.snapshot {
                if let failure = snapshot.refreshFailure { Text(failure.displayMessage).font(.callout) }
                if snapshot.omittedFaceCount > 0 {
                    Text("일부 글꼴의 정보를 확인하지 못했습니다.").font(.caption).foregroundStyle(.secondary)
                }
                if !snapshot.grantIssues.isEmpty {
                    ScrollView {
                        ForEach(snapshot.grantIssues, id: \.id) { issue in
                            HStack {
                                Text("저장된 폴더의 접근 권한을 확인해 주세요.").font(.caption)
                                Spacer()
                                Button("폴더 다시 선택…") { chooseLocation(replacing: issue.id) }.disabled(model.busy)
                            }
                        }
                    }.frame(maxHeight: 60)
                }
            }
            if families.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "textformat").font(.title).foregroundStyle(.secondary)
                    Text(model.busy ? "글꼴을 찾고 있습니다…" : query.isEmpty ? "확인된 글꼴이 없습니다" : "검색 결과가 없습니다")
                    if !query.isEmpty { Text("다른 이름으로 검색해 보세요.").font(.callout).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(families, id: \.name) { group in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(group.records) { record in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(record.fullName).lineLimit(2).help(record.fullName)
                                                if let failure = limitation(record) {
                                                    Text(failure.displayMessage).font(.caption).foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            if record.failure == .permissionDenied {
                                                Button("접근 허용…") { chooseLocation(for: record) }.disabled(model.busy)
                                            }
                                        }.padding(.vertical, 4)
                                    }
                                }
                                .padding(.leading, 32)
                                .padding(.bottom, 8)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.name).lineLimit(2).help(group.name)
                                        Text(Array(Set(group.records.map(\.style))).sorted().joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    if group.records.contains(where: { limitation($0) != nil }) {
                                        Label("확인 필요", systemImage: "exclamationmark.circle")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 6)
                            }
                            Divider()
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 24)
                }
            }
            DisclosureGroup("사용 설정", isExpanded: $showingOptions) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("문서 연동 시 설치 글꼴 사용", isOn: Binding(
                        get: { model.snapshot?.enabled ?? false },
                        set: { value in Task { await model.setEnabled(value) } }
                    )).disabled(model.busy || model.snapshot == nil)
                    Text("현재는 설정만 저장합니다. 원본을 삭제하거나 비활성화하면 사용할 수 없습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 6)
            }
            Divider()
            HStack {
                Text("별도로 가져온 파일은 보관함에서 관리합니다.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("가져온 글꼴 보관함…") { showingLibrary = true }
            }
        }
        .padding(24)
        .task { await model.prepare() }
        .sheet(isPresented: $showingLibrary) {
            VStack {
                FontLibrarySettingsView(model: library)
                Button("닫기") { showingLibrary = false }.keyboardShortcut(.cancelAction).padding(.bottom)
            }.frame(width: 720, height: 560)
        }
    }

    private func limitation(_ record: InstalledFontRecord) -> InstalledFontFailure? {
        record.failure ?? (record.axes.isEmpty ? nil : .unsupported)
    }

    private func chooseLocation(for record: InstalledFontRecord? = nil, replacing id: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = record?.sourceURL.deletingLastPathComponent()
        panel.prompt = "읽기 허용"
        panel.message = "글꼴이 있는 폴더를 선택해 주세요. 읽기 권한을 저장하며 원본은 변경하지 않습니다."
        panel.begin { response in
            let selected = response == .OK ? panel.url : nil
            Task { @MainActor in await model.selectLocation(selected, replacing: id) }
        }
    }
}
