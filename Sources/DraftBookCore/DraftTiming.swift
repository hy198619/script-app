import Foundation

public enum DraftTiming {
    public static let fadeDuration: TimeInterval = 7 * 86_400

    public static func creationAgeProgress(
        createdAt: Date,
        referenceDate: Date = Date()
    ) -> Double {
        guard fadeDuration > 0 else { return 1 }
        let age = max(0, referenceDate.timeIntervalSince(createdAt))
        return min(1, age / fadeDuration)
    }

    public static func tagOpacity(
        createdAt: Date,
        referenceDate: Date = Date()
    ) -> Double {
        1 - 0.56 * creationAgeProgress(createdAt: createdAt, referenceDate: referenceDate)
    }

    public static func tagSaturation(
        createdAt: Date,
        referenceDate: Date = Date()
    ) -> Double {
        1 - 0.45 * creationAgeProgress(createdAt: createdAt, referenceDate: referenceDate)
    }

    public static func wholeDaysSinceUpdate(
        updatedAt: Date,
        referenceDate: Date = Date()
    ) -> Int {
        max(0, Int(referenceDate.timeIntervalSince(updatedAt) / 86_400))
    }

    public static func uneditedDescription(
        updatedAt: Date,
        referenceDate: Date = Date()
    ) -> String {
        let days = wholeDaysSinceUpdate(updatedAt: updatedAt, referenceDate: referenceDate)
        return days == 0 ? "今天更新" : "已有 \(days) 天未编辑"
    }

    public static func cleanupDescription(
        reviewAt: Date?,
        isPinned: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if isPinned {
            return "已固定，不进入清理台"
        }
        guard let reviewAt else {
            return "没有清理计划"
        }
        guard reviewAt > referenceDate else {
            return "已进入清理台"
        }

        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: reviewAt)
        let calendarDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        return switch calendarDays {
        case ...0: "今天进入清理台"
        case 1: "明天进入清理台"
        default: "还有 \(calendarDays) 天进入清理台"
        }
    }
}
