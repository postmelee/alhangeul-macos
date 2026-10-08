import SwiftUI

struct FontLibrarySettingsView: View {
    @ObservedObject var model: FontLibrarySettingsModel
    var embedded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("보관한 글꼴").font(embedded ? .headline : .title2.weight(.semibold))
                }
                Spacer()
                if !embedded {
                    Button("새로고침") { Task { await model.prepare() } }.disabled(model.busy)
                }
                Button("글꼴 가져오기…") { model.beginImport() }.disabled(!model.ready || model.busy)
            }
            Text("한글 앱이나 글꼴 폴더에서 복사해 보관합니다. 보관한 복사본은 원본을 삭제해도 남습니다.")
                .font(.callout).foregroundStyle(.secondary)
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            if model.preparing { ProgressView("글꼴 보관함 확인 중…") }
            if !model.ready {
                if !model.preparing {
                    Button("다시 시도") { Task { await model.prepare() } }.disabled(model.busy)
                }
                if !embedded { Spacer() }
            } else if model.manifest.entries.isEmpty {
                VStack(spacing: 12) {
                    if !embedded { Image(systemName: "textformat").font(.system(size: 36)).foregroundStyle(.secondary) }
                    Text("아직 보관한 글꼴이 없습니다.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: embedded ? .leading : .center)
            } else if embedded {
                FontSettingsDisclosure {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.manifest.entries, id: \.object.sha256) { entry in
                            entryRow(entry).padding(.vertical, 8)
                            Divider()
                        }
                        Button("보관한 목록 새로고침") { Task { await model.prepare() } }
                            .disabled(model.busy).padding(.top, 8)
                    }.padding(.leading, 22).padding(.trailing, 24)
                } label: {
                    Text("보관한 파일 \(model.manifest.entries.count)개").padding(.vertical, 5)
                }
            } else {
                List(model.manifest.entries, id: \.object.sha256) { entry in
                    entryRow(entry).padding(.vertical, 4)
                }
            }
            Text("지원되는 글꼴은 문서와 상단 글꼴 목록에서 사용할 수 있습니다. PDF·인쇄에 포함할 수 없는 글꼴은 출력 전에 안내합니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(embedded ? 0 : 24)
        .task { await model.prepare() }
        .sheet(isPresented: $model.showingImport, onDismiss: { model.importSheetDidDismiss() }) {
            MacFontImportView(model: model)
        }
    }

    private func entryRow(_ entry: FontLibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.faces.first?.fullName ?? entry.source.originalFilename)
                .lineLimit(2).help(entry.source.originalFilename)
            Text("\(entry.faces.count)개 서체 · \(entry.source.originalFilename)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
    }
}
