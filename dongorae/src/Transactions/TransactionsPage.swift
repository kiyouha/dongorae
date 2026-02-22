import SwiftUI
import CoreData

enum LegDraftKind: String, CaseIterable {
    case cash
    case position
}

struct LegDraft: Identifiable, Equatable {
    let id: UUID
    var existingID: NSManagedObjectID?
    var kind: LegDraftKind

    var assetID: NSManagedObjectID?
    var role: LegRole
    var direction: LegDirection
    var titleText: String
    var isRequired: Bool

    var amountText: String
    var currency: String

    var ticker: String
    var market: String
    var quantityText: String
    var unit: String
    var priceText: String

    static func cashDefault(assetID: NSManagedObjectID?) -> LegDraft {
        LegDraft(
            id: UUID(),
            existingID: nil,
            kind: .cash,
            assetID: assetID,
            role: .expense,
            direction: .out,
            titleText: "",
            isRequired: false,
            amountText: "",
            currency: "KRW",
            ticker: "",
            market: "",
            quantityText: "",
            unit: "share",
            priceText: ""
        )
    }

    static func positionDefault(assetID: NSManagedObjectID?) -> LegDraft {
        LegDraft(
            id: UUID(),
            existingID: nil,
            kind: .position,
            assetID: assetID,
            role: .positionIn,
            direction: .in,
            titleText: "",
            isRequired: false,
            amountText: "",
            currency: "KRW",
            ticker: "",
            market: "",
            quantityText: "",
            unit: "share",
            priceText: ""
        )
    }
}

struct TransactionEditorInput {
    let transactionTitle: String
    let date: Date
    let executionDate: Date?
    let categoryID: NSManagedObjectID?
    let dividendTicker: String
    let stockTicker: String
    let stockMarket: String
    let memo: String
    let transactionTagsText: String
    let transactionType: TransactionType
    let legs: [LegDraft]
}

private struct DaySection {
    let day: Date
    let transactions: [Transaction]
}

private struct CurrencyNetItem: Identifiable {
    let id = UUID()
    let currency: String
    let amount: NSDecimalNumber
}

private struct LegEditRoute: Identifiable {
    let id: NSManagedObjectID
}

enum TransactionViewMode: String, CaseIterable {
    case list
    case calendar
}

