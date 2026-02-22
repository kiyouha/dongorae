import SwiftUI
import CoreData

struct SettingsPage: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    AppCard("통계/리포트") {
                        reportLink("월별 재정 리포트", systemImage: "doc.text")
                        reportLink("지출 패턴 분석", systemImage: "chart.bar.xaxis")
                        reportLink("목표 저축률 달성 현황", systemImage: "target")
                    }

                    AppCard("설정") {
                        NavigationLink {
                            TransactionCategoryManagerView()
                        } label: {
                            settingRow("카테고리/예산 설정", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.plain)
                        settingRow("알림 설정", systemImage: "bell")
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, AppSpacing.sectionVertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("더보기")
                        .font(AppTypography.title)
                }
            }
        }
    }

    private func reportLink(_ title: String, systemImage: String) -> some View {
        NavigationLink {
            reportDetail(title: title)
        } label: {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(AppPalette.green)
                Text(title)
                    .font(AppTypography.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func settingRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(AppPalette.yellow)
            Text(title)
                .font(AppTypography.body)
            Spacer()
        }
    }

    private func reportDetail(title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(AppTypography.body.weight(.semibold))
            Text("리포트 상세는 다음 단계에서 연결됩니다.")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.vertical, AppSpacing.sectionVertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct TransactionCategoryManagerView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appContainer) private var appContainer
    @FetchRequest(fetchRequest: Self.categoryRequest())
    private var categories: FetchedResults<NSManagedObject>

    @StateObject private var pageViewModel = TransactionCategoryPageViewModel()
    @StateObject private var mutationViewModel = TransactionCategoryMutationViewModel()

    var body: some View {
        List {
            if rootCategories.isEmpty {
                Text("카테고리가 없습니다")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rootCategories, id: \.objectID) { root in
                    categoryRow(root, isChild: false)
                    ForEach(children(of: root), id: \.objectID) { child in
                        categoryRow(child, isChild: true)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("카테고리 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pageViewModel.startCreate()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $pageViewModel.showingCreate) {
            NavigationStack {
                TransactionCategoryEditorView(
                    category: nil,
                    allCategories: Array(categories),
                    onSave: { saveCategory(nil, with: $0) }
                )
            }
        }
        .sheet(item: $pageViewModel.editingRoute) { route in
            if let category = categoryByID(route.id) {
                NavigationStack {
                    TransactionCategoryEditorView(
                        category: category,
                        allCategories: Array(categories),
                        onSave: { saveCategory(category, with: $0) },
                        onDelete: { deleteCategory(category) }
                    )
                }
            }
        }
        .alert("저장 실패", isPresented: Binding(
            get: { mutationViewModel.saveErrorMessage != nil },
            set: { if !$0 { mutationViewModel.saveErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(mutationViewModel.saveErrorMessage ?? "")
        }
        .alert("삭제할 수 없음", isPresented: Binding(
            get: { mutationViewModel.deleteBlockedMessage != nil },
            set: { if !$0 { mutationViewModel.deleteBlockedMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(mutationViewModel.deleteBlockedMessage ?? "")
        }
    }

    private static func categoryRequest() -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TransactionCategory")
        request.sortDescriptors = [
            NSSortDescriptor(key: "parent", ascending: true),
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return request
    }

    private func categoryRow(_ category: NSManagedObject, isChild: Bool) -> some View {
        HStack(spacing: 10) {
            if isChild { Color.clear.frame(width: 18) }
            let icon = (category.value(forKey: "icon") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            Text(icon.isEmpty ? "📁" : icon)
            Text(category.value(forKey: "title") as? String ?? "이름 없음")
                .font(AppTypography.body)
            Spacer()
            Button {
                pageViewModel.startEdit(category.objectID)
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var rootCategories: [NSManagedObject] {
        Array(categories)
            .filter { ($0.value(forKey: "parent") as? NSManagedObject) == nil }
            .sorted { lhs, rhs in
                let lOrder = lhs.value(forKey: "order") as? Int16 ?? 0
                let rOrder = rhs.value(forKey: "order") as? Int16 ?? 0
                if lOrder != rOrder { return lOrder < rOrder }
                let lTitle = lhs.value(forKey: "title") as? String ?? ""
                let rTitle = rhs.value(forKey: "title") as? String ?? ""
                return lTitle < rTitle
            }
    }

    private func children(of parent: NSManagedObject) -> [NSManagedObject] {
        ((parent.value(forKey: "children") as? Set<NSManagedObject>) ?? [])
            .sorted { lhs, rhs in
                let lOrder = lhs.value(forKey: "order") as? Int16 ?? 0
                let rOrder = rhs.value(forKey: "order") as? Int16 ?? 0
                if lOrder != rOrder { return lOrder < rOrder }
                let lTitle = lhs.value(forKey: "title") as? String ?? ""
                let rTitle = rhs.value(forKey: "title") as? String ?? ""
                return lTitle < rTitle
            }
    }

    private func saveCategory(_ category: NSManagedObject?, with input: TransactionCategoryInput) {
        mutationViewModel.saveCategory(
            editingID: category?.objectID,
            input: input,
            existingCategories: Array(categories),
            in: context,
            store: appContainer.store
        )
    }

    private func deleteCategory(_ category: NSManagedObject) {
        mutationViewModel.deleteCategory(category.objectID, in: context, store: appContainer.store)
    }

    private func categoryByID(_ objectID: NSManagedObjectID?) -> NSManagedObject? {
        guard let objectID else { return nil }
        return try? context.existingObject(with: objectID)
    }

}

struct TransactionCategoryInput {
    let title: String
    let icon: String
    let parentID: NSManagedObjectID?
}

private struct TransactionCategoryEditorView: View {
    let category: NSManagedObject?
    let allCategories: [NSManagedObject]
    let onSave: (TransactionCategoryInput) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var icon = ""
    @State private var parentID: NSManagedObjectID?

    var body: some View {
        List {
            lineRow("제목") {
                TextField("카테고리명", text: $title)
                    .multilineTextAlignment(.trailing)
            }
            lineRow("상위 카테고리") {
                Picker("상위 카테고리", selection: $parentID) {
                    Text("없음(부모 카테고리)").tag(Optional<NSManagedObjectID>.none)
                    ForEach(parentCandidates, id: \.objectID) { parent in
                        let iconText = ((parent.value(forKey: "icon") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let titleText = parent.value(forKey: "title") as? String ?? ""
                        Text("\(iconText.isEmpty ? "📁" : iconText) \(titleText)")
                            .tag(Optional(parent.objectID))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppPalette.green)
            }

            if parentID == nil {
                lineRow("아이콘") {
                    TextField("예: 🍔", text: $icon)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                lineRow("아이콘") {
                    Text(inheritedParentIcon)
                        .foregroundStyle(.secondary)
                }
            }

            if let onDelete {
                Button("삭제", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
        .navigationTitle(category == nil ? "카테고리 추가" : "카테고리 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    onSave(
                        TransactionCategoryInput(
                            title: resolvedTitle,
                            icon: resolvedIcon,
                            parentID: parentID
                        )
                    )
                    dismiss()
                }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private var parentCandidates: [NSManagedObject] {
        allCategories
            .filter { ($0.value(forKey: "parent") as? NSManagedObject) == nil }
            .filter { $0.objectID != category?.objectID }
            .sorted { lhs, rhs in
                let lOrder = lhs.value(forKey: "order") as? Int16 ?? 0
                let rOrder = rhs.value(forKey: "order") as? Int16 ?? 0
                if lOrder != rOrder { return lOrder < rOrder }
                let lTitle = lhs.value(forKey: "title") as? String ?? ""
                let rTitle = rhs.value(forKey: "title") as? String ?? ""
                return lTitle < rTitle
            }
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "이름 없음" : trimmed
    }

    private var resolvedIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "📁" : trimmed
    }

    private var inheritedParentIcon: String {
        guard let parentID,
              let parent = allCategories.first(where: { $0.objectID == parentID }) else {
            return "📁"
        }
        let icon = (parent.value(forKey: "icon") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "📁" : icon
    }

    private func loadInitial() {
        guard let category else { return }
        title = category.value(forKey: "title") as? String ?? ""
        icon = category.value(forKey: "icon") as? String ?? ""
        parentID = (category.value(forKey: "parent") as? NSManagedObject)?.objectID
    }

    @ViewBuilder
    private func lineRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            Spacer()
            content()
                .font(AppTypography.body)
        }
        .padding(.vertical, AppSpacing.rowVertical)
    }
}
