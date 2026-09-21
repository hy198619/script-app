import AppKit
import DraftBookCore
import SwiftUI

enum AppPreferenceKeys {
    static let keepWindowOnTop = "keepWindowOnTop"
    static let defaultReviewDays = "defaultReviewDays"
    static let automaticBackupsEnabled = "automaticBackupsEnabled"
    static let backupRetentionCount = "backupRetentionCount"
}

struct SettingsView: View {
    @EnvironmentObject private var store: DraftStore

    @AppStorage(AppPreferenceKeys.keepWindowOnTop) private var keepWindowOnTop = true
    @AppStorage(AppPreferenceKeys.defaultReviewDays) private var defaultReviewDays = 7
    @AppStorage(AppPreferenceKeys.automaticBackupsEnabled) private var automaticBackupsEnabled = true
    @AppStorage(AppPreferenceKeys.backupRetentionCount) private var backupRetentionCount = 14

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            dataSettings
                .tabItem {
                    Label("数据", systemImage: "externaldrive")
                }
        }
        .frame(width: 480, height: 330)
        .onAppear(perform: synchronizeStorePreferences)
        .onChange(of: defaultReviewDays) { _, _ in synchronizeStorePreferences() }
        .onChange(of: automaticBackupsEnabled) { _, _ in synchronizeStorePreferences() }
        .onChange(of: backupRetentionCount) { _, _ in synchronizeStorePreferences() }
    }

    private var generalSettings: some View {
        Form {
            Section("窗口") {
                Toggle("保持草稿本窗口在最上方", isOn: $keepWindowOnTop)
            }

            Section("草稿生命周期") {
                Picker("新草稿默认在多久后进入清理台", selection: $defaultReviewDays) {
                    Text("1 天").tag(1)
                    Text("3 天").tag(3)
                    Text("7 天").tag(7)
                    Text("14 天").tag(14)
                    Text("30 天").tag(30)
                }
                Text("仅影响之后创建或重新恢复的草稿；固定草稿不会进入清理台。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private var dataSettings: some View {
        Form {
            Section("自动备份") {
                Toggle("每天自动备份", isOn: $automaticBackupsEnabled)

                Picker("保留最近", selection: $backupRetentionCount) {
                    Text("7 份").tag(7)
                    Text("14 份").tag(14)
                    Text("30 份").tag(30)
                }
                .disabled(!automaticBackupsEnabled)

                HStack {
                    Button("打开数据文件夹") {
                        ExportController.openDataFolder(for: store)
                    }
                    Button("恢复完整备份…") {
                        ExportController.importFullBackup(into: store)
                    }
                }
            }

            Section("隐私") {
                Text("所有草稿均保存在本机，不会上传服务器。数据文件目前没有加密，不建议用来长期保存密码、私钥或其他高度敏感信息。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func synchronizeStorePreferences() {
        store.configure(
            defaultReviewDays: defaultReviewDays,
            automaticBackupsEnabled: automaticBackupsEnabled,
            backupRetentionCount: backupRetentionCount
        )
    }
}
