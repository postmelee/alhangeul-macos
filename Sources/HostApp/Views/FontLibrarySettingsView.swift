import SwiftUI

struct FontLibrarySettingsView: View {
    @ObservedObject var model: FontLibrarySettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("가져온 글꼴").font(.title2.weight(.semibold))
                    Text("별도로 가져온 글꼴의 복사본을 알한글에 보관합니다.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("새로고침") { Task { await model.prepare() } }.disabled(model.busy)
            }
            Text("문서 표시·출력 적용은 준비 중입니다.")
                .font(.callout).foregroundStyle(.secondary)
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            if model.preparing { ProgressView("글꼴 보관함 확인 중…") }
            if !model.ready {
                Spacer()
            } else if model.manifest.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "textformat").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("아직 가져온 글꼴이 없습니다").font(.headline)
                    Text("한글 앱이나 글꼴 폴더에서 한꺼번에 가져올 수 있습니다.")
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.manifest.entries, id: \.object.sha256) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.faces.first?.fullName ?? entry.source.originalFilename)
                        Text("\(entry.faces.count)개 서체 · \(entry.source.originalFilename)")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            HStack {
                Text("원본 파일은 변경하지 않습니다.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("기존 한글 글꼴 가져오기…") { model.beginImport() }
                    .disabled(!model.ready || model.busy)
            }
        }
        .padding(24)
        .task { await model.prepare() }
        .sheet(isPresented: $model.showingImport, onDismiss: { model.dismissImport() }) {
            MacFontImportView(model: model)
        }
    }
}
