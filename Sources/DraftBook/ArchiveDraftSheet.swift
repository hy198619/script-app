import DraftBookCore
import SwiftUI

struct ArchiveDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title: String

    let draft: Draft
    let onArchive: (String) -> Void

    init(draft: Draft, onArchive: @escaping (String) -> Void) {
        self.draft = draft
        self.onArchive = onArchive
        _title = State(initialValue: draft.displayTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("存档草稿")
                .font(.system(size: 16, weight: .semibold))

            Text("名称只用于以后查找，不会写入正文。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("草稿名称", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            Text(draft.content)
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("存档") {
                    onArchive(title)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            titleFocused = true
        }
    }
}