struct TransactionsPage: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appContainer) private var appContainer

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Transaction.date, ascending: false),
            NSSortDescriptor(keyPath: \Transaction.order, ascending: true)
        ],
        animation: .default
    )
    private var transactions: FetchedResults<Transaction>

    @FetchRequest(entity: Asset.entity(), sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var assets: FetchedResults<Asset>

    @State private var expandedTransactionIDs: Set<NSManagedObjectID> = []

    @State private var showingCreate = false
    @State private var editingTransaction: Transaction?
    @State private var editingLegRoute: LegEditRoute?

    @State private var highlightedTransactionIDs: Set<NSManagedObjectID> = []
    @State private var highlightedLegIDs: Set<NSManagedObjectID> = []
    @StateObject private var pageViewModel = TransactionsPageViewModel()
    @StateObject private var mutationViewModel = TransactionsMutationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .background(Color(.systemBackground))

                if pageViewModel.transactionViewMode == .list {
                    List {
                        if groupedTransactions.isEmpty {
                            Section {
                                Text("거래가 없습니다")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(groupedTransactions, id: \.day) { section in
                                Section {
                                    ForEach(section.transactions, id: \.objectID) { tx in
                                        transactionItem(tx)
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                    .onMove { indices, newOffset in
                                        guard pageViewModel.isDeleteSelectionMode else { return }
                                        reorderTransactions(in: section.transactions, from: indices, to: newOffset)
                                    }
                                    .moveDisabled(!pageViewModel.isDeleteSelectionMode)
                                } header: {
                                    dayHeader(section)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(0)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .environment(\.editMode, .constant(pageViewModel.isDeleteSelectionMode ? .active : .inactive))
                } else {
                    VStack {
                        Spacer()
                        Text("달력 뷰는 곧 추가됩니다")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreate) {
                NavigationStack {
                    TransactionEditorView(
                        transaction: nil,
                        assets: Array(assets),
                        onSave: { input in createTransaction(input) },
                        onDelete: nil
                    )
                }
            }
            .sheet(item: $editingTransaction) { tx in
                NavigationStack {
                    TransactionEditorView(
                        transaction: tx,
                        assets: Array(assets),
                        onSave: { input in updateTransaction(tx, input: input) },
                        onDelete: { deleteTransaction(tx) }
                    )
                }
            }
            .sheet(item: $editingLegRoute) { route in
                if let leg = context.object(with: route.id) as? Leg {
                    NavigationStack {
                        LegEditorView(
                            leg: leg,
                            assets: Array(assets),
                            onSave: { _ = saveContext() },
                            onDelete: {
                                context.delete(leg)
                                _ = saveContext()
                            },
                            fallbackAssetProvider: { ensureDefaultAsset() }
                        )
                    }
                }
            }
            .sheet(isPresented: $pageViewModel.showingFilter) {
                TransactionFilterSheet(
                    allAssetOwners: availableAssetOwners,
                    allAssetClasses: availableAssetClasses,
                    allAssetInstitutions: availableAssetInstitutions,
                    allAssetTags: availableAssetTagNames,
                    allTransactionTypes: availableTransactionTypeNames,
                    allTransactionTags: availableTransactionTagNames,
                    selectedAssetOwners: $pageViewModel.selectedAssetOwnerFilters,
                    selectedAssetClasses: $pageViewModel.selectedAssetClassFilters,
                    selectedAssetInstitutions: $pageViewModel.selectedAssetInstitutionFilters,
                    selectedAssetTags: $pageViewModel.selectedAssetTagFilters,
                    selectedTransactionTypes: $pageViewModel.selectedTransactionTypeFilters,
                    selectedTransactionTags: $pageViewModel.selectedTransactionTagFilters
                )
            }
            .sheet(isPresented: $pageViewModel.showingMonthPicker) {
                YearMonthPickerSheet(currentDate: $pageViewModel.monthCursor)
            }
            .alert("저장 실패", isPresented: Binding(
                get: { mutationViewModel.saveErrorMessage != nil },
                set: { if !$0 { mutationViewModel.saveErrorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(mutationViewModel.saveErrorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("거래내역")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    headerIconButton("magnifyingglass") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pageViewModel.toggleSearch()
                        }
                    }
                    headerIconButton("plus") {
                        showingCreate = true
                    }
                    headerIconButton(pageViewModel.isDeleteSelectionMode ? "checkmark.square" : "square.and.pencil") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pageViewModel.toggleDeleteSelectionMode()
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 7)

            Divider().opacity(0.3)

            if pageViewModel.isDeleteSelectionMode {
                HStack(spacing: 10) {
                    Text("선택 \(pageViewModel.selectedTransactionIDs.count)건")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("선택 삭제", role: .destructive) {
                        deleteSelectedTransactions()
                    }
                    .font(AppTypography.body.weight(.semibold))
                    .disabled(pageViewModel.selectedTransactionIDs.isEmpty)
                    Button("완료") {
                        pageViewModel.finishDeleteSelectionMode()
                    }
                    .font(AppTypography.body)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 6)

                Divider().opacity(0.25)
            }

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        pageViewModel.monthCursor = Calendar.current.date(byAdding: .month, value: -1, to: pageViewModel.monthCursor) ?? pageViewModel.monthCursor
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .frame(width: 32, height: 32)
                    }

                    Button {
                        pageViewModel.showingMonthPicker = true
                    } label: {
                        Text(monthText(pageViewModel.monthCursor))
                            .font(.body.weight(.semibold))
                            .frame(width: 120, height: 32)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pageViewModel.monthCursor = Calendar.current.date(byAdding: .month, value: 1, to: pageViewModel.monthCursor) ?? pageViewModel.monthCursor
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .frame(width: 32, height: 32)
                    }

                    Spacer(minLength: 0)

                    headerIconButton(pageViewModel.transactionViewMode == .list ? "list.bullet" : "calendar") {
                        pageViewModel.transactionViewMode = pageViewModel.transactionViewMode == .list ? .calendar : .list
                    }

                    headerIconButton("line.3.horizontal.decrease") {
                        pageViewModel.showingFilter = true
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)

                if pageViewModel.showingSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("거래내역 검색", text: $pageViewModel.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .font(AppTypography.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.horizontal, AppSpacing.pageHorizontal)
                }

                if hasActiveFilters {
                    HStack(spacing: 8) {
                        Text(filterSummaryText)
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)
                }

                let monthNets = currencyNetItems(for: filteredTransactions)
                if !monthNets.isEmpty {
                    currencyNetLine(monthNets, font: .system(size: 12))
                        .padding(.horizontal, AppSpacing.pageHorizontal)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)

            Divider().opacity(0.3)
        }
    }

    private func dayHeader(_ section: DaySection) -> some View {
        let nets = currencyNetItems(for: section.transactions)

        return HStack(spacing: 8) {
            Text("\(dayNumberText(section.day))일 (\(weekdayText(section.day)))")
                .font(AppTypography.body.weight(.semibold))
                .monospacedDigit()

            Spacer(minLength: 8)

            if !nets.isEmpty {
                currencyNetLine(nets, font: .system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .frame(minHeight: 32, alignment: .leading)
        .textCase(nil)
    }

    @ViewBuilder
    private func currencyNetLine(_ items: [CurrencyNetItem], font: Font) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 3) {
                        Text(signedAmountText(item.amount))
                            .font(font)
                            .monospacedDigit()
                            .foregroundStyle(signedAmountColor(item.amount))
                        Text(item.currency)
                            .font(font)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func currencyNetItems(for txs: [Transaction]) -> [CurrencyNetItem] {
        guard !txs.isEmpty else { return [] }
        var buckets: [String: NSDecimalNumber] = [:]

        for tx in txs {
            let legs = (tx.legs as? Set<Leg>) ?? []
            for leg in legs {
                guard let cash = leg as? CashLeg else { continue }
                let currency = (cash.currency ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                guard !currency.isEmpty else { continue }

                let amount = cash.amount ?? NSDecimalNumber.zero
                let signedAmount = cash.directionEnum == .in
                    ? amount
                    : amount.multiplying(by: NSDecimalNumber(value: -1))

                buckets[currency] = (buckets[currency] ?? NSDecimalNumber.zero).adding(signedAmount)
            }
        }

        return buckets
            .map { CurrencyNetItem(currency: $0.key, amount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.currency == "KRW" { return true }
                if rhs.currency == "KRW" { return false }
                if lhs.currency == "USD" { return true }
                if rhs.currency == "USD" { return false }
                return lhs.currency < rhs.currency
            }
    }

    private func signedAmountText(_ value: NSDecimalNumber) -> String {
        let absValue = value.compare(NSDecimalNumber.zero) == .orderedAscending
            ? value.multiplying(by: NSDecimalNumber(value: -1))
            : value
        let base = amountText(absValue)
        switch value.compare(NSDecimalNumber.zero) {
        case .orderedDescending:
            return "+\(base)"
        case .orderedAscending:
            return "-\(base)"
        default:
            return base
        }
    }

    private func signedAmountColor(_ value: NSDecimalNumber) -> Color {
        switch value.compare(NSDecimalNumber.zero) {
        case .orderedDescending:
            return AppPalette.red
        case .orderedAscending:
            return AppPalette.blue
        default:
            return .primary
        }
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        let categoryInfo = transactionCategoryInfo(for: tx)
        let isPressed = highlightedTransactionIDs.contains(tx.objectID)
        return HStack(alignment: .center, spacing: 8) {
            if pageViewModel.isDeleteSelectionMode {
                Image(systemName: pageViewModel.selectedTransactionIDs.contains(tx.objectID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(pageViewModel.selectedTransactionIDs.contains(tx.objectID) ? AppPalette.yellow : .secondary)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28, alignment: .center)
                    .padding(.trailing, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(tx.title ?? "제목 없음")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isPressed ? AppPalette.yellow : .primary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        categoryTagChip(icon: categoryInfo.icon, title: categoryChipTitle(categoryInfo), isPressed: isPressed)
                        if !tagGroupText(for: tx).isEmpty {
                            Text(tagGroupText(for: tx))
                                .font(.system(size: 13))
                                .foregroundStyle(isPressed ? AppPalette.yellow : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: 180, alignment: .trailing)
                }

                summaryView(for: tx, isPressed: isPressed)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if pageViewModel.isDeleteSelectionMode {
                toggleTransactionSelection(tx)
            } else {
                highlightTransactionAndToggleExpand(tx)
            }
        }
        .onLongPressGesture(minimumDuration: 0.12) {
            if !pageViewModel.isDeleteSelectionMode {
                highlightAndEditTransaction(tx)
            }
        }
    }

    private func transactionItem(_ tx: Transaction) -> some View {
        let expanded = expandedTransactionIDs.contains(tx.objectID)

        return VStack(alignment: .leading, spacing: 0) {
            transactionRow(tx)
            if expanded {
                legsBlock(tx)
                    .padding(.top, 8)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.vertical, 4)
    }

    private func legsBlock(_ tx: Transaction) -> some View {
        let legs = ((tx.legs as? Set<Leg>) ?? []).sorted { $0.order < $1.order }

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(legs, id: \.objectID) { leg in
                legRow(leg)
            }
        }
    }

    private func legRow(_ leg: Leg) -> some View {
        Group {
            if let cash = leg as? CashLeg {
                let isPressed = highlightedLegIDs.contains(cash.objectID)
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(cash.asset?.name ?? "")
                            .foregroundStyle(isPressed ? AppPalette.yellow : .primary)
                            .lineLimit(1)
                        let title = legTitle(dynamicStringValue(cash, key: "title"))
                        if !title.isEmpty {
                            Text(title)
                                .foregroundStyle(isPressed ? AppPalette.yellow : .secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text(signedDecimalText(cash.amount, direction: cash.directionEnum))
                            .monospacedDigit()
                            .foregroundStyle(isPressed ? AppPalette.yellow : signedColor(cash.amount, direction: cash.directionEnum))
                        let currency = (cash.currency ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !currency.isEmpty {
                            Text(currency)
                                .foregroundStyle(isPressed ? AppPalette.yellow : .secondary)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 13))
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 38, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { highlightAndEditLeg(cash.objectID) }
                .onLongPressGesture(minimumDuration: 0.08) { highlightAndEditLeg(cash.objectID) }
            } else if let position = leg as? PositionLeg {
                let isPressed = highlightedLegIDs.contains(position.objectID)
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(position.asset?.name ?? "")
                            .foregroundStyle(isPressed ? AppPalette.yellow : .primary)
                            .lineLimit(1)
                        let title = legTitle(dynamicStringValue(position, key: "title"))
                        if !title.isEmpty {
                            Text(title)
                                .foregroundStyle(isPressed ? AppPalette.yellow : .secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        let ticker = (position.ticker ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        if !ticker.isEmpty {
                            Text(ticker)
                                .foregroundStyle(isPressed ? AppPalette.yellow : .primary)
                        }
                        Text(signedDecimalText(position.quantity, direction: position.directionEnum))
                            .monospacedDigit()
                            .foregroundStyle(isPressed ? AppPalette.yellow : signedColor(position.quantity, direction: position.directionEnum))
                        Text("주")
                            .foregroundStyle(isPressed ? AppPalette.yellow : .primary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 13))
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 38, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { highlightAndEditLeg(position.objectID) }
                .onLongPressGesture(minimumDuration: 0.08) { highlightAndEditLeg(position.objectID) }
            }
        }
    }

    @ViewBuilder
    private func categoryTagChip(icon: String, title: String, isPressed: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(icon)
                .font(.system(size: 11))
            Text(title)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .foregroundStyle(isPressed ? AppPalette.yellow : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }

    private func categoryChipTitle(_ info: (icon: String, parent: String, child: String?)) -> String {
        let parent = categoryDisplayTitle(info.parent)
        if let child = info.child, !child.isEmpty {
            return "\(parent)/\(categoryDisplayTitle(child))"
        }
        return parent
    }

    private func categoryDisplayTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(8))
    }

    private func toggleExpand(_ tx: Transaction) {
        if expandedTransactionIDs.contains(tx.objectID) {
            expandedTransactionIDs.remove(tx.objectID)
        } else {
            expandedTransactionIDs.insert(tx.objectID)
        }
    }

    private func highlightAndEditTransaction(_ tx: Transaction) {
        highlightedTransactionIDs.insert(tx.objectID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            highlightedTransactionIDs.remove(tx.objectID)
            editingTransaction = tx
        }
    }

    private func highlightTransactionAndToggleExpand(_ tx: Transaction) {
        highlightedTransactionIDs.insert(tx.objectID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            highlightedTransactionIDs.remove(tx.objectID)
            toggleExpand(tx)
        }
    }

    private func highlightAndEditLeg(_ id: NSManagedObjectID) {
        highlightedLegIDs.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            highlightedLegIDs.remove(id)
            editingLegRoute = LegEditRoute(id: id)
        }
    }

    private func reorderTransactions(in dayTransactions: [Transaction], from source: IndexSet, to destination: Int) {
        guard !dayTransactions.isEmpty else { return }
        var orderedIDs = dayTransactions.map(\.objectID)
        orderedIDs.move(fromOffsets: source, toOffset: destination)

        let byID = Dictionary(uniqueKeysWithValues: dayTransactions.map { ($0.objectID, $0) })
        for (index, id) in orderedIDs.enumerated() {
            byID[id]?.order = Int16(index)
        }
        saveContext()
    }

    private func toggleTransactionSelection(_ tx: Transaction) {
        pageViewModel.toggleTransactionSelection(tx.objectID)
    }

    private func deleteSelectedTransactions() {
        let selected = Array(transactions).filter { pageViewModel.selectedTransactionIDs.contains($0.objectID) }
        for tx in selected { context.delete(tx) }
        pageViewModel.finishDeleteSelectionMode()
        _ = saveContext()
    }

    private var monthTransactions: [Transaction] {
        TransactionsQueryService.monthTransactions(
            Array(transactions),
            monthCursor: pageViewModel.monthCursor
        )
    }

    private var filteredTransactions: [Transaction] {
        let filters = TransactionsFilterSnapshot(
            selectedAssetOwners: effectiveSelectedAssetOwnerFilters,
            selectedAssetClasses: effectiveSelectedAssetClassFilters,
            selectedAssetInstitutions: effectiveSelectedAssetInstitutionFilters,
            selectedAssetTags: effectiveSelectedAssetTagFilters,
            selectedTransactionTypes: effectiveSelectedTransactionTypeFilters,
            selectedTransactionTags: effectiveSelectedTransactionTagFilters
        )

        return TransactionsQueryService.filteredTransactions(
            monthTransactions,
            searchText: pageViewModel.searchText,
            filters: filters,
            searchableText: { tx in
                [
                    tx.title ?? "",
                    tx.memo ?? "",
                    transactionSummary(for: tx),
                    transactionTagText(for: tx)
                ].joined(separator: " ")
            },
            assetOwnerNames: { tx in assetOwnerNames(for: tx) },
            assetClassNames: { tx in assetClassNames(for: tx) },
            assetInstitutionNames: { tx in assetInstitutionNames(for: tx) },
            assetTagNames: { tx in assetTagNames(for: tx) },
            transactionTypeName: { tx in transactionTypeName(for: tx) },
            transactionTagNames: { tx in transactionTagNames(for: tx) }
        )
    }

    private var groupedTransactions: [DaySection] {
        TransactionsQueryService.groupedByDay(filteredTransactions).map { grouped in
            DaySection(day: grouped.day, transactions: grouped.transactions)
        }
    }

    private var availableAssetOwners: [String] {
        let values = assets.compactMap { asset in
            trimmedOrNil(dynamicStringValue(asset, key: "owner"))
        }
        return Array(Set(values)).sorted()
    }

    private var availableAssetClasses: [String] {
        let values = assets.compactMap { asset -> String? in
            guard let account = asset as? Account else { return nil }
            return assetClassText(account.type)
        }
        return Array(Set(values)).sorted()
    }

    private var availableAssetInstitutions: [String] {
        let values = assets.compactMap { asset -> String? in
            guard let account = asset as? Account else { return nil }
            return trimmedOrNil(account.institution)
        }
        return Array(Set(values)).sorted()
    }

    private var availableAssetTagNames: [String] {
        let joins: [AssetTag] = assets.flatMap { asset in
            ((asset.tags as? Set<AssetTag>) ?? []).map { $0 }
        }
        let names = joins.compactMap { trimmedOrNil($0.tag?.name) }
        return Array(Set(names)).sorted()
    }

    private var availableTransactionTypeNames: [String] {
        let names = monthTransactions.map { transactionTypeName(for: $0) }
        return Array(Set(names)).sorted()
    }

    private var availableTransactionTagNames: [String] {
        let names = monthTransactions.flatMap { transactionTagNames(for: $0) }
        return Array(Set(names)).sorted()
    }

    private func assetTags(for tx: Transaction) -> [Tag] {
        let legs = (tx.legs as? Set<Leg>) ?? []
        let joins: [AssetTag] = legs.flatMap { leg in
            ((leg.asset?.tags as? Set<AssetTag>) ?? []).map { $0 }
        }
        return joins.compactMap { $0.tag }
    }

    private func transactionTags(for tx: Transaction) -> [Tag] {
        let joins = (tx.tags as? Set<TransactionTag>) ?? []
        return joins.compactMap { $0.tag }
    }

    private func assetOwnerNames(for tx: Transaction) -> Set<String> {
        let legs = (tx.legs as? Set<Leg>) ?? []
        let values = legs.compactMap { leg -> String? in
            guard let asset = leg.asset else { return nil }
            return trimmedOrNil(dynamicStringValue(asset, key: "owner"))
        }
        return Set(values)
    }

    private func assetClassNames(for tx: Transaction) -> Set<String> {
        let legs = (tx.legs as? Set<Leg>) ?? []
        let values = legs.compactMap { leg -> String? in
            guard let account = leg.asset as? Account else { return nil }
            return assetClassText(account.type)
        }
        return Set(values)
    }

    private func assetInstitutionNames(for tx: Transaction) -> Set<String> {
        let legs = (tx.legs as? Set<Leg>) ?? []
        let values = legs.compactMap { leg -> String? in
            guard let account = leg.asset as? Account else { return nil }
            return trimmedOrNil(account.institution)
        }
        return Set(values)
    }

    private func assetTagNames(for tx: Transaction) -> Set<String> {
        Set(assetTags(for: tx).compactMap { trimmedOrNil($0.name) })
    }

    private func transactionTagNames(for tx: Transaction) -> [String] {
        transactionTags(for: tx).compactMap { trimmedOrNil($0.name) }
    }

    private func transactionTypeName(for tx: Transaction) -> String {
        let legs = ((tx.legs as? Set<Leg>) ?? []).sorted { $0.order < $1.order }
        return inferredTransactionType(for: tx, legs: legs).title
    }

    private func transactionSummary(for tx: Transaction) -> String {
        summaryPlain(for: tx)
    }

    @ViewBuilder
    private func summaryView(for tx: Transaction, isPressed: Bool = false) -> some View {
        Group {
            if isPressed {
                AutoMarqueeText(
                    summaryPlain(for: tx),
                    font: .system(size: 10),
                    color: AppPalette.yellow,
                    alignment: .leading
                )
            } else {
                AutoMarqueeAttributedText(
                    summaryAttributed(for: tx),
                    alignment: .leading
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transactionTagText(for tx: Transaction) -> String {
        transactionTagNames(for: tx).sorted().joined(separator: ", ")
    }

    private func tagGroupText(for tx: Transaction) -> String {
        transactionTagText(for: tx)
    }

    private func transactionCategoryInfo(for tx: Transaction) -> (icon: String, parent: String, child: String?) {
        guard let category = tx.value(forKey: "category") as? NSManagedObject else {
            return ("📒", "미분류", nil)
        }
        let icon = trimmedOrNil(category.value(forKey: "icon") as? String) ?? "📒"
        let ownTitle = trimmedOrNil(category.value(forKey: "title") as? String) ?? "미분류"
        if let parent = category.value(forKey: "parent") as? NSManagedObject {
            let parentTitle = trimmedOrNil(parent.value(forKey: "title") as? String) ?? ownTitle
            return (icon, parentTitle, ownTitle)
        }
        return (icon, ownTitle, nil)
    }

    private var filterSummaryText: String {
        let selectedAssetOwners = effectiveSelectedAssetOwnerFilters
        let selectedAssetClasses = effectiveSelectedAssetClassFilters
        let selectedAssetInstitutions = effectiveSelectedAssetInstitutionFilters
        let selectedAssetTags = effectiveSelectedAssetTagFilters
        let selectedTransactionTypes = effectiveSelectedTransactionTypeFilters
        let selectedTransactionTags = effectiveSelectedTransactionTagFilters

        var parts: [String] = []
        if !selectedAssetOwners.isEmpty { parts.append("소유주 \(selectedAssetOwners.sorted().joined(separator: ", "))") }
        if !selectedAssetClasses.isEmpty { parts.append("자산 분류 \(selectedAssetClasses.sorted().joined(separator: ", "))") }
        if !selectedAssetInstitutions.isEmpty { parts.append("기관 \(selectedAssetInstitutions.sorted().joined(separator: ", "))") }
        if !selectedAssetTags.isEmpty { parts.append("자산 태그 \(selectedAssetTags.sorted().joined(separator: ", "))") }
        if !selectedTransactionTypes.isEmpty { parts.append("거래 유형 \(selectedTransactionTypes.sorted().joined(separator: ", "))") }
        if !selectedTransactionTags.isEmpty { parts.append("거래 태그 \(selectedTransactionTags.sorted().joined(separator: ", "))") }
        if parts.isEmpty { return "전체" }
        return parts.joined(separator: " · ")
    }

    private var hasActiveFilters: Bool {
        !effectiveSelectedAssetOwnerFilters.isEmpty ||
        !effectiveSelectedAssetClassFilters.isEmpty ||
        !effectiveSelectedAssetInstitutionFilters.isEmpty ||
        !effectiveSelectedAssetTagFilters.isEmpty ||
        !effectiveSelectedTransactionTypeFilters.isEmpty ||
        !effectiveSelectedTransactionTagFilters.isEmpty
    }

    private var effectiveSelectedAssetOwnerFilters: Set<String> {
        pageViewModel.selectedAssetOwnerFilters.intersection(Set(availableAssetOwners))
    }

    private var effectiveSelectedAssetClassFilters: Set<String> {
        pageViewModel.selectedAssetClassFilters.intersection(Set(availableAssetClasses))
    }

    private var effectiveSelectedAssetInstitutionFilters: Set<String> {
        pageViewModel.selectedAssetInstitutionFilters.intersection(Set(availableAssetInstitutions))
    }

    private var effectiveSelectedAssetTagFilters: Set<String> {
        pageViewModel.selectedAssetTagFilters.intersection(Set(availableAssetTagNames))
    }

    private var effectiveSelectedTransactionTypeFilters: Set<String> {
        pageViewModel.selectedTransactionTypeFilters.intersection(Set(availableTransactionTypeNames))
    }

    private var effectiveSelectedTransactionTagFilters: Set<String> {
        pageViewModel.selectedTransactionTagFilters.intersection(Set(availableTransactionTagNames))
    }

    private func legTitle(_ note: String?) -> String {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed
    }

    private func assetClassText(_ raw: Int16) -> String {
        switch raw {
        case 0: return "은행"
        case 1: return "증권"
        default: return "기타"
        }
    }

    private func monthText(_ day: Date) -> String {
        Self.monthFormatter.string(from: day)
    }

    @ViewBuilder
    private func headerIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(HeaderIconButtonStyle())
    }

    private func dayNumberText(_ day: Date) -> String {
        Self.dayFormatter.string(from: day)
    }

    private func weekdayText(_ day: Date) -> String {
        Self.weekdayFormatter.string(from: day)
    }

    private func amountText(_ value: NSDecimalNumber) -> String {
        Self.amountFormatter.string(from: value) ?? value.stringValue
    }

    private func decimalText(_ value: NSDecimalNumber?) -> String {
        let number = value ?? 0
        if number.compare(0) == .orderedSame { return "0" }
        return Self.decimalFormatter.string(from: number) ?? number.stringValue
    }

    private func signedDecimalText(_ value: NSDecimalNumber?, direction: LegDirection) -> String {
        let number = value ?? 0
        let absValue = number.compare(0) == .orderedAscending ? number.multiplying(by: -1) : number
        let base = decimalText(absValue)
        if absValue.compare(0) == .orderedSame { return base }
        let sign = direction == .in ? "+" : "-"
        return "\(sign)\(base)"
    }

    private func signedColor(_ value: NSDecimalNumber?, direction: LegDirection) -> Color {
        let number = value ?? 0
        let absValue = number.compare(0) == .orderedAscending ? number.multiplying(by: -1) : number
        if absValue.compare(0) == .orderedSame { return .primary }
        return direction == .in ? AppPalette.red : AppPalette.blue
    }

    private func summaryAttributed(for tx: Transaction) -> AttributedString {
        let fragments = summaryTokens(for: tx)
        var result = AttributedString()
        for (index, fragment) in fragments.enumerated() {
            if index > 0 {
                var separator = AttributedString("")
                if fragment.leadingSeparator {
                    separator = AttributedString(" · ")
                }
                separator.foregroundColor = .secondary
                separator.font = .system(size: 10)
                result += separator
            }
            var text = AttributedString(fragment.text)
            text.foregroundColor = color(for: fragment.style)
            text.font = .system(size: 10)
            result += text
        }
        return result
    }

    private func summaryPlain(for tx: Transaction) -> String {
        summaryTokens(for: tx).map(\.text).joined(separator: " ")
    }

    private func summaryTokens(for tx: Transaction) -> [SummaryToken] {
        let legs = ((tx.legs as? Set<Leg>) ?? []).sorted { $0.order < $1.order }
        let summary = TransactionSummaryService.makeSummary(
            tx: tx,
            legs: legs,
            fxRate: transactionFXRate(tx),
            averagePrice: transactionAveragePrice(tx),
            dividendTicker: transactionDividendTicker(tx),
            amountText: amountText,
            decimalText: decimalText
        )
        return summary.tokens
    }

    private func inferredTransactionType(for tx: Transaction, legs: [Leg]) -> TransactionType {
        TransactionSummaryService.inferType(
            tx: tx,
            legs: legs,
            fxRate: transactionFXRate(tx),
            dividendTicker: transactionDividendTicker(tx)
        )
    }

    private func color(for style: SummaryTokenStyle) -> Color {
        switch style {
        case .secondary: return .secondary
        case .primary: return .primary
        case .positive: return AppPalette.red
        case .negative: return AppPalette.blue
        case .accent: return AppPalette.yellow
        }
    }

    private func createTransaction(_ input: TransactionEditorInput) -> Bool {
        mutationViewModel.create(input: input, in: context, store: appContainer.store)
    }

    private func updateTransaction(_ tx: Transaction, input: TransactionEditorInput) -> Bool {
        mutationViewModel.update(tx, input: input, in: context, store: appContainer.store)
    }

    private func deleteTransaction(_ tx: Transaction) {
        mutationViewModel.delete(tx, in: context, store: appContainer.store)
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }

    private func dynamicDecimalValue(_ object: NSManagedObject, key: String) -> NSDecimalNumber? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? NSDecimalNumber
    }

    private func transactionFXRate(_ tx: Transaction) -> NSDecimalNumber? {
        dynamicDecimalValue(tx, key: "fxRate")
    }

    private func transactionAveragePrice(_ tx: Transaction) -> NSDecimalNumber? {
        dynamicDecimalValue(tx, key: "averagePrice")
    }

    private func transactionDividendTicker(_ tx: Transaction) -> String? {
        let ticker = dynamicStringValue(tx, key: "dividendTicker")?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let ticker, !ticker.isEmpty { return ticker }
        return nil
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    private func ensureDefaultAsset() -> Asset {
        if let first = assets.first { return first }

        let now = Date()
        let account = Account(context: context)
        account.id = UUID()
        account.name = "기본 현금"
        account.note = nil
        account.isActive = true
        account.createdAt = now
        account.updatedAt = now
        account.accountNumber = nil
        account.institution = "수동 생성"
        account.type = 0
        return account
    }

    @discardableResult
    private func saveContext() -> Bool {
        mutationViewModel.save(in: context, store: appContainer.store)
    }
}

private struct TransactionFilterSheet: View {
    let allAssetOwners: [String]
    let allAssetClasses: [String]
    let allAssetInstitutions: [String]
    let allAssetTags: [String]
    let allTransactionTypes: [String]
    let allTransactionTags: [String]
    @Binding var selectedAssetOwners: Set<String>
    @Binding var selectedAssetClasses: Set<String>
    @Binding var selectedAssetInstitutions: Set<String>
    @Binding var selectedAssetTags: Set<String>
    @Binding var selectedTransactionTypes: Set<String>
    @Binding var selectedTransactionTags: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var assetSearchText = ""
    @State private var transactionSearchText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("자산 영역") {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("자산 필터 검색", text: $assetSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    stringFilterCategory(title: "소유주", options: filteredAssetOwners, selected: $selectedAssetOwners)
                    stringFilterCategory(title: "자산 분류", options: filteredAssetClasses, selected: $selectedAssetClasses)
                    stringFilterCategory(title: "기관", options: filteredAssetInstitutions, selected: $selectedAssetInstitutions)
                    stringFilterCategory(title: "태그", options: filteredAssetTags, selected: $selectedAssetTags)
                }

                Section("거래내역 영역") {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("거래내역 필터 검색", text: $transactionSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    stringFilterCategory(title: "거래 유형", options: filteredTransactionTypes, selected: $selectedTransactionTypes)
                    stringFilterCategory(title: "태그", options: filteredTransactionTags, selected: $selectedTransactionTags)
                }

            }
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func stringFilterCategory(title: String, options: [String], selected: Binding<Set<String>>) -> some View {
        if !options.isEmpty {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                selected.wrappedValue.removeAll()
            } label: {
                HStack {
                    Text("전체")
                    Spacer()
                    if selected.wrappedValue.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(options, id: \.self) { item in
                Button {
                    if selected.wrappedValue.contains(item) {
                        selected.wrappedValue.remove(item)
                    } else {
                        selected.wrappedValue.insert(item)
                    }
                } label: {
                    HStack {
                        Text(item)
                        Spacer()
                        if selected.wrappedValue.contains(item) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private var filteredAssetOwners: [String] {
        filterStrings(allAssetOwners, query: assetSearchText)
    }

    private var filteredAssetClasses: [String] {
        filterStrings(allAssetClasses, query: assetSearchText)
    }

    private var filteredAssetInstitutions: [String] {
        filterStrings(allAssetInstitutions, query: assetSearchText)
    }

    private var filteredAssetTags: [String] {
        filterStrings(allAssetTags, query: assetSearchText)
    }

    private var filteredTransactionTypes: [String] {
        filterStrings(allTransactionTypes, query: transactionSearchText)
    }

    private var filteredTransactionTags: [String] {
        filterStrings(allTransactionTags, query: transactionSearchText)
    }

    private func filterStrings(_ items: [String], query: String) -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return items }
        return items.filter { $0.lowercased().contains(normalized) }
    }
}

private struct YearMonthPickerSheet: View {
    @Binding var currentDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    private let years = Array(2000...2100)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Picker("연도", selection: $year) {
                        ForEach(years, id: \.self) { y in
                            Text("\(y)년").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("월", selection: $month) {
                        ForEach(1...12, id: \.self) { m in
                            Text("\(m)월").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Button("적용") {
                    var components = DateComponents()
                    components.year = year
                    components.month = month
                    components.day = 1
                    if let date = Calendar.current.date(from: components) {
                        currentDate = date
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("연월 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                year = Calendar.current.component(.year, from: currentDate)
                month = Calendar.current.component(.month, from: currentDate)
            }
        }
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.16) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
