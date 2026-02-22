import SwiftUI
import CoreData

private enum AssetClassOption: Int16, CaseIterable, Identifiable {
    case bank = 0
    case brokerage = 1
    case other = 99

    var id: Int16 { rawValue }

    static var selectableCases: [AssetClassOption] { [.bank, .brokerage] }

    var title: String {
        switch self {
        case .bank: return "은행"
        case .brokerage: return "증권"
        case .other: return "기타"
        }
    }
}

struct AssetEditorInput {
    let name: String
    let owner: String
    let institution: String
    let accountNumber: String
    let note: String
    let tagsText: String
    let assetClass: Int16
    let isActive: Bool
}

private struct AssetGroupSection {
    let title: String
    let assets: [Asset]
    let summaryItems: [CurrencySummaryItem]
}

private struct AssetHoldingRow: Identifiable {
    let id = UUID()
    let title: String
    let amount: NSDecimalNumber
    let currency: String
    let trailingNote: String?
    let quantity: NSDecimalNumber?
}

private struct AssetHoldingSection: Identifiable {
    let id = UUID()
    let title: String
    let headerNote: String?
    let rows: [AssetHoldingRow]
}

private struct CurrencySummaryItem: Identifiable {
    let id = UUID()
    let currency: String
    let amount: NSDecimalNumber
}

private struct AssetAggregateChild: Identifiable {
    let id = UUID()
    let title: String
    let amount: NSDecimalNumber
    let currency: String
}

private struct AssetAggregateItem: Identifiable {
    let id: String
    let title: String
    let amount: NSDecimalNumber
    let currency: String
    let children: [AssetAggregateChild]
}

private struct AssetAggregateSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [AssetAggregateItem]
    let summaryItems: [CurrencySummaryItem]
}

private struct HoldingRecord {
    let assetID: NSManagedObjectID
    let assetName: String
    let kind: InstrumentKind
    let code: String
    let currency: String
    let quantity: NSDecimalNumber
    let marketValue: NSDecimalNumber
}

