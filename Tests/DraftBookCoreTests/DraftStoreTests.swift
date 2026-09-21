import XCTest
@testable import DraftBookCore

@MainActor
final class DraftStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DraftBookTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func testSealingComposerCreatesNewestDraftAndClearsComposer() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "第一条临时文字"

        let sealed = store.sealComposer(now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(sealed?.content, "第一条临时文字")
        XCTAssertEqual(store.drafts.count, 1)
        XCTAssertEqual(store.composer, "")
    }

    func testEmptyComposerDoesNotCreateDraft() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "  \n\n"

        XCTAssertNil(store.sealComposer())
        XCTAssertTrue(store.drafts.isEmpty)
    }

    func testStoreRestoresComposerAndDraftsFromDisk() {
        var store: DraftStore? = DraftStore(dataDirectory: directory)
        store?.composer = "尚未划定"
        _ = store?.sealComposer(now: Date(timeIntervalSince1970: 200))
        store?.composer = "仍在顶部"
        store?.flush()
        store = nil

        let restored = DraftStore(dataDirectory: directory)

        XCTAssertEqual(restored.composer, "仍在顶部")
        XCTAssertEqual(restored.drafts.map(\.content), ["尚未划定"])
    }

    func testEditingOldDraftDoesNotChangeCreatedOrder() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "旧内容"
        let older = store.sealComposer(now: Date(timeIntervalSince1970: 100))!
        store.composer = "新内容"
        let newer = store.sealComposer(now: Date(timeIntervalSince1970: 200))!

        store.updateContent(
            id: older.id,
            content: "修改后的旧内容",
            now: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(store.orderedDrafts.map(\.id), [newer.id, older.id])
    }

    func testPinnedDraftAppearsBeforeNewerDraft() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "旧内容"
        let older = store.sealComposer(now: Date(timeIntervalSince1970: 100))!
        store.composer = "新内容"
        _ = store.sealComposer(now: Date(timeIntervalSince1970: 200))!

        store.togglePinned(id: older.id)

        XCTAssertEqual(store.orderedDrafts.first?.id, older.id)
    }

    func testEditedDraftIsPersistedAfterFlush() {
        var store: DraftStore? = DraftStore(dataDirectory: directory)
        store?.composer = "最初内容"
        let draft = store?.sealComposer(now: Date(timeIntervalSince1970: 100))

        store?.updateContent(id: draft!.id, content: "多行修改内容\n第二行\n第三行")
        store?.flush()
        store = nil

        let restored = DraftStore(dataDirectory: directory)
        XCTAssertEqual(restored.drafts.first?.content, "多行修改内容\n第二行\n第三行")
    }

    func testMoveToTrashCanBeUndone() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "暂时删除"
        let draft = store.sealComposer()!

        store.moveToTrash(id: draft.id)

        XCTAssertTrue(store.orderedDrafts.isEmpty)
        XCTAssertEqual(store.trashedDrafts.map(\.id), [draft.id])
        XCTAssertTrue(store.canUndoLastDelete)

        store.undoLastDelete()

        XCTAssertEqual(store.orderedDrafts.map(\.id), [draft.id])
        XCTAssertTrue(store.trashedDrafts.isEmpty)
        XCTAssertFalse(store.canUndoLastDelete)
    }

    func testTrashStatePersistsAndCanBePermanentlyDeleted() {
        var store: DraftStore? = DraftStore(dataDirectory: directory)
        store?.composer = "进入回收站"
        let draft = store?.sealComposer()!
        store?.moveToTrash(id: draft!.id)
        store?.flush()
        store = nil

        let restored = DraftStore(dataDirectory: directory)
        XCTAssertEqual(restored.trashedDrafts.map(\.id), [draft!.id])

        restored.deletePermanently(id: draft!.id)
        XCTAssertTrue(restored.drafts.isEmpty)
    }

    func testExportsExcludeTrashAndBackupIncludesSchemaVersion() throws {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "保留内容"
        _ = store.sealComposer(now: Date(timeIntervalSince1970: 100))
        store.composer = "删除内容"
        let deleted = store.sealComposer(now: Date(timeIntervalSince1970: 200))!
        store.moveToTrash(id: deleted.id)

        XCTAssertTrue(store.exportPlainText().contains("保留内容"))
        XCTAssertFalse(store.exportPlainText().contains("删除内容"))

        let object = try JSONSerialization.jsonObject(with: store.fullBackupData()) as? [String: Any]
        XCTAssertEqual(object?["schemaVersion"] as? Int, 4)
    }

    func testFlushCreatesAutomaticBackup() throws {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "需要备份"
        store.flush()

        let backups = try FileManager.default.contentsOfDirectory(
            at: store.backupDirectoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(backups.filter { $0.pathExtension == "json" }.count, 1)
    }

    func testLegacyDraftWithoutStateLoadsAsActive() throws {
        struct LegacyDraft: Codable {
            let id: UUID
            let content: String
            let createdAt: Date
            let updatedAt: Date
            let color: DraftColor
            let markdownEnabled: Bool
            let pinned: Bool
            let lastCopiedAt: Date?
        }

        struct LegacySnapshot: Codable {
            let composer: String
            let drafts: [LegacyDraft]
        }

        let legacy = LegacySnapshot(
            composer: "旧版顶部内容",
            drafts: [
                LegacyDraft(
                    id: UUID(),
                    content: "旧版草稿",
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 100),
                    color: .blue,
                    markdownEnabled: false,
                    pinned: false,
                    lastCopiedAt: nil
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacy)
        try data.write(to: directory.appendingPathComponent("drafts.json"))

        let store = DraftStore(dataDirectory: directory)

        XCTAssertEqual(store.composer, "旧版顶部内容")
        XCTAssertEqual(store.orderedDrafts.first?.content, "旧版草稿")
        XCTAssertEqual(store.orderedDrafts.first?.state, .active)
        XCTAssertEqual(store.orderedDrafts.first?.reviewIntervalDays, 7)
        XCTAssertNotNil(store.orderedDrafts.first?.reviewAt)
    }

    func testNewDraftBecomesDueSevenDaysAfterCreation() {
        let store = DraftStore(dataDirectory: directory)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        store.composer = "七天生命周期"
        let draft = store.sealComposer(now: createdAt)!

        XCTAssertTrue(store.dueDrafts(referenceDate: createdAt.addingTimeInterval(6 * 86_400)).isEmpty)
        XCTAssertEqual(
            store.dueDrafts(referenceDate: createdAt.addingTimeInterval(7 * 86_400 + 1)).map(\.id),
            [draft.id]
        )
    }

    func testConfiguredLifecycleAppliesToNewAndRestoredDrafts() {
        let store = DraftStore(dataDirectory: directory, defaultReviewDays: 30)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        store.composer = "三十天生命周期"
        let draft = store.sealComposer(now: createdAt)!

        XCTAssertEqual(draft.reviewIntervalDays, 30)
        XCTAssertTrue(store.dueDrafts(referenceDate: createdAt.addingTimeInterval(29 * 86_400)).isEmpty)

        store.moveToTrash(id: draft.id, now: createdAt)
        store.restoreFromTrash(id: draft.id, now: createdAt)

        XCTAssertEqual(store.draft(withID: draft.id)?.reviewIntervalDays, 30)
    }

    func testAutomaticBackupCanBeDisabled() throws {
        let store = DraftStore(
            dataDirectory: directory,
            automaticBackupsEnabled: false
        )
        store.composer = "只保存主数据"
        store.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.backupDirectoryURL.path))
    }

    func testReducingBackupRetentionPrunesExistingBackupsImmediately() throws {
        let store = DraftStore(dataDirectory: directory, backupRetentionCount: 14)
        try FileManager.default.createDirectory(
            at: store.backupDirectoryURL,
            withIntermediateDirectories: true
        )

        for index in 0..<10 {
            let file = store.backupDirectoryURL.appendingPathComponent("backup-\(index).json")
            try Data("{}".utf8).write(to: file)
        }

        store.configure(
            defaultReviewDays: 7,
            automaticBackupsEnabled: true,
            backupRetentionCount: 7
        )

        let remaining = try FileManager.default.contentsOfDirectory(
            at: store.backupDirectoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(remaining.count, 7)
    }

    func testRestoringFullBackupPreservesCurrentDataAsSafetyBackup() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DraftBookSource-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let source = DraftStore(dataDirectory: sourceDirectory)
        source.composer = "来自备份的草稿"
        source.flush()
        let backup = try source.fullBackupData()

        let store = DraftStore(dataDirectory: directory)
        store.composer = "恢复前的草稿"
        store.flush()
        try store.restoreFullBackupData(backup, now: Date(timeIntervalSince1970: 2_000))

        XCTAssertEqual(store.composer, "来自备份的草稿")
        let safetyBackup = store.backupDirectoryURL
            .appendingPathComponent("BeforeRestore-19700101-003320.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: safetyBackup.path))
        let safetyData = try Data(contentsOf: safetyBackup)
        XCTAssertTrue(String(decoding: safetyData, as: UTF8.self).contains("恢复前的草稿"))
    }

    func testRestoreRejectsBackupFromNewerSchemaVersion() throws {
        let store = DraftStore(dataDirectory: directory)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: store.fullBackupData()) as? [String: Any]
        )
        object["schemaVersion"] = 999
        let data = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try store.restoreFullBackupData(data)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "这份备份来自更新版本的草稿本（数据版本 999），当前版本无法安全恢复。"
            )
        }
    }

    func testEditingActiveDraftRestartsLifecycle() {
        let store = DraftStore(dataDirectory: directory)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let editedAt = Date(timeIntervalSince1970: 20_000)
        store.composer = "会被修改"
        let draft = store.sealComposer(now: createdAt)!

        store.updateContent(id: draft.id, content: "修改后", now: editedAt)

        XCTAssertTrue(store.dueDrafts(referenceDate: editedAt.addingTimeInterval(6 * 86_400)).isEmpty)
        XCTAssertEqual(
            store.dueDrafts(referenceDate: editedAt.addingTimeInterval(7 * 86_400 + 1)).first?.id,
            draft.id
        )
    }

    func testTagFadeUsesCreationTimeContinuously() {
        let createdAt = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            DraftTiming.tagOpacity(createdAt: createdAt, referenceDate: createdAt),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            DraftTiming.tagOpacity(
                createdAt: createdAt,
                referenceDate: createdAt.addingTimeInterval(3.5 * 86_400)
            ),
            0.72,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            DraftTiming.tagOpacity(
                createdAt: createdAt,
                referenceDate: createdAt.addingTimeInterval(7 * 86_400)
            ),
            0.44,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            DraftTiming.tagSaturation(
                createdAt: createdAt,
                referenceDate: createdAt.addingTimeInterval(14 * 86_400)
            ),
            0.55,
            accuracy: 0.0001
        )
    }

    func testEditingRestartsCleanupWithoutResettingCreationFade() {
        let store = DraftStore(dataDirectory: directory)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let editedAt = createdAt.addingTimeInterval(10 * 86_400)
        store.composer = "一条旧草稿"
        let draft = store.sealComposer(now: createdAt)!

        store.updateContent(id: draft.id, content: "编辑后的旧草稿", now: editedAt)

        let edited = store.draft(withID: draft.id)!
        XCTAssertEqual(edited.createdAt, createdAt)
        XCTAssertEqual(edited.updatedAt, editedAt)
        XCTAssertEqual(
            edited.reviewAt,
            editedAt.addingTimeInterval(7 * 86_400)
        )
        XCTAssertEqual(
            DraftTiming.tagOpacity(createdAt: edited.createdAt, referenceDate: editedAt),
            0.44,
            accuracy: 0.0001
        )
    }

    func testMarkdownToggleDoesNotChangeContentUpdateTime() {
        let store = DraftStore(dataDirectory: directory)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        store.composer = "Markdown 草稿"
        let draft = store.sealComposer(now: createdAt)!

        store.toggleMarkdown(id: draft.id)

        XCTAssertTrue(store.draft(withID: draft.id)?.markdownEnabled == true)
        XCTAssertEqual(store.draft(withID: draft.id)?.updatedAt, createdAt)
        XCTAssertEqual(
            store.draft(withID: draft.id)?.reviewAt,
            createdAt.addingTimeInterval(7 * 86_400)
        )
    }

    func testTimingDescriptionsExplainCleanupCycle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = Date(timeIntervalSince1970: 10 * 86_400 + 12 * 3_600)
        let updatedAt = referenceDate.addingTimeInterval(-6 * 86_400)

        XCTAssertEqual(
            DraftTiming.uneditedDescription(updatedAt: updatedAt, referenceDate: referenceDate),
            "已有 6 天未编辑"
        )
        XCTAssertEqual(
            DraftTiming.cleanupDescription(
                reviewAt: referenceDate.addingTimeInterval(86_400),
                isPinned: false,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            "明天进入清理台"
        )
        XCTAssertEqual(
            DraftTiming.cleanupDescription(
                reviewAt: referenceDate.addingTimeInterval(-1),
                isPinned: false,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            "已进入清理台"
        )
        XCTAssertEqual(
            DraftTiming.cleanupDescription(
                reviewAt: nil,
                isPinned: true,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            "已固定，不进入清理台"
        )
    }

    func testPostponeAndPinRemoveDraftFromCleanup() {
        let store = DraftStore(dataDirectory: directory)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let dueDate = createdAt.addingTimeInterval(8 * 86_400)
        store.composer = "待处理"
        let draft = store.sealComposer(now: createdAt)!
        XCTAssertEqual(store.dueDrafts(referenceDate: dueDate).first?.id, draft.id)

        store.postpone(id: draft.id, days: 7, now: dueDate)
        XCTAssertTrue(store.dueDrafts(referenceDate: dueDate).isEmpty)

        store.togglePinned(id: draft.id, now: dueDate)
        XCTAssertNil(store.draft(withID: draft.id)?.reviewAt)
        XCTAssertTrue(store.dueDrafts(referenceDate: .distantFuture).isEmpty)
    }

    func testArchiveUsesSuggestedTitleAndCanBeRestored() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "这是第一行标题\n这是正文"
        let draft = store.sealComposer()!

        store.archive(id: draft.id, title: "")

        XCTAssertTrue(store.orderedDrafts.isEmpty)
        XCTAssertEqual(store.archivedDrafts.first?.displayTitle, "这是第一行标题")
        XCTAssertNil(store.archivedDrafts.first?.reviewAt)

        store.restoreFromArchive(id: draft.id)

        XCTAssertEqual(store.orderedDrafts.first?.id, draft.id)
        XCTAssertEqual(store.orderedDrafts.first?.reviewIntervalDays, 7)
        XCTAssertNotNil(store.orderedDrafts.first?.reviewAt)
    }

    func testUndoDeleteRestoresArchivedState() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "先存档再误删"
        let draft = store.sealComposer()!
        store.archive(id: draft.id, title: "重要存档")

        store.moveToTrash(id: draft.id)
        store.undoLastDelete()

        XCTAssertEqual(store.archivedDrafts.first?.id, draft.id)
        XCTAssertEqual(store.archivedDrafts.first?.displayTitle, "重要存档")
        XCTAssertTrue(store.trashedDrafts.isEmpty)
    }

    func testRestoreArchivedDraftFromTrashReturnsToArchive() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "归档来源"
        let draft = store.sealComposer()!
        store.archive(id: draft.id, title: "归档名称")
        store.moveToTrash(id: draft.id)

        store.restoreFromTrash(id: draft.id)

        XCTAssertEqual(store.archivedDrafts.first?.id, draft.id)
        XCTAssertEqual(store.archivedDrafts.first?.displayTitle, "归档名称")
        XCTAssertTrue(store.orderedDrafts.isEmpty)
    }

    func testColorFilterCanCombineWithTextSearch() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "蓝色客户草稿"
        let blue = store.sealComposer()!
        store.setColor(id: blue.id, color: .blue)
        store.composer = "黄色客户草稿"
        let yellow = store.sealComposer()!
        store.setColor(id: yellow.id, color: .yellow)

        XCTAssertEqual(
            store.drafts(in: .active, matching: "客户", color: .blue).map(\.id),
            [blue.id]
        )
        XCTAssertEqual(
            store.drafts(in: .active, matching: "客户", color: .yellow).map(\.id),
            [yellow.id]
        )
    }

    func testSamplesCoverStatesAndCanBeRemovedWithoutDeletingRealDrafts() {
        let store = DraftStore(dataDirectory: directory)
        store.composer = "真实草稿"
        let realDraft = store.sealComposer()!
        let now = Date(timeIntervalSince1970: 1_000_000)

        store.installSampleDrafts(now: now)

        XCTAssertTrue(store.hasSampleDrafts)
        XCTAssertEqual(store.dueDrafts(referenceDate: now).filter(\.isSample).count, 1)
        XCTAssertEqual(store.archivedDrafts.filter(\.isSample).count, 1)
        XCTAssertEqual(store.trashedDrafts.filter(\.isSample).count, 1)
        XCTAssertFalse(store.exportPlainText().contains("【示例"))

        store.removeSampleDrafts()

        XCTAssertFalse(store.hasSampleDrafts)
        XCTAssertEqual(store.orderedDrafts.map(\.id), [realDraft.id])
    }
}
