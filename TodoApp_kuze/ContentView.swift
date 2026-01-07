//
//  ContentView.swift
//  TodoApp_kuze
//
//  Created by 久世晃暢 on 2025/10/20.
//

import SwiftUI
import GoogleMobileAds

struct TaskItem: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var detail: String
    var priority: TaskPriority
    var isCompleted: Bool
    let createdAt: Date?
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String,
         detail: String,
         priority: TaskPriority = .medium,
         isCompleted: Bool = false,
         createdAt: Date? = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

struct TaskTab: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var tasks: [TaskItem]
    var themeIndex: Int

    init(id: UUID = UUID(), name: String, tasks: [TaskItem] = [], themeIndex: Int = 0) {
        self.id = id
        self.name = name
        self.tasks = tasks
        self.themeIndex = themeIndex
    }

    static let defaultTabs: [TaskTab] = [TaskTab(name: "メイン", themeIndex: 0)]
}

struct ContentView: View {
    @State private var tabs: [TaskTab] = TaskTab.defaultTabs
    @State private var selectedTabID: UUID = TaskTab.defaultTabs.first!.id
    @State private var taskDetailToShow: TaskItem?
    @State private var taskBeingEdited: TaskItem?
    @State private var sortManager = SortManager()
    @State private var taskSetManager = TaskSetManager()
    @State private var isSortSettingsPresented = false
    @State private var isTaskSetReadPresented = false
    @State private var isTaskSetWritePresented = false
    @State private var isTaskAddPresented = false
    @State private var isTabAddSheetPresented = false
    @State private var newTabName: String = ""
    @State private var newTabThemeIndex: Int = 0
    @State private var tabEditName: String = ""
    @State private var tabEditThemeIndex: Int = 0
    @State private var tabBeingEdited: TaskTab?
    @State private var isDeleteTabDialogPresented = false
    @State private var tabPendingDeletion: TaskTab?
    @State private var didLoadPersistedTabs = false
    @StateObject private var interstitialAd = AppInterstitialAd(adUnitID: "ca-app-pub-9158687989284001/2620829799/interstitial")
    private let bannerAdUnitID = "ca-app-pub-9158687989284001/5193461744/banner"
    @State private var showCompletedTasks = true
    @State private var isDeleteCompletedConfirmationPresented = false
    private let tabColorOptions: [TabColorOption] = [
        .init(id: 0, name: "ブルー", color: Color(red: 0.15, green: 0.45, blue: 0.95)),
        .init(id: 1, name: "パープル", color: Color(red: 0.50, green: 0.30, blue: 0.80)),
        .init(id: 2, name: "オレンジ", color: Color(red: 0.94, green: 0.56, blue: 0.18)),
        .init(id: 3, name: "エメラルド", color: Color(red: 0.10, green: 0.70, blue: 0.57)),
        .init(id: 4, name: "ローズ", color: Color(red: 0.86, green: 0.26, blue: 0.40))
    ]

    var body: some View {
        ZStack {
            Color(white: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NavigationView {
                    List {
                        Section {
                            tabBar
                            taskProgressText
                            addTaskButton
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 4, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)

                    taskRows

                    Text("右にスライドで編集　左にスライドで削除")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                    .modifier(ScrollContentBackgroundHidden())
                    .background(Color.clear)
                    .padding(.top, -16)
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarLeading) {
                            Button {
                                isTaskSetReadPresented = true
                            } label: {
                                Label("タスクセット読込", systemImage: "tray.and.arrow.down")
                            }

                            Button {
                                isTaskSetWritePresented = true
                            } label: {
                                Label("タスクセット保存", systemImage: "tray.and.arrow.up")
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            Image("headerLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 44)
                        }
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                isSortSettingsPresented = true
                            } label: {
                                Label("ソート設定", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                sortTasks()
                            } label: {
                                Label("ソート", systemImage: "arrow.up.arrow.down")
                            }
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("閉じる") {
                                dismissKeyboard()
                            }
                        }
                    }
                    .sheet(item: $taskBeingEdited) { task in
                        TaskEditView(task: task) { updatedTask in
                            updateTask(updatedTask)
                            sortTasks()
                        }
                    }
                }
                .background(Color(white: 0.08).ignoresSafeArea())
                .sheet(isPresented: $isSortSettingsPresented) {
                    SortSettingsView(configuration: $sortManager.configuration)
                }
                .sheet(isPresented: $isTaskSetReadPresented) {
                    TaskSetReadView(taskSetManager: taskSetManager) { selectedSet in
                        addTaskSet(selectedSet)
                        isTaskSetReadPresented = false
                    }
                }
                .sheet(isPresented: $isTaskSetWritePresented) {
                    TaskSetWriteView(
                        taskSetManager: taskSetManager,
                        tasks: currentTasks,
                        onDismiss: { isTaskSetWritePresented = false },
                        onSaveCompleted: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                interstitialAd.show(reason: "TaskSetSave")
                            }
                        }
                    )
                }

                BannerAdView(adUnitID: bannerAdUnitID)
                    .frame(height: 50)
                    .background(Color(white: 0.05).ignoresSafeArea())
            }

