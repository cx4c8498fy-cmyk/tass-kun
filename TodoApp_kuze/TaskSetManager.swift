import Foundation

struct TaskTemplate: Codable, Identifiable {
    var id: UUID
    var title: String
    var detail: String
    var priority: TaskPriority

    init(id: UUID = UUID(), title: String, detail: String, priority: TaskPriority) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
    }
}

struct TaskSet: Codable, Identifiable {
    let id: UUID
    var name: String
    var tasks: [TaskTemplate]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, tasks: [TaskTemplate], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tasks = tasks
        self.createdAt = createdAt
    }
}

struct TaskSetManager {
    private let storageKey = "TaskSetsStorage"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadTaskSets() -> [TaskSet] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let sets = try? decoder.decode([TaskSet].self, from: data) else {
            return []
        }
        return sets.sorted { $0.createdAt < $1.createdAt }
    }

    func save(taskSet: TaskSet) {
        var current = loadTaskSets()
        current.append(taskSet)
        persist(current)
    }

    func persist(_ sets: [TaskSet]) {
        if let data = try? encoder.encode(sets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func delete(taskSetID: UUID) {
        var current = loadTaskSets()
        guard let index = current.firstIndex(where: { $0.id == taskSetID }) else { return }
        current.remove(at: index)
        persist(current)
    }

    func instantiateTasks(from taskSet: TaskSet) -> [TaskItem] {
        taskSet.tasks.map {
            TaskItem(
                title: $0.title,
                detail: $0.detail,
                priority: $0.priority,
                createdAt: nil,
                completedAt: nil
            )
        }
    }
}
