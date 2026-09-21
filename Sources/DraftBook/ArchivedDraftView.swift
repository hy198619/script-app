import DraftBookCore
import SwiftUI

struct ArchivedDraftView: View {
    @EnvironmentObject private var store: DraftStore

    let draft: Draft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(draft.color.swiftUIColor.opacity(0.72))
                    .frame(width: 26, height: 8)

                Text(draft.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
            }
            .frame(height: 24)

            Text(draft.content)
                .font(.system(size: 14))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                Button("恢复到草稿") {
                    store.restoreFromArchive(id: draft.id)
                }

                Button("移到回收站", role: .destructive) {
                    store.moveToTrash(id: draft.id)
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 2)
        }
        .padding(.bottom, 16)
    }
}