            if let activeDetail = taskDetailToShow {
                BottomSheetOverlay(onDismiss: dismissTaskDetail) {
                    TaskDetailCard(task: activeDetail, onClose: dismissTaskDetail)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .sheet(isPresented: $isTaskAddPresented) {
            TaskAddView { newTask in
                addTask(newTask)
            }
        }
        .sheet(isPresented: $isTabAddSheetPresented) {
            TabAddSheet(
                name: $newTabName,
                themeIndex: $newTabThemeIndex,
                options: tabColorOptions,
                onCancel: cancelTabAddition,
                onAdd: commitTabAddition
            )
        }
        .sheet(item: $tabBeingEdited) { editingTab in
            TabEditSheet(
                name: $tabEditName,
                themeIndex: $tabEditThemeIndex,
                options: tabColorOptions,
                onCancel: cancelTabEdit,
                onSave: { saveTabEdit(id: editingTab.id) }
            )
        }
        .confirmationDialog("タブを削除", isPresented: $isDeleteTabDialogPresented, presenting: tabPendingDeletion) { tab in
            Button("削除", role: .destructive) {
                deleteTab(tab)
            }
            Button("キャンセル", role: .cancel) {
                tabPendingDeletion = nil
            }
        } message: { tab in
            Text("「\(tab.name)」を削除しますか？このタブのタスクも削除されます。")
        }
        .confirmationDialog("完了済みのタスクを一括で削除しますか？",
                            isPresented: $isDeleteCompletedConfirmationPresented) {
            Button("削除", role: .destructive) {
                deleteCompletedTasks()
            }
            Button("キャンセル", role: .cancel) { }
        }
        .onAppear {
            loadTabsIfNeeded()
            interstitialAd.load()
        }
        .onChange(of: tabs) { _ in
            persistTabsIfPossible()
        }
        .onChange(of: sortManager.configuration) { _ in
            sortManager.configuration.persist()
        }
    }

    private var selectedTabIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabID }
    }

    private var currentTasks: [TaskItem] {
        guard let index = selectedTabIndex else { return [] }
        return tabs[index].tasks
    }

    private var selectedTasksBinding: Binding<[TaskItem]>? {
        guard let index = selectedTabIndex else { return nil }
        return Binding(
            get: { tabs[index].tasks },
            set: { tabs[index].tasks = $0 }
        )
    }

    private func mutateSelectedTabTasks(_ update: (inout [TaskItem]) -> Void) {
        guard let index = selectedTabIndex else { return }
        update(&tabs[index].tasks)
    }

    private func indexPath(for taskID: UUID) -> (tabIndex: Int, taskIndex: Int)? {
        for (tabIndex, tab) in tabs.enumerated() {
            if let taskIndex = tab.tasks.firstIndex(where: { $0.id == taskID }) {
                return (tabIndex, taskIndex)
            }
        }
        return nil
    }

    private func tabAccentColor(for tab: TaskTab) -> Color {
        guard !tabColorOptions.isEmpty else { return .accentColor }
        let index = normalizedThemeIndex(tab.themeIndex)
        return tabColorOptions[index].color
    }

    private func loadTabsIfNeeded() {
        guard !didLoadPersistedTabs else { return }
        if let savedTabs = TabPersistence.load(), !savedTabs.isEmpty {
            tabs = savedTabs
            selectedTabID = savedTabs.first?.id ?? selectedTabID
        } else if tabs.isEmpty {
            tabs = TaskTab.defaultTabs
            selectedTabID = tabs.first?.id ?? selectedTabID
        }
        didLoadPersistedTabs = true
    }

    private func persistTabsIfPossible() {
        guard didLoadPersistedTabs else { return }
        TabPersistence.save(tabs)
    }

    private func normalizedThemeIndex(_ index: Int) -> Int {
        guard !tabColorOptions.isEmpty else { return 0 }
        let count = tabColorOptions.count
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }

    private var canDeleteCurrentTab: Bool {
        tabs.count > 1
    }

    private var canEditCurrentTab: Bool {
        selectedTabIndex != nil
    }

    private func deleteCurrentTab() {
        guard canDeleteCurrentTab, let current = tabs.first(where: { $0.id == selectedTabID }) else { return }
        beginDeleting(current)
    }

    private func updateTask(_ task: TaskItem) {
        if let path = indexPath(for: task.id) {
            tabs[path.tabIndex].tasks[path.taskIndex] = task
        }
    }

    private var currentTab: TaskTab? {
        tabs.first { $0.id == selectedTabID }
    }

    private var currentAccentColor: Color {
        guard let tab = currentTab else { return .accentColor }
        return tabAccentColor(for: tab)
    }

    private var addTaskButton: some View {
        let accent = currentAccentColor
        return Button {
            isTaskAddPresented = true
        } label: {
            Label("タスクを追加", systemImage: "plus")
                .font(.headline)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .foregroundColor(accent)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(accent.opacity(0.7), lineWidth: 1)
                        )
                )
                .shadow(color: accent.opacity(0.25), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var taskProgressText: some View {
        let completed = currentTasks.filter { $0.isCompleted }.count
        let pending = currentTasks.count - completed

        return HStack(spacing: 12) {
            Text("完了済\(completed)/未完了\(pending)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showCompletedTasks.toggle()
                } label: {
                    Text(showCompletedTasks ? "完了非表示" : "完了表示")
                        .font(.caption)
                        .frame(minWidth: 78)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)

                Button {
                    isDeleteCompletedConfirmationPresented = true
                } label: {
                    Text("完了削除")
                        .font(.caption)
                        .frame(minWidth: 78)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var tabBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    beginAddingTab()
                } label: {
                    Label("タブを追加", systemImage: "plus.circle")
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Button {
                    beginEditingCurrentTab()
                } label: {
                    Image(systemName: "pencil.circle")
                        .imageScale(.large)
                        .foregroundColor(canEditCurrentTab ? .orange : .gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(!canEditCurrentTab)

                Button {
                    deleteCurrentTab()
                } label: {
                    Image(systemName: "trash.circle")
                        .imageScale(.large)
                        .foregroundColor(canDeleteCurrentTab ? .red : .gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteCurrentTab)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tabs) { tab in
                        tabChip(for: tab)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal)
        .padding(.top, -8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal)
    }

    private func tabChip(for tab: TaskTab) -> some View {
        let accent = tabAccentColor(for: tab)
        let isActive = selectedTabID == tab.id

        let fillStyle: AnyShapeStyle = {
            if isActive {
                return AnyShapeStyle(
                    LinearGradient(colors: [accent, accent.opacity(0.8)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
            } else {
                return AnyShapeStyle(Color(.systemGray6))
            }
        }()

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                selectedTabID = tab.id
            }
        } label: {
            VStack(spacing: 4) {
                Text(tab.name)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .foregroundColor(isActive ? .white : accent)

                Rectangle()
                    .fill(Color.white.opacity(isActive ? 0.6 : 0.15))
                    .frame(height: 3)
                    .padding(.horizontal, 12)
            }
            .frame(width: 98, height: 52, alignment: .leading)
            .background(
                OneNoteTabShape()
                    .fill(fillStyle)
            )
            .overlay(
                OneNoteTabShape()
                    .stroke(isActive ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: accent.opacity(isActive ? 0.35 : 0.15),
                    radius: isActive ? 10 : 4,
                    x: 0,
                    y: isActive ? 6 : 2)
            .scaleEffect(isActive ? 1.02 : 0.98)
        }
        .buttonStyle(.plain)
    }

    private func beginAddingTab() {
        newTabName = ""
        newTabThemeIndex = nextThemeIndex()
        isTabAddSheetPresented = true
    }

    private func beginEditingCurrentTab() {
        guard let current = tabs.first(where: { $0.id == selectedTabID }) else { return }
        tabEditName = current.name
        tabEditThemeIndex = normalizedThemeIndex(current.themeIndex)
        tabBeingEdited = current
    }

    private func beginDeleting(_ tab: TaskTab) {
        guard tabs.count > 1 else { return }
        tabPendingDeletion = tab
        isDeleteTabDialogPresented = true
    }

    private func cancelTabAddition() {
        newTabName = ""
        isTabAddSheetPresented = false
    }

    private func commitTabAddition() {
        let trimmed = newTabName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        addTab(named: trimmed, themeIndex: newTabThemeIndex)
        cancelTabAddition()
    }

    private func addTab(named name: String, themeIndex: Int? = nil) {
        let resolvedTheme = themeIndex.map(normalizedThemeIndex) ?? nextThemeIndex()
        let newTab = TaskTab(name: name, themeIndex: resolvedTheme)
        tabs.append(newTab)
        selectedTabID = newTab.id
    }

    private func nextThemeIndex() -> Int {
        guard !tabColorOptions.isEmpty else { return 0 }
        return normalizedThemeIndex(tabs.count)
    }

    private func deleteTab(_ tab: TaskTab) {
        defer {
            tabPendingDeletion = nil
        }

        guard let index = tabs.firstIndex(where: { $0.id == tab.id }), tabs.count > 1 else { return }
        tabs.remove(at: index)
        if selectedTabID == tab.id {
            selectedTabID = tabs.first?.id ?? TaskTab.defaultTabs.first!.id
        }
    }

    private func cancelTabEdit() {
        tabBeingEdited = nil
    }

    private func saveTabEdit(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            cancelTabEdit()
            return
        }
        let trimmed = tabEditName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tabs[index].name = trimmed
        tabs[index].themeIndex = normalizedThemeIndex(tabEditThemeIndex)
        cancelTabEdit()
    }

    private var taskRows: some View {
        let accent = currentAccentColor

        return Group {
            if let tasksBinding = selectedTasksBinding {
                ForEach(tasksBinding) { $task in
                    if showCompletedTasks || !task.isCompleted {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accent.opacity(0.08))
                                .shadow(color: accent.opacity(0.12), radius: 4, x: 0, y: 2)

                            HStack(alignment: .center, spacing: 16) {
                                Button {
                                    task.isCompleted.toggle()
                                    if task.isCompleted {
                                        task.completedAt = Date()
                                    } else {
                                        task.completedAt = nil
                                    }
                                } label: {
                                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundColor(task.isCompleted ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                Text(task.title)
                                    .font(.headline)
                                    .strikethrough(task.isCompleted, color: .secondary)
                                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                                Spacer()

                                Button {
                                    task.priority.advance()
                                } label: {
                                    priorityMarkView(for: task.priority)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    taskDetailToShow = task
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(task.detail.isEmpty ? .gray : .primary)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(minHeight: 60)
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTask(task)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                taskBeingEdited = task
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .onMove(perform: moveTask)
            } else {
                Text("タブがありません。")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private func addTask(_ task: TaskItem) {
        mutateSelectedTabTasks { tasks in
            tasks.append(task)
        }
        sortTasks()
    }

    private func deleteTask(_ task: TaskItem) {
        if let path = indexPath(for: task.id) {
            tabs[path.tabIndex].tasks.remove(at: path.taskIndex)
        }
    }

    private func deleteCompletedTasks() {
        mutateSelectedTabTasks { tasks in
            tasks.removeAll { $0.isCompleted }
        }
    }

    private func addTaskSet(_ taskSet: TaskSet) {
        let newTasks = taskSetManager.instantiateTasks(from: taskSet)
        mutateSelectedTabTasks { tasks in
            tasks.append(contentsOf: newTasks)
        }
        sortTasks()
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        mutateSelectedTabTasks { tasks in
            tasks.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func dismissTaskDetail() {
        withAnimation(.easeInOut(duration: 0.2)) {
            taskDetailToShow = nil
        }
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
#endif
    }

    private func sortTasks() {
        mutateSelectedTabTasks { tasks in
            tasks = sortManager.sort(tasks)
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return Color(red: 0.6, green: 0, blue: 0)
        case .medium:
            return .gray
        case .low:
            return .gray.opacity(0.6)
        }
    }

    private func priorityIcon(_ priority: TaskPriority) -> String {
        switch priority {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "circle"
        case .low:
            return "minus.circle.fill"
        }
    }

    @ViewBuilder
    private func priorityMarkView(for priority: TaskPriority) -> some View {
        switch priority {
        case .medium:
            Text("普通")
                .font(.subheadline)
                .foregroundColor(priorityColor(.medium))
        case .high:
            Text("重要")
                .font(.subheadline)
                .foregroundColor(priorityColor(.high))
        case .low:
            Text("保留")
                .font(.subheadline)
                .foregroundColor(priorityColor(.low))
        }
    }

    @ViewBuilder
    private func accentButton(
        title: String,
        systemImage: String,
        filled: Bool,
        expand: Bool,
        minimal: Bool = false,
        showsTitle: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let gradient = LinearGradient(
            colors: [Color.indigo, Color.blue],
            startPoint: .leading,
            endPoint: .trailing
        )

        Button(action: action) {
            accentLabel(title: title, systemImage: systemImage, showsTitle: showsTitle)
                .font(.headline)
                .padding(.vertical, minimal ? 0 : 10)
                .frame(maxWidth: expand ? .infinity : nil)
                .padding(.horizontal, expand ? 0 : (minimal ? 0 : 12))
                .background(
                    Group {
                        if minimal {
                            Color.clear
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(gradient)
                                .opacity(filled ? 1 : 0)
                        }
                    }
                )
                .overlay(
                    Group {
                        if minimal {
                            Color.clear
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(gradient, lineWidth: filled ? 0 : 1.5)
                        }
                    }
                )
                .foregroundColor(minimal ? .primary : (filled ? .white : .primary))
                .shadow(
                    color: minimal ? .clear : (filled ? Color.black.opacity(0.18) : Color.clear),
                    radius: minimal ? 0 : (filled ? 10 : 0),
                    x: 0,
                    y: minimal ? 0 : (filled ? 6 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accentLabel(title: String, systemImage: String, showsTitle: Bool) -> some View {
        if showsTitle {
            Label(title, systemImage: systemImage)
        } else {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
    }
}

struct BottomSheetOverlay<Content: View>: View {
    let onDismiss: () -> Void
    let dismissOnBackgroundTap: Bool
    private let content: Content

    init(onDismiss: @escaping () -> Void,
         dismissOnBackgroundTap: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.onDismiss = onDismiss
        self.dismissOnBackgroundTap = dismissOnBackgroundTap
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard dismissOnBackgroundTap else { return }
                        onDismiss()
                    }

                VStack {
                    Spacer()
                    content
                        .frame(height: proxy.size.height * 0.5)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }
        }
    }
}

struct TaskDetailCard: View {
    let task: TaskItem
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Spacer()
                Button("閉じる") {
                    onClose()
                }
                .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(task.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    DetailDateRow(title: "登録日", value: formattedTaskDate(task.createdAt))
                    DetailDateRow(title: "完了日", value: formattedTaskDate(task.completedAt))
                }

                ScrollView {
                    Text(task.detail.isEmpty ? "詳細は登録されていません。" : task.detail)
                        .font(.body)
                        .foregroundColor(task.detail.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -6)
        )
    }
}

private struct DetailDateRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

private func formattedTaskDate(_ date: Date?) -> String {
    guard let date else { return "-" }
    return TaskDateFormatter.shared.string(from: date)
}

private enum TaskDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd/HH"
        formatter.locale = Locale.current
        formatter.timeZone = .current
        return formatter
    }()
}

struct TaskSetReadView: View {
    let taskSetManager: TaskSetManager
    var onSelect: (TaskSet) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var taskSets: [TaskSet]

    init(taskSetManager: TaskSetManager, onSelect: @escaping (TaskSet) -> Void) {
        self.taskSetManager = taskSetManager
        self.onSelect = onSelect
        _taskSets = State(initialValue: taskSetManager.loadTaskSets())
    }

    var body: some View {
        NavigationView {
            List {
                if taskSets.isEmpty {
                    Text("保存されたタスクセットはありません。")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(taskSets) { set in
                        Button {
                            onSelect(set)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.name)
                                    .font(.headline)
                                Text("\(set.tasks.count) 件・\(formatted(date: set.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(set: set)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: delete(at:))
                }
            }
            .navigationTitle("タスクセット読込")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func delete(set: TaskSet) {
        withAnimation {
            taskSets.removeAll { $0.id == set.id }
            taskSetManager.delete(taskSetID: set.id)
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            taskSets.indices.contains(index) ? taskSets[index].id : nil
        }
        withAnimation {
            taskSets.remove(atOffsets: offsets)
        }
        ids.forEach { taskSetManager.delete(taskSetID: $0) }
    }
}

struct TaskSetWriteView: View {
    let taskSetManager: TaskSetManager
    let tasks: [TaskItem]
    var onDismiss: () -> Void
    var onSaveCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスクセット名")) {
                    TextField("名称を入力", text: $name)
                }

                Section(header: Text("保存されるタスク \(tasks.count) 件")) {
                    if tasks.isEmpty {
                        Text("タスクがありません。")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(tasks) { task in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                if !task.detail.isEmpty {
                                    Text(task.detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("タスクセット保存")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismissView()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTaskSet()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || tasks.isEmpty)
                }
            }
        }
    }

    private func dismissView() {
        dismiss()
        onDismiss()
    }

    private func saveTaskSet() {
        let templates = tasks.map {
            TaskTemplate(
                title: $0.title,
                detail: $0.detail,
                priority: $0.priority
            )
        }
        let taskSet = TaskSet(name: name.trimmingCharacters(in: .whitespacesAndNewlines), tasks: templates)
        taskSetManager.save(taskSet: taskSet)
        onSaveCompleted()
        dismissView()
    }
}

struct SortSettingsView: View {
    @Binding var configuration: SortConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(configuration.priorities.indices, id: \.self) { index in
                        Picker("優先度\(index + 1)", selection: priorityBinding(for: index)) {
                            ForEach(SortKey.allCases) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                    }
                } footer: {
                    Text("優先度1から順に条件を適用します。")
                }
            }
            .navigationTitle("ソート設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func priorityBinding(for index: Int) -> Binding<SortKey> {
        Binding<SortKey>(
            get: { configuration.priorities[index] },
            set: { newValue in
                updatePriority(at: index, with: newValue)
            }
        )
    }

    private func updatePriority(at index: Int, with newValue: SortKey) {
        guard configuration.priorities[index] != newValue else { return }
        if newValue != .none, let existingIndex = configuration.priorities.firstIndex(of: newValue) {
            configuration.priorities[existingIndex] = configuration.priorities[index]
        }
        configuration.priorities[index] = newValue
    }
}

struct TaskAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var detail: String = ""
    @FocusState private var isTitleFocused: Bool

    let onAdd: (TaskItem) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タイトル")) {
                    TextField("タスク名", text: $title)
                        .focused($isTitleFocused)
                }

                Section(header: Text("詳細")) {
                    TextEditor(text: $detail)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("タスクを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await MainActor.run {
                isTitleFocused = true
            }
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newTask = TaskItem(title: trimmed, detail: detail)
        onAdd(newTask)
        dismiss()
    }
}

struct TabAddSheet: View {
    @Binding var name: String
    @Binding var themeIndex: Int
    let options: [TabColorOption]
    let onCancel: () -> Void
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                TabBasicsSection(name: $name, focusBinding: $isNameFocused)
                TabThemeSection(themeIndex: $themeIndex, options: options)
            }
            .navigationTitle("タブを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await MainActor.run {
                isNameFocused = true
            }
        }
    }
}

struct TabEditSheet: View {
    @Binding var name: String
    @Binding var themeIndex: Int
    let options: [TabColorOption]
    let onCancel: () -> Void
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TabBasicsSection(name: $name)
                TabThemeSection(themeIndex: $themeIndex, options: options)
            }
            .navigationTitle("タブを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TabColorOption: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

struct TabPersistence {
    private static let storageKey = "task_tabs_storage"

    static func load() -> [TaskTab]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([TaskTab].self, from: data)
        } catch {
            print("[Persistence] Failed to decode tabs: \(error)")
            return nil
        }
    }

    static func save(_ tabs: [TaskTab]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tabs)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[Persistence] Failed to encode tabs: \(error)")
        }
    }
}

struct ScrollContentBackgroundHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = adUnitID
        view.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
        view.delegate = context.coordinator
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        }
    }
}
#else
struct BannerAdView: View {
    let adUnitID: String

    var body: some View {
        Color.clear.frame(height: 0)
    }
}
#endif

private struct TabBasicsSection: View {
    @Binding var name: String
    var focusBinding: FocusState<Bool>.Binding?

    var body: some View {
        Section(header: Text("タブ名")) {
            if let focusBinding {
                TextField("名前を入力", text: $name)
                    .focused(focusBinding)
            } else {
                TextField("名前を入力", text: $name)
            }
        }
    }
}

private struct TabThemeSection: View {
    @Binding var themeIndex: Int
    let options: [TabColorOption]

    var body: some View {
        Section(header: Text("テーマカラー")) {
            Picker("テーマカラー", selection: $themeIndex) {
                ForEach(options) { option in
                    HStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: 16, height: 16)
                        Text(option.name)
                    }
                    .tag(option.id)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

#if canImport(GoogleMobileAds)
final class AppInterstitialAd: NSObject, ObservableObject, GoogleMobileAds.FullScreenContentDelegate {
    private let adUnitID: String
    private var interstitial: GoogleMobileAds.InterstitialAd?
    @Published private(set) var isReady: Bool = false

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }

    func load() {
        let request = GoogleMobileAds.Request()
        GoogleMobileAds.InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                self?.isReady = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isReady = true
        }
    }

    func show(reason: String) {
        guard let interstitial = interstitial,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
            return
        }
        interstitial.present(from: rootVC)
        isReady = false
    }

    func adDidDismissFullScreenContent(_ ad: GoogleMobileAds.FullScreenPresentingAd) {
        load()
    }

    func ad(_ ad: GoogleMobileAds.FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        load()
    }
}
#else
final class AppInterstitialAd: ObservableObject {
    init(adUnitID: String) {}
    func load() {}
    func show(reason: String) {}
}
#endif

struct OneNoteTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(20, rect.height * 0.6)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var detail: String

    let task: TaskItem
    let onSave: (TaskItem) -> Void

    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _detail = State(initialValue: task.detail)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タイトル")) {
                    TextField("タスク名", text: $title)
                }

                Section(header: Text("詳細")) {
                    TextEditor(text: $detail)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("タスクを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = TaskItem(id: task.id,
                               title: trimmed,
                               detail: detail,
                               priority: task.priority,
                               isCompleted: task.isCompleted,
                               createdAt: task.createdAt,
                               completedAt: task.completedAt)
        onSave(updated)
        dismiss()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