struct AssetsPage: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appContainer) private var appContainer

    @FetchRequest(entity: Asset.entity(), sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var assets: FetchedResults<Asset>
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Transaction.date, ascending: true),
            NSSortDescriptor(keyPath: \Transaction.order, ascending: true)
        ]
    )
    private var transactions: FetchedResults<Transaction>

    @StateObject private var pageViewModel = AssetsPageViewModel()
    @StateObject private var mutationViewModel = AssetsMutationViewModel()
    @State private var selectedAssetOwners: Set<String> = []
    @State private var selectedAssetTags: Set<String> = []
    @State private var didBootstrapHoldings = false
    @State private var expandedAssetIDs: Set<NSManagedObjectID> = []
    @State private var expandedAggregateItemIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .background(Color(.systemBackground))

                List {
                    if isCurrentModeEmpty {
                        Section {
                            Text("자산이 없습니다")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        if pageViewModel.groupingMode == .byAccount {
                            ForEach(accountModeSections, id: \.title) { section in
                                Section {
                                    ForEach(section.assets, id: \.objectID) { asset in
                                        assetItem(asset)
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                } header: {
                                    assetSectionHeader(section.title, summaryItems: section.summaryItems)
                                }
                            }
                        } else {
                            ForEach(assetModeSections) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        aggregateItemView(item, sectionTitle: section.title)
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    }
                                } header: {
                                    assetSectionHeader(section.title, summaryItems: section.summaryItems)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(0)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $pageViewModel.showingCreate) {
                NavigationStack {
                    AssetEditorView(
                        account: nil,
                        onSave: { input in createAsset(input) },
                        onDelete: nil
                    )
                }
            }
            .sheet(item: $pageViewModel.editingRoute) { route in
                if let account = accountForRoute(route) {
                    NavigationStack {
                        AssetEditorView(
                            account: account,
                            onSave: { input in updateAsset(account, input: input) },
                            onDelete: { deleteAsset(account) }
                        )
                    }
                }
            }
            .sheet(isPresented: $pageViewModel.showingFilter) {
                AssetFilterSheet(
                    allAssetOwners: availableAssetOwners,
                    allAssetTags: availableAssetTagNames,
                    selectedOwners: $selectedAssetOwners,
                    selectedTags: $selectedAssetTags
                )
            }
            .sheet(isPresented: $pageViewModel.showingMonthPicker) {
                AssetYearMonthPickerSheet(currentDate: $pageViewModel.monthCursor)
            }
            .alert("삭제할 수 없음", isPresented: Binding(
                get: { pageViewModel.deleteBlockedMessage != nil },
                set: { if !$0 { pageViewModel.deleteBlockedMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(pageViewModel.deleteBlockedMessage ?? "")
            }
            .alert("저장 실패", isPresented: Binding(
                get: { mutationViewModel.saveErrorMessage != nil },
                set: { if !$0 { mutationViewModel.saveErrorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(mutationViewModel.saveErrorMessage ?? "")
            }
            .task {
                await bootstrapHoldingsIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("자산")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    headerIconButton("plus") {
                        pageViewModel.startCreate()
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
                    Text("선택 \(pageViewModel.selectedAssetIDs.count)건")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("선택 삭제", role: .destructive) {
                        deleteSelectedAssets()
                    }
                    .font(AppTypography.body.weight(.semibold))
                    .disabled(pageViewModel.selectedAssetIDs.isEmpty)
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

                    headerIconButton(pageViewModel.groupingMode == .byAccount ? "building.columns" : "square.stack.3d.up") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            pageViewModel.toggleGroupingMode()
                        }
                    }

                    headerIconButton("line.3.horizontal.decrease") {
                        pageViewModel.showingFilter = true
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)

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

                let headerItems = headerCurrencySummaryItems
                if !headerItems.isEmpty {
                    headerCurrencyLine(headerItems)
                        .padding(.horizontal, AppSpacing.pageHorizontal)
                }
            }
            .padding(.vertical, 6)

            Divider().opacity(0.3)
        }
    }

    @ViewBuilder
    private func assetSectionHeader(_ title: String, summaryItems: [CurrencySummaryItem] = []) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !summaryItems.isEmpty {
                HStack(spacing: 8) {
                    ForEach(summaryItems) { item in
                        signedAmountWithCurrency(amount: item.amount, currency: item.currency, font: .system(size: 12))
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .frame(height: 32, alignment: .leading)
        .textCase(nil)
    }

    @ViewBuilder
    private func assetItem(_ asset: Asset) -> some View {
        let expanded = expandedAssetIDs.contains(asset.objectID)
        let detailSections = holdingDetailSections(for: asset)
        let summaryItems = assetSummaryCurrencyItems(for: asset)
        let chips = metadataChipItems(for: asset)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                if pageViewModel.isDeleteSelectionMode {
                    Image(systemName: pageViewModel.selectedAssetIDs.contains(asset.objectID) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(pageViewModel.selectedAssetIDs.contains(asset.objectID) ? AppPalette.yellow : .secondary)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 28, height: 28, alignment: .center)
                        .padding(.trailing, 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(asset.name ?? "이름 없음")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(chips, id: \.self) { chip in
                                    metadataChip(chip)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    HStack(spacing: 10) {
                        if summaryItems.isEmpty {
                            Text("잔액 없음")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summaryItems) { item in
                                signedAmountWithCurrency(amount: item.amount, currency: item.currency, font: .system(size: 12))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            if expanded, !detailSections.isEmpty {
                Divider().opacity(0.2).padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(detailSections) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(section.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                            }

                            ForEach(section.rows) { row in
                                if section.title == "주식" {
                                    HStack(spacing: 6) {
                                        Text(row.title)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.primary)
                                        let qty = row.quantity ?? NSDecimalNumber.zero
                                        let sign = signPrefix(for: qty)
                                        let absValue = absoluteDecimal(qty)
                                        Text("\(sign)\(amountText(absValue))")
                                            .font(.system(size: 13))
                                            .monospacedDigit()
                                            .foregroundStyle(amountColor(for: qty))
                                        Text("주")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Spacer(minLength: 8)
                                        signedAmountWithCurrency(amount: row.amount, currency: row.currency, font: .system(size: 13))
                                    }
                                    .padding(.leading, 14)
                                } else {
                                    HStack(spacing: 8) {
                                        Text(row.title)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 8)
                                        if let trailingNote = row.trailingNote, !trailingNote.isEmpty {
                                            Text(trailingNote)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        signedAmountWithCurrency(amount: row.amount, currency: row.currency, font: .system(size: 13))
                                    }
                                    .padding(.leading, 14)
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if pageViewModel.isDeleteSelectionMode {
                pageViewModel.toggleAssetSelection(asset.objectID)
            } else {
                toggleAssetExpand(asset)
            }
        }
        .onLongPressGesture(minimumDuration: 0.12) {
            if !pageViewModel.isDeleteSelectionMode {
                pageViewModel.startEdit(asset.objectID)
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

    private func accountForRoute(_ route: AssetEditRoute) -> Account? {
        guard let object = try? context.existingObject(with: route.id) else { return nil }
        return object as? Account
    }

    private func createAsset(_ input: AssetEditorInput) -> Bool {
        mutationViewModel.create(input: input, in: context, store: appContainer.store)
    }

    private func updateAsset(_ account: Account, input: AssetEditorInput) -> Bool {
        mutationViewModel.update(account, input: input, in: context, store: appContainer.store)
    }

    private func deleteAsset(_ asset: Asset) {
        let linkedLegCount = ((asset.value(forKey: "legs") as? Set<Leg>) ?? []).count
        if linkedLegCount > 0 {
            pageViewModel.blockDelete(linkedLegCount: linkedLegCount)
            return
        }
        mutationViewModel.delete(asset, in: context, store: appContainer.store)
    }

    private func deleteSelectedAssets() {
        let selected = Array(assets).filter { pageViewModel.selectedAssetIDs.contains($0.objectID) }
        for asset in selected {
            let linkedLegCount = ((asset.value(forKey: "legs") as? Set<Leg>) ?? []).count
            if linkedLegCount > 0 {
                pageViewModel.blockDelete(linkedLegCount: linkedLegCount)
                continue
            }
            mutationViewModel.delete(asset, in: context, store: appContainer.store)
        }
        pageViewModel.finishDeleteSelectionMode()
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }


    private var accountModeSections: [AssetGroupSection] {
        var sections: [AssetGroupSection] = []

        let accountAssets = filteredAssets
            .filter { $0 is Account }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if !accountAssets.isEmpty {
            sections.append(AssetGroupSection(
                title: "계좌",
                assets: accountAssets,
                summaryItems: sectionCurrencySummaryItems(for: accountAssets)
            ))
        }

        let nonAccount = filteredAssets.filter { !($0 is Account) }
        let groupedNonAccount = Dictionary(grouping: nonAccount, by: assetGroupTitle(for:))
        let order = ["부동산", "코인", "기타"]
        let tail = groupedNonAccount
            .map { key, values in
                let sorted = values.sorted { ($0.name ?? "") < ($1.name ?? "") }
                return AssetGroupSection(
                    title: key,
                    assets: sorted,
                    summaryItems: sectionCurrencySummaryItems(for: sorted)
                )
            }
            .sorted { lhs, rhs in
                let li = order.firstIndex(of: lhs.title) ?? Int.max
                let ri = order.firstIndex(of: rhs.title) ?? Int.max
                return li == ri ? lhs.title < rhs.title : li < ri
            }
        sections.append(contentsOf: tail)
        return sections
    }

    private var assetModeSections: [AssetAggregateSection] {
        let accountAssets = filteredAssets.filter { $0 is Account }
        let records = holdingRecords(from: accountAssets)
        var sections: [AssetAggregateSection] = []

        let cashSectionItems: [AssetAggregateItem] = {
            let byCurrency = Dictionary(grouping: records.filter { $0.kind == .cash }, by: { $0.code })
            return byCurrency.keys.sorted().map { currency in
                let items = byCurrency[currency] ?? []
                let total = items.reduce(NSDecimalNumber.zero) { $0.adding($1.quantity) }
                let children = Dictionary(grouping: items, by: { $0.assetName })
                    .map { name, list in
                        AssetAggregateChild(
                            title: name,
                            amount: list.reduce(NSDecimalNumber.zero) { $0.adding($1.quantity) },
                            currency: currency
                        )
                    }
                    .sorted { $0.title < $1.title }
                return AssetAggregateItem(
                    id: "cash:\(currency)",
                    title: currency,
                    amount: total,
                    currency: currency,
                    children: children
                )
            }
        }()
        if !cashSectionItems.isEmpty {
            sections.append(AssetAggregateSection(
                title: "현금",
                items: cashSectionItems,
                summaryItems: cashSectionItems.map { CurrencySummaryItem(currency: $0.currency, amount: $0.amount) }
            ))
        }

        let stockSectionItems: [AssetAggregateItem] = {
            let byTicker = Dictionary(grouping: records.filter { $0.kind == .stock }, by: { $0.code })
            return byTicker.keys.sorted().map { ticker in
                let items = byTicker[ticker] ?? []
                let currency = items.first?.currency ?? "KRW"
                let total = items.reduce(NSDecimalNumber.zero) { $0.adding($1.marketValue) }
                let children = Dictionary(grouping: items, by: { $0.assetName })
                    .map { name, list in
                        AssetAggregateChild(
                            title: name,
                            amount: list.reduce(NSDecimalNumber.zero) { $0.adding($1.marketValue) },
                            currency: currency
                        )
                    }
                    .sorted { $0.title < $1.title }
                return AssetAggregateItem(
                    id: "stock:\(ticker)",
                    title: ticker,
                    amount: total,
                    currency: currency,
                    children: children
                )
            }
        }()
        if !stockSectionItems.isEmpty {
            let stockSummaryBuckets = stockSectionItems.reduce(into: [String: NSDecimalNumber]()) { partial, item in
                partial[item.currency] = (partial[item.currency] ?? NSDecimalNumber.zero).adding(item.amount)
            }
            let stockSummaryItems = stockSummaryBuckets
                .map { CurrencySummaryItem(currency: $0.key, amount: $0.value) }
                .sorted { $0.currency < $1.currency }
            sections.append(AssetAggregateSection(
                title: "주식",
                items: stockSectionItems,
                summaryItems: stockSummaryItems
            ))
        }

        let realEstateAssets = filteredAssets
            .filter { assetGroupTitle(for: $0) == "부동산" }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if !realEstateAssets.isEmpty {
            let items = realEstateAssets.map { asset in
                AssetAggregateItem(
                    id: "estate:\(asset.objectID.uriRepresentation().absoluteString)",
                    title: asset.name ?? "부동산",
                    amount: NSDecimalNumber.zero,
                    currency: "KRW",
                    children: []
                )
            }
            sections.append(AssetAggregateSection(
                title: "부동산",
                items: items,
                summaryItems: []
            ))
        }

        return sections
    }

    private var isCurrentModeEmpty: Bool {
        pageViewModel.groupingMode == .byAccount ? accountModeSections.isEmpty : assetModeSections.isEmpty
    }

    private var filteredAssets: [Asset] {
        Array(assets).filter(matchesFilter)
    }

    private func monthEndDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return nextStart.addingTimeInterval(-1)
    }

    private func matchesFilter(_ asset: Asset) -> Bool {
        let owner = ownerText(for: asset)
        let tagNames = assetTagNames(for: asset)

        if !selectedAssetOwners.isEmpty && !selectedAssetOwners.contains(owner) { return false }
        if !selectedAssetTags.isEmpty && selectedAssetTags.isDisjoint(with: tagNames) { return false }
        return true
    }

    private var hasActiveFilters: Bool {
        !selectedAssetOwners.isEmpty || !selectedAssetTags.isEmpty
    }

    private var filterSummaryText: String {
        var parts: [String] = []
        if !selectedAssetOwners.isEmpty { parts.append("소유주 \(selectedAssetOwners.sorted().joined(separator: ", "))") }
        if !selectedAssetTags.isEmpty { parts.append("태그 \(selectedAssetTags.sorted().joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }

    private var availableAssetOwners: [String] {
        Array(Set(assets.map(ownerText(for:)))).sorted()
    }

    private var availableAssetTagNames: [String] {
        Array(Set(assets.flatMap { assetTagNames(for: $0) })).sorted()
    }

    private func assetTagNames(for asset: Asset) -> [String] {
        let joins = (asset.tags as? Set<AssetTag>) ?? []
        return joins.compactMap { $0.tag?.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func ownerText(for asset: Asset) -> String {
        if let owner = dynamicStringValue(asset, key: "owner")?.trimmingCharacters(in: .whitespacesAndNewlines), !owner.isEmpty {
            return owner
        }
        return "소유주 없음"
    }

    private func institutionText(for asset: Asset) -> String {
        if let account = asset as? Account, let inst = account.institution?.trimmingCharacters(in: .whitespacesAndNewlines), !inst.isEmpty {
            return inst
        }
        return "기관 없음"
    }

    private func assetGroupTitle(for asset: Asset) -> String {
        if asset is Account {
            return "계좌"
        }
        let name = (asset.entity.name ?? "").lowercased()
        if name.contains("real") || name.contains("estate") {
            return "부동산"
        }
        if name.contains("coin") || name.contains("crypto") {
            return "코인"
        }
        return "기타"
    }

    private func accountGroupTitle(for asset: Asset) -> String {
        guard let account = asset as? Account else { return "기타" }
        switch account.type {
        case AssetClassOption.bank.rawValue: return "은행"
        case AssetClassOption.brokerage.rawValue: return "증권"
        default: return "기타"
        }
    }

    private func createdAt(of object: NSManagedObject) -> Date? {
        guard object.entity.attributesByName["createdAt"] != nil else { return nil }
        return object.value(forKey: "createdAt") as? Date
    }

    private func monthText(_ date: Date) -> String {
        Self.monthFormatter.string(from: date)
    }

    private func assetSummaryCurrencyItems(for asset: Asset) -> [CurrencySummaryItem] {
        guard asset.entity.relationshipsByName["holdings"] != nil else { return [] }
        guard let holdings = asset.value(forKey: "holdings") as? Set<NSManagedObject>, !holdings.isEmpty else { return [] }

        var cashBuckets: [String: NSDecimalNumber] = [:]

        for holding in holdings {
            guard let instrument = holding.value(forKey: "instrument") as? NSManagedObject else { continue }
            let kindRaw = (instrument.value(forKey: "kind") as? Int16) ?? InstrumentKind.other.rawValue
            let kind = InstrumentKind(rawValue: kindRaw) ?? .other
            let code = ((instrument.value(forKey: "code") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let key = code.isEmpty ? "-" : code
            let quantity = (holding.value(forKey: "quantity") as? NSDecimalNumber) ?? NSDecimalNumber.zero

            switch kind {
            case .cash:
                cashBuckets[key] = (cashBuckets[key] ?? NSDecimalNumber.zero).adding(quantity)
            default:
                break
            }
        }

        return cashBuckets
            .sorted { $0.key < $1.key }
            .map { key, value in
                CurrencySummaryItem(currency: key, amount: value)
            }
    }

    private func holdingDetailSections(for asset: Asset) -> [AssetHoldingSection] {
        guard asset.entity.relationshipsByName["holdings"] != nil else { return [] }
        guard let holdings = asset.value(forKey: "holdings") as? Set<NSManagedObject>, !holdings.isEmpty else { return [] }

        var cashBuckets: [String: NSDecimalNumber] = [:]
        var stockBuckets: [String: (quantity: NSDecimalNumber, marketValue: NSDecimalNumber, currency: String)] = [:]

        for holding in holdings {
            guard let instrument = holding.value(forKey: "instrument") as? NSManagedObject else { continue }
            let kindRaw = (instrument.value(forKey: "kind") as? Int16) ?? InstrumentKind.other.rawValue
            let kind = InstrumentKind(rawValue: kindRaw) ?? .other
            let code = ((instrument.value(forKey: "code") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let key = code.isEmpty ? "-" : code
            let quantity = (holding.value(forKey: "quantity") as? NSDecimalNumber) ?? NSDecimalNumber.zero

            switch kind {
            case .cash:
                cashBuckets[key] = (cashBuckets[key] ?? NSDecimalNumber.zero).adding(quantity)
            case .stock:
                let quoteCurrency = ((instrument.value(forKey: "quoteCurrency") as? String) ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let marketValue = (holding.value(forKey: "marketValue") as? NSDecimalNumber) ?? NSDecimalNumber.zero
                let prev = stockBuckets[key] ?? (NSDecimalNumber.zero, NSDecimalNumber.zero, quoteCurrency.isEmpty ? "KRW" : quoteCurrency)
                stockBuckets[key] = (
                    quantity: prev.quantity.adding(quantity),
                    marketValue: prev.marketValue.adding(marketValue),
                    currency: prev.currency
                )
            default:
                continue
            }
        }

        var sections: [AssetHoldingSection] = []

        let cashRows = cashBuckets.sorted { $0.key < $1.key }.map { key, value in
            AssetHoldingRow(title: key, amount: value, currency: key, trailingNote: nil, quantity: nil)
        }
        if !cashRows.isEmpty {
            sections.append(AssetHoldingSection(title: "현금", headerNote: nil, rows: cashRows))
        }

        let stockRows = stockBuckets.sorted { $0.key < $1.key }.map { key, value in
            AssetHoldingRow(
                title: key,
                amount: value.marketValue,
                currency: value.currency,
                trailingNote: nil,
                quantity: value.quantity
            )
        }
        if !stockRows.isEmpty {
            sections.append(AssetHoldingSection(title: "주식", headerNote: nil, rows: stockRows))
        }

        return sections
    }

    @ViewBuilder
    private func signedAmountWithCurrency(amount: NSDecimalNumber, currency: String, font: Font) -> some View {
        let sign = signPrefix(for: amount)
        let absValue = absoluteDecimal(amount)
        HStack(spacing: 3) {
            Text("\(sign)\(amountText(absValue))")
                .font(font)
                .monospacedDigit()
                .foregroundStyle(amountColor(for: amount))
            Text(currency)
                .font(font)
                .foregroundStyle(.secondary)
        }
    }

    private func amountColor(for value: NSDecimalNumber) -> Color {
        switch value.compare(NSDecimalNumber.zero) {
        case .orderedDescending:
            return AppPalette.red
        case .orderedAscending:
            return AppPalette.blue
        default:
            return .primary
        }
    }

    private func signPrefix(for value: NSDecimalNumber) -> String {
        switch value.compare(NSDecimalNumber.zero) {
        case .orderedDescending:
            return ""
        case .orderedAscending:
            return "-"
        default:
            return ""
        }
    }

    private func absoluteDecimal(_ value: NSDecimalNumber) -> NSDecimalNumber {
        value.compare(NSDecimalNumber.zero) == .orderedAscending ? value.multiplying(by: NSDecimalNumber(value: -1)) : value
    }

    @ViewBuilder
    private func metadataChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            )
    }

    private func metadataChipItems(for asset: Asset) -> [String] {
        var items: [String] = []
        let owner = ownerText(for: asset)
        if owner != "소유주 없음" { items.append(owner) }
        let institution = institutionText(for: asset)
        if institution != "기관 없음" { items.append(institution) }
        let tags = assetTagNames(for: asset).sorted()
        items.append(contentsOf: tags.prefix(3))
        if items.isEmpty { items.append("정보 없음") }
        return items
    }

    private func toggleAssetExpand(_ asset: Asset) {
        if expandedAssetIDs.contains(asset.objectID) {
            expandedAssetIDs.remove(asset.objectID)
        } else {
            expandedAssetIDs.insert(asset.objectID)
        }
    }

    @ViewBuilder
    private func aggregateItemView(_ item: AssetAggregateItem, sectionTitle: String) -> some View {
        let expanded = expandedAggregateItemIDs.contains(item.id)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                signedAmountWithCurrency(amount: item.amount, currency: item.currency, font: .system(size: 13))
            }

            if expanded, !item.children.isEmpty {
                Divider().opacity(0.2).padding(.vertical, 8)
                VStack(spacing: 0) {
                    ForEach(item.children) { child in
                        HStack(spacing: 8) {
                            Text(child.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            signedAmountWithCurrency(amount: child.amount, currency: child.currency, font: .system(size: 13))
                        }
                        .padding(.leading, 14)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if item.children.isEmpty { return }
            if expandedAggregateItemIDs.contains(item.id) {
                expandedAggregateItemIDs.remove(item.id)
            } else {
                expandedAggregateItemIDs.insert(item.id)
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

    private func holdingRecords(from assets: [Asset]) -> [HoldingRecord] {
        guard !assets.isEmpty else { return [] }

        struct HoldingKey: Hashable {
            let assetID: NSManagedObjectID
            let kind: InstrumentKind
            let code: String
            let currency: String
        }

        let endOfMonth = monthEndDate(pageViewModel.monthCursor)
        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.objectID, $0) })
        let assetIDSet = Set(assetMap.keys)

        var buckets: [HoldingKey: (quantity: NSDecimalNumber, marketValue: NSDecimalNumber)] = [:]

        let txs = Array(transactions)
            .filter { tx in
                let date = tx.date ?? createdAt(of: tx) ?? Date.distantPast
                return date <= endOfMonth
            }
            .sorted {
                let l = $0.date ?? createdAt(of: $0) ?? Date.distantPast
                let r = $1.date ?? createdAt(of: $1) ?? Date.distantPast
                if l == r { return $0.order < $1.order }
                return l < r
            }

        for tx in txs {
            let txCurrency = transactionBaseCurrency(tx)
            let legs = ((tx.legs as? Set<Leg>) ?? []).sorted { $0.order < $1.order }
            for leg in legs {
                guard let asset = leg.asset, assetIDSet.contains(asset.objectID) else { continue }

                if let cash = leg as? CashLeg {
                    let currency = normalizedCurrency(cash.currency)
                    let amount = cash.amount ?? NSDecimalNumber.zero
                    let signed = leg.directionEnum == .in ? amount : amount.multiplying(by: NSDecimalNumber(value: -1))
                    let key = HoldingKey(assetID: asset.objectID, kind: .cash, code: currency, currency: currency)
                    let prev = buckets[key] ?? (NSDecimalNumber.zero, NSDecimalNumber.zero)
                    buckets[key] = (prev.quantity.adding(signed), prev.marketValue.adding(signed))
                    continue
                }

                if let position = leg as? PositionLeg {
                    let ticker = (position.ticker ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !ticker.isEmpty else { continue }
                    let quantity = position.quantity ?? NSDecimalNumber.zero
                    let signedQty = leg.directionEnum == .in ? quantity : quantity.multiplying(by: NSDecimalNumber(value: -1))
                    let price = position.price ?? NSDecimalNumber.zero
                    let signedValue = signedQty.multiplying(by: price)
                    let key = HoldingKey(assetID: asset.objectID, kind: .stock, code: ticker, currency: txCurrency)
                    let prev = buckets[key] ?? (NSDecimalNumber.zero, NSDecimalNumber.zero)
                    buckets[key] = (prev.quantity.adding(signedQty), prev.marketValue.adding(signedValue))
                }
            }
        }

        return buckets
            .map { key, value in
                let assetName = (assetMap[key.assetID]?.name ?? "이름 없음").trimmingCharacters(in: .whitespacesAndNewlines)
                return HoldingRecord(
                    assetID: key.assetID,
                    assetName: assetName.isEmpty ? "이름 없음" : assetName,
                    kind: key.kind,
                    code: key.code,
                    currency: key.currency,
                    quantity: value.quantity,
                    marketValue: value.marketValue
                )
            }
            .sorted {
                if $0.assetName == $1.assetName {
                    if $0.kind == $1.kind { return $0.code < $1.code }
                    return $0.kind.rawValue < $1.kind.rawValue
                }
                return $0.assetName < $1.assetName
            }
    }

    private func normalizedCurrency(_ value: String?) -> String {
        let currency = (value ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return currency.isEmpty ? "KRW" : currency
    }

    private func transactionBaseCurrency(_ tx: Transaction) -> String {
        if tx.entity.attributesByName["baseCurrency"] != nil,
           let base = tx.value(forKey: "baseCurrency") as? String {
            return normalizedCurrency(base)
        }
        return "KRW"
    }

    private func assetClassText(_ raw: Int16) -> String {
        AssetClassOption(rawValue: raw)?.title ?? AssetClassOption.other.title
    }

    private var headerCurrencySummaryItems: [CurrencySummaryItem] {
        var buckets: [String: NSDecimalNumber] = [:]
        let records = holdingRecords(from: filteredAssets)
        for record in records {
            switch record.kind {
            case .cash:
                buckets[record.currency] = (buckets[record.currency] ?? NSDecimalNumber.zero).adding(record.quantity)
            case .stock:
                buckets[record.currency] = (buckets[record.currency] ?? NSDecimalNumber.zero).adding(record.marketValue)
            default:
                continue
            }
        }

        return buckets
            .map { CurrencySummaryItem(currency: $0.key, amount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.currency == "KRW" { return true }
                if rhs.currency == "KRW" { return false }
                if lhs.currency == "USD" { return true }
                if rhs.currency == "USD" { return false }
                return lhs.currency < rhs.currency
            }
    }

    private func sectionCurrencySummaryItems(for assets: [Asset]) -> [CurrencySummaryItem] {
        guard !assets.isEmpty else { return [] }
        var buckets: [String: NSDecimalNumber] = [:]
        let records = holdingRecords(from: assets)
        for record in records {
            switch record.kind {
            case .cash:
                buckets[record.currency] = (buckets[record.currency] ?? NSDecimalNumber.zero).adding(record.quantity)
            case .stock:
                buckets[record.currency] = (buckets[record.currency] ?? NSDecimalNumber.zero).adding(record.marketValue)
            default:
                continue
            }
        }

        return buckets
            .map { CurrencySummaryItem(currency: $0.key, amount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.currency == "KRW" { return true }
                if rhs.currency == "KRW" { return false }
                if lhs.currency == "USD" { return true }
                if rhs.currency == "USD" { return false }
                return lhs.currency < rhs.currency
            }
    }

    @ViewBuilder
    private func headerCurrencyLine(_ items: [CurrencySummaryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    signedAmountWithCurrency(amount: item.amount, currency: item.currency, font: .system(size: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func headerIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(AssetHeaderIconButtonStyle())
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f
    }()

    private func amountText(_ value: NSDecimalNumber) -> String {
        Self.amountFormatter.string(from: value) ?? value.stringValue
    }

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    private func bootstrapHoldingsIfNeeded() async {
        guard !didBootstrapHoldings else { return }
        didBootstrapHoldings = true
        do {
            try appContainer.store.performBackgroundSave { background in
                let rebuild = HoldingRebuildUseCase(context: background)
                try rebuild.rebuildAll()
            }
            context.performAndWait {
                context.processPendingChanges()
                context.refreshAllObjects()
            }
        } catch {
#if DEBUG
            print("[AssetsPage] holding bootstrap failed: \(error)")
#endif
        }
    }
}

private struct AssetEditorView: View {
    let account: Account?
    let onSave: (AssetEditorInput) -> Bool
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var owner = ""
    @State private var institution = ""
    @State private var accountNumber = ""
    @State private var note = ""
    @State private var tagsText = ""
    @State private var selectedClass: AssetClassOption = .bank
    @State private var isActive = true

    private var institutionOptions: [String] {
        let base = InstitutionCatalog.names(forAssetClass: selectedClass.rawValue)
        let current = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty && !base.contains(current) {
            return ([current] + base).sorted()
        }
        return base
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                lineSection {
                    lineRow("이름") {
                        TextField("자산 이름", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    lineRow("소유주") {
                        TextField("소유주", text: $owner)
                            .multilineTextAlignment(.trailing)
                    }
                    lineRow("기관") {
                        Picker("기관", selection: $institution) {
                            Text("선택 안함").tag("")
                            ForEach(institutionOptions, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppPalette.green)
                    }
                    lineRow("계좌번호") {
                        TextField("계좌번호", text: $accountNumber)
                            .multilineTextAlignment(.trailing)
                    }
                    lineRow("자산 분류") {
                        Picker("자산 분류", selection: $selectedClass) {
                            ForEach(AssetClassOption.selectableCases) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppPalette.green)
                    }
                    lineRow("태그") {
                        TextField("쉼표로 구분", text: $tagsText)
                            .multilineTextAlignment(.trailing)
                    }
                    lineRow("사용 여부") {
                        Toggle("", isOn: $isActive)
                            .labelsHidden()
                    }
                    lineRow("메모") {
                        TextField("메모", text: $note)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if let onDelete {
                    lineSection {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("삭제")
                                .font(AppTypography.body)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(account == nil ? "자산 생성" : "자산 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    let saved = onSave(AssetEditorInput(
                        name: resolvedName,
                        owner: owner,
                        institution: institution,
                        accountNumber: accountNumber,
                        note: note,
                        tagsText: tagsText,
                        assetClass: selectedClass.rawValue,
                        isActive: isActive
                    ))
                    if saved {
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: loadInitialValue)
        .onChange(of: selectedClass) { _, newClass in
            let allowed = Set(InstitutionCatalog.names(forAssetClass: newClass.rawValue))
            let current = institution.trimmingCharacters(in: .whitespacesAndNewlines)
            if !current.isEmpty && !allowed.contains(current) {
                institution = ""
            }
        }
    }

    private var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "이름 없는 자산" : trimmed
    }

    private func loadInitialValue() {
        guard let account else { return }
        name = account.name ?? ""
        owner = dynamicStringValue(account, key: "owner") ?? ""
        institution = account.institution ?? ""
        accountNumber = account.accountNumber ?? ""
        note = account.note ?? ""
        selectedClass = AssetClassOption(rawValue: account.type) ?? .other
        isActive = account.isActive

        let joins = (account.tags as? Set<AssetTag>) ?? []
        let manualNames = joins
            .compactMap { $0.tag?.name }
            .sorted()
        tagsText = manualNames.joined(separator: ", ")
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }

    @ViewBuilder
    private func lineSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, AppSpacing.pageHorizontal - 2)
        .padding(.vertical, AppSpacing.sectionVertical)
    }

    @ViewBuilder
    private func lineRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                Spacer()
                content()
                    .font(AppTypography.body)
            }
            .padding(.vertical, AppSpacing.rowVertical)
            Divider().opacity(0.35)
        }
    }
}

private struct AssetFilterSheet: View {
    let allAssetOwners: [String]
    let allAssetTags: [String]

    @Binding var selectedOwners: Set<String>
    @Binding var selectedTags: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                filterCategory(title: "소유주", options: allAssetOwners, selected: $selectedOwners)
                filterCategory(title: "태그", options: allAssetTags, selected: $selectedTags)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("전체") {
                        selectedOwners = []
                        selectedTags = []
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filterCategory(title: String, options: [String], selected: Binding<Set<String>>) -> some View {
        Section(title) {
            if options.isEmpty {
                Text("항목 없음")
                    .foregroundStyle(.secondary)
            } else {
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
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected.wrappedValue.contains(item) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppPalette.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AssetYearMonthPickerSheet: View {
    @Binding var currentDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Picker("연도", selection: $year) {
                        ForEach(2000...2100, id: \.self) { y in
                            Text("\(y)년").tag(y)
                        }
                    }
                    Picker("월", selection: $month) {
                        ForEach(1...12, id: \.self) { m in
                            Text("\(m)월").tag(m)
                        }
                    }
                }
                .pickerStyle(.wheel)
                Spacer()
            }
            .padding()
            .navigationTitle("연월 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("확인") {
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: currentDate)
                        comps.year = year
                        comps.month = month
                        comps.day = 1
                        if let date = Calendar.current.date(from: comps) {
                            currentDate = date
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                year = Calendar.current.component(.year, from: currentDate)
                month = Calendar.current.component(.month, from: currentDate)
            }
        }
    }
}

private struct AssetHeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.16) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
