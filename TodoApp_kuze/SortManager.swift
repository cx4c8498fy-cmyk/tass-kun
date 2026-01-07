import Foundation

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:
            return "高"
        case .medium:
            return "中"
        case .low:
            return "低"
        }
    }

    mutating func advance() {
        switch self {
        case .medium:
            self = .high
        case .high:
            self = .low
        case .low:
            self = .medium
        }
    }

    var sortOrder: Int {
        switch self {
        case .high:
            return 0
        case .medium:
            return 1
        case .low:
            return 2
        }
    }
}

enum SortKey: String, CaseIterable, Identifiable, Codable {
    case completion = "未完了優先"
    case priority = "重要度順"
    case createdDate = "作成日時"
    case name = "名前順"
    case none = "なし"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .completion:
            return "未完了を上"
        case .priority:
            return "重要度順"
        case .createdDate:
            return "古い順"
        case .name:
            return "名前順"
        case .none:
            return "なし"
        }
    }
}

struct SortConfiguration: Codable, Equatable {
    var priorities: [SortKey]

    static let `default` = SortConfiguration(priorities: [.completion, .priority, .createdDate, .none])

    private static let storageKey = "SortConfigurationStorage"

    static func load() -> SortConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(SortConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SortConfiguration.storageKey)
        }
    }
}

struct SortManager {
    var configuration: SortConfiguration

    init(configuration: SortConfiguration = SortConfiguration.load()) {
        self.configuration = configuration
    }

    func sort(_ tasks: [TaskItem]) -> [TaskItem] {
        let indexed = tasks.enumerated()
        return indexed.sorted { lhs, rhs in
            for key in configuration.priorities {
                let result = compare(lhs.element, rhs.element, by: key)
                if result != 0 {
                    return result < 0
                }
            }
            return lhs.offset < rhs.offset
        }.map { $0.element }
    }

    private func compare(_ lhs: TaskItem, _ rhs: TaskItem, by key: SortKey) -> Int {
        switch key {
        case .completion:
            if lhs.isCompleted == rhs.isCompleted { return 0 }
            return lhs.isCompleted ? 1 : -1
        case .priority:
            if lhs.priority == rhs.priority { return 0 }
            return lhs.priority.sortOrder < rhs.priority.sortOrder ? -1 : 1
        case .createdDate:
            return compareDates(lhs.createdAt, rhs.createdAt)
        case .name:
            if lhs.title == rhs.title { return 0 }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending ? -1 : 1
        case .none:
            return 0
        }
    }

    private func compareDates(_ lhs: Date?, _ rhs: Date?) -> Int {
        switch (lhs, rhs) {
        case let (l?, r?):
            if l == r { return 0 }
            return l < r ? -1 : 1
        case (nil, nil):
            return 0
        case (nil, _?):
            return 1 // 未設定は後ろ
        case (_?, nil):
            return -1
        }
    }
}
