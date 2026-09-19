import AppKit
import SwiftUI

struct InstalledFontSettingsView: View {
    @ObservedObject var model: InstalledFontSettingsModel
    @ObservedObject var library: FontLibrarySettingsModel
    @State private var showingLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mac에 설치된 글꼴").font(.title2.weight(.semibold))
            Toggle("Mac에 설치된 글꼴 사용", isOn: Binding(
                get: { model.snapshot?.enabled ?? false },
                set: { value in Task { await model.setEnabled(value) } }
            ))
            .disabled(model.busy || model.snapshot == nil)
            Text("설치된 글꼴을 찾아 사용하도록 설정합니다. 원본을 지우거나 비활성화하면 사용할 수 없습니다.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("현재는 목록 확인과 설정 저장까지 지원합니다. 문서 표시·출력 적용은 준비 중입니다.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("글꼴 목록 새로고침") { Task { await model.refresh() } }
                    .disabled(model.busy)
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                if let snapshot = model.snapshot { Text("\(snapshot.records.count)개 서체").foregroundStyle(.secondary) }
            }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            if let snapshot = model.snapshot {
                if let failure = snapshot.refreshFailure {
                    Text(failure.displayMessage).font(.callout)
                }
                if snapshot.omittedFaceCount > 0 {
                    Text("\(snapshot.omittedFaceCount)개 서체는 정보를 확인하지 못했습니다.").font(.caption)
                }
                if !snapshot.grantIssues.isEmpty {
                    ScrollView {
                        ForEach(snapshot.grantIssues, id: \.id) { issue in
                            HStack {
                                Text("저장된 폴더의 읽기 권한을 다시 확인해 주세요.").font(.caption)
                                Spacer()
                                Button("폴더 다시 선택…") { chooseLocation(replacing: issue.id) }
                                    .disabled(model.busy)
                            }
                        }
                    }.frame(maxHeight: 70)
                }
                if snapshot.records.isEmpty && !model.busy {
                    Text("확인된 설치 글꼴이 없습니다.")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(snapshot.records) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.fullName).lineLimit(2).help(record.fullName)
                            Text("\(record.family) · \(record.style)").font(.caption).foregroundStyle(.secondary)
                            Text((record.failure ?? (record.axes.isEmpty ? nil : InstalledFontFailure.unsupported))?.displayMessage ?? "목록 확인됨 · 사용 시 글꼴 데이터 확인")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
                if snapshot.records.contains(where: { $0.failure == .permissionDenied }) {
                    Button("읽기 권한을 위한 폴더 선택…") { chooseLocation() }.disabled(model.busy)
                }
            } else { Spacer() }
            Divider()
            HStack {
                Text("별도로 복사해 보관한 글꼴은 보관함에서 확인하세요.")
                    .font(.caption).foregroundStyle(.secondary)
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

    private func chooseLocation(replacing id: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "읽기 허용"
        panel.message = "접근할 수 없는 설치 글꼴이 있는 폴더를 선택해 주세요. 읽기 권한을 저장하며 원본은 변경하지 않습니다."
        panel.begin { response in
            let selected = response == .OK ? panel.url : nil
            Task { @MainActor in await model.selectLocation(selected, replacing: id) }
        }
    }
}
