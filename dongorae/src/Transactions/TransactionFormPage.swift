import SwiftUI
import CoreData

extension TransactionType {
    func makeDrafts(defaultAssetID: NSManagedObjectID?) -> [LegDraft] {
        func requiredCash(_ direction: LegDirection, role: LegRole, currency: String = "KRW") -> LegDraft {
            var leg = LegDraft.cashDefault(assetID: defaultAssetID)
            leg.role = role
            leg.direction = direction
            leg.currency = currency
            leg.isRequired = true
            return leg
        }

        func requiredPosition(_ direction: LegDirection, role: LegRole) -> LegDraft {
            var leg = LegDraft.positionDefault(assetID: defaultAssetID)
            leg.role = role
            leg.direction = direction
            leg.isRequired = true
            return leg
        }

        switch self {
        case .income:
            return [requiredCash(.in, role: .income)]

        case .expense:
            return [requiredCash(.out, role: .expense)]

        case .transfer:
            return [
                requiredCash(.in, role: .income),
                requiredCash(.out, role: .expense)
            ]

        case .exchange:
            return [
                requiredCash(.in, role: .income, currency: "USD"),
                requiredCash(.out, role: .expense, currency: "KRW")
            ]

        case .buy:
            return [
                requiredCash(.out, role: .expense),
                requiredPosition(.in, role: .positionIn)
            ]

        case .sell:
            return [
                requiredCash(.in, role: .income),
                requiredPosition(.out, role: .positionOut)
            ]

        case .dividend:
            return [requiredCash(.in, role: .income)]

        case .move:
            return [
                requiredPosition(.in, role: .positionIn),
                requiredPosition(.out, role: .positionOut)
            ]
        case .positionIn:
            return [requiredPosition(.in, role: .positionIn)]
        case .positionOut:
            return [requiredPosition(.out, role: .positionOut)]
        }
    }

    static func infer(from drafts: [LegDraft]) -> TransactionType {
        let requireds = drafts.filter(\.isRequired)
        let cash = requireds.filter { $0.kind == .cash }
        let pos = requireds.filter { $0.kind == .position }
        let hasInCash = cash.contains { $0.direction == .in }
        let hasOutCash = cash.contains { $0.direction == .out }
        let hasInPos = pos.contains { $0.direction == .in }
        let hasOutPos = pos.contains { $0.direction == .out }
        let inCurrencies = Set(cash.filter { $0.direction == .in }.map { normalizedCurrency($0.currency) })
        let outCurrencies = Set(cash.filter { $0.direction == .out }.map { normalizedCurrency($0.currency) })
        let isExchange = hasInCash && hasOutCash && inCurrencies.contains { inCode in
            outCurrencies.contains { outCode in inCode != outCode }
        }

        if hasInPos && hasOutCash && !hasOutPos { return .buy }
        if hasOutPos && hasInCash && !hasInPos { return .sell }
        if hasInPos && hasOutPos { return .move }
        if hasInPos { return .positionIn }
        if hasOutPos { return .positionOut }
        if isExchange { return .exchange }
        if hasInCash && hasOutCash { return .transfer }
        if hasInCash { return .income }
        return .expense
    }

    private static func normalizedCurrency(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "KRW" : trimmed
    }
}

func roleCandidates(for kind: LegDraftKind) -> [LegRole] {
    switch kind {
    case .cash:
        return [.income, .expense]
    case .position:
        return [.positionIn, .positionOut]
    }
}

struct TransactionEditorView: View {
    let transaction: Transaction?
    let assets: [Asset]
    let onSave: (TransactionEditorInput) -> Bool
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FetchRequest(fetchRequest: Self.categoryRequest())
    private var categories: FetchedResults<NSManagedObject>

    @State private var titleText: String = ""
    @State private var date: Date = Date()
    @State private var executionDate: Date = Date()
    @State private var selectedCategoryID: NSManagedObjectID?
    @State private var dividendTicker: String = ""
    @State private var stockTicker: String = ""
    @State private var stockMarket: String = ""
    @State private var memoText: String = ""
    @State private var txTagsText: String = ""

    @State private var selectedTemplate: TransactionType = .expense
    @State private var legs: [LegDraft] = []
    @State private var editingDraftRoute: DraftEditRoute?
    @State private var showingDatePicker = false
    @State private var showingExecutionDatePicker = false
    @State private var suppressTemplateApply = false

    private static func categoryRequest() -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TransactionCategory")
        request.sortDescriptors = [
            NSSortDescriptor(key: "parent", ascending: true),
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return request
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                lineSection {
                    lineRow("거래 유형") {
                        Picker("거래 유형", selection: $selectedTemplate) {
                            ForEach(TransactionType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppPalette.green)
                        .foregroundStyle(AppPalette.green)
                    }

                    lineRow("제목") {
                        TextField("거래 제목", text: $titleText)
                            .multilineTextAlignment(.trailing)
                    }

                    lineRow("카테고리") {
                        Picker("카테고리", selection: $selectedCategoryID) {
                            Text("미분류").tag(Optional<NSManagedObjectID>.none)
                            ForEach(categoryPickerItems, id: \.id) { item in
                                Text(item.label).tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppPalette.green)
                    }

                    lineRow("날짜") {
                        Button {
                            showingDatePicker = true
                        } label: {
                            Text(koreanDateText(date))
                                .foregroundStyle(AppPalette.green)
                        }
                        .buttonStyle(.plain)
                    }

                    if showsExecutionDate {
                        lineRow("체결일") {
                            Button {
                                showingExecutionDatePicker = true
                            } label: {
                                Text(koreanDateText(executionDate))
                                    .foregroundStyle(AppPalette.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isStockTransactionType {
                        lineRow("시장") {
                            TextField("예: NASDAQ", text: $stockMarket)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                        }
                        lineRow("티커") {
                            TextField("예: AAPL", text: $stockTicker)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if selectedTemplate == .exchange {
                        lineRow("환율") {
                            Text(exchangeRatePreviewText)
                                .foregroundStyle(AppPalette.yellow)
                        }
                    }

                    if selectedTemplate == .buy || selectedTemplate == .sell {
                        lineRow("평단") {
                            Text(averagePricePreviewText)
                                .foregroundStyle(AppPalette.yellow)
                        }
                    }

                    lineRow("내용") {
                        TextField("메모", text: $memoText)
                            .multilineTextAlignment(.trailing)
                    }

                    lineRow("태그") {
                        TextField("쉼표로 구분", text: $txTagsText)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }

                    lineLabel("세부 거래 내역")
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    if legs.isEmpty {
                        Text("세부 거래 항목이 없습니다")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }

                    VStack(spacing: 0) {
                        ForEach($legs) { $draft in
                            HStack(spacing: 8) {
                                Button {
                                    editingDraftRoute = DraftEditRoute(id: draft.id)
                                } label: {
                                    LegDraftSummaryRow(draft: draft, assets: assets)
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    legs.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.body)
                                        .foregroundStyle(canDelete(draft) ? Color.red : Color.secondary.opacity(0.45))
                                }
                                .buttonStyle(.plain)
                                .disabled(!canDelete(draft))
                            }

                            if draft.id != legs.last?.id {
                                Divider().opacity(0.25)
                            }
                        }
                    }
                    .padding(.leading, 12)

                    Button {
                        addManualCashLeg()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("항목 추가")
                            Spacer()
                        }
                        .font(.body)
                        .padding(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }

                if !validationResult.isValid {
                    Text(validationResult.message)
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }

                if let onDelete {
                    lineSection {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("삭제")
                                .font(.body)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(transaction == nil ? "거래 생성" : "거래 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: loadInitialValues)
        .onChange(of: selectedTemplate) { _, newValue in
            guard !suppressTemplateApply else { return }
            applyTemplate(newValue)
            synchronizeAutoTradeCash()
            if !showsExecutionDate {
                executionDate = date
            }
        }
        .onChange(of: legs) { _, _ in
            synchronizeAutoTradeCash()
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet(title: "날짜 선택", selection: $date)
        }
        .sheet(isPresented: $showingExecutionDatePicker) {
            datePickerSheet(title: "체결일 선택", selection: $executionDate)
        }
        .sheet(item: $editingDraftRoute) { route in
            if let binding = bindingForDraft(route.id) {
                NavigationStack {
                    LegDraftEditorView(
                        draft: binding,
                        assets: assets,
                        transactionType: selectedTemplate,
                        fixedTicker: stockTicker,
                        fixedMarket: stockMarket
                    )
                }
            }
        }
    }

    private var canSave: Bool {
        validateDrafts().isValid
    }

    private var validationResult: ValidationResult {
        validateDrafts()
    }

    private var showsExecutionDate: Bool {
        switch selectedTemplate {
        case .buy, .sell, .dividend, .move:
            return true
        default:
            return false
        }
    }

    private var isStockTransactionType: Bool {
        switch selectedTemplate {
        case .buy, .sell, .dividend, .move, .positionIn, .positionOut:
            return true
        default:
            return false
        }
    }

    private var categoryPickerItems: [(id: NSManagedObjectID, label: String)] {
        let all = Array(categories)
        let roots = all
            .filter { ($0.value(forKey: "parent") as? NSManagedObject) == nil }
            .sorted { lhs, rhs in
                let lOrder = lhs.value(forKey: "order") as? Int16 ?? 0
                let rOrder = rhs.value(forKey: "order") as? Int16 ?? 0
                if lOrder != rOrder { return lOrder < rOrder }
                let lTitle = lhs.value(forKey: "title") as? String ?? ""
                let rTitle = rhs.value(forKey: "title") as? String ?? ""
                return lTitle < rTitle
            }

        var items: [(NSManagedObjectID, String)] = []
        for root in roots {
            let rootIcon = ((root.value(forKey: "icon") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rootTitle = ((root.value(forKey: "title") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rootLabel = "\(rootIcon.isEmpty ? "📁" : rootIcon) \(rootTitle)"
            items.append((root.objectID, rootLabel))

            let children = ((root.value(forKey: "children") as? Set<NSManagedObject>) ?? [])
                .sorted { lhs, rhs in
                    let lOrder = lhs.value(forKey: "order") as? Int16 ?? 0
                    let rOrder = rhs.value(forKey: "order") as? Int16 ?? 0
                    if lOrder != rOrder { return lOrder < rOrder }
                    let lTitle = lhs.value(forKey: "title") as? String ?? ""
                    let rTitle = rhs.value(forKey: "title") as? String ?? ""
                    return lTitle < rTitle
                }
            for child in children {
                let icon = ((child.value(forKey: "icon") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let title = ((child.value(forKey: "title") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let label = "  \(icon.isEmpty ? "📄" : icon) \(title)"
                items.append((child.objectID, label))
            }
        }
        return items
    }

    private var exchangeRatePreviewText: String {
        guard let rate = inferredExchangeRate(from: legs) else { return "자동 계산" }
        return amountText(rate)
    }

    private var averagePricePreviewText: String {
        guard let average = inferredAveragePrice(from: legs, type: selectedTemplate) else { return "자동 계산" }
        return amountText(average)
    }

    private func canDelete(_ draft: LegDraft) -> Bool {
        if draft.isRequired { return false }
        let candidate = legs.filter { $0.id != draft.id }
        guard !candidate.isEmpty else { return false }
        return validateDrafts(drafts: candidate).isValid
    }

    private func loadInitialValues() {
        guard let transaction else {
            applyTemplate(selectedTemplate)
            synchronizeAutoTradeCash()
            return
        }

        date = transaction.date ?? Date()
        executionDate = transaction.executionDate ?? date
        selectedCategoryID = (transaction.value(forKey: "category") as? NSManagedObject)?.objectID
        dividendTicker = dynamicStringValue(transaction, key: "dividendTicker") ?? ""
        stockTicker = dynamicStringValue(transaction, key: "ticker") ?? ""
        stockMarket = dynamicStringValue(transaction, key: "market") ?? ""
        if stockTicker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stockTicker = dividendTicker
        }
        titleText = transaction.title ?? ""
        memoText = transaction.memo ?? ""

        if let joins = transaction.tags as? Set<TransactionTag> {
            txTagsText = joins
                .compactMap { $0.tag?.name }
                .sorted()
                .joined(separator: ", ")
        }

        let existingLegs = ((transaction.legs as? Set<Leg>) ?? []).sorted { $0.order < $1.order }
        legs = existingLegs.map { draft(from: $0) }
        if legs.isEmpty {
            applyTemplate(.expense)
        } else {
            suppressTemplateApply = true
            if dynamicDecimalValue(transaction, key: "fxRate") != nil {
                selectedTemplate = .exchange
            } else if let ticker = dynamicStringValue(transaction, key: "dividendTicker")?.trimmingCharacters(in: .whitespacesAndNewlines), !ticker.isEmpty {
                selectedTemplate = .dividend
            } else {
                selectedTemplate = .infer(from: legs)
            }
            DispatchQueue.main.async { suppressTemplateApply = false }
        }
        synchronizeAutoTradeCash()
    }

    private func applyTemplate(_ template: TransactionType) {
        let defaultAssetID = assets.first?.objectID
        legs = template.makeDrafts(defaultAssetID: defaultAssetID)
    }

    private func synchronizeAutoTradeCash() {
        guard selectedTemplate == .buy || selectedTemplate == .sell else { return }
        guard let cashIndex = legs.firstIndex(where: {
            $0.isRequired &&
            $0.kind == .cash &&
            (
                (selectedTemplate == .buy && $0.role == .expense && $0.direction == .out) ||
                (selectedTemplate == .sell && $0.role == .income && $0.direction == .in)
            )
        }) else {
            return
        }

        let positionDirection: LegDirection = selectedTemplate == .buy ? .in : .out
        let targets = legs.filter { $0.kind == .position && $0.direction == positionDirection }

        var total: NSDecimalNumber = 0
        for draft in targets {
            guard let quantity = decimal(from: draft.quantityText), let price = decimal(from: draft.priceText) else { continue }
            let qtyAbs = quantity.compare(0) == .orderedAscending ? quantity.multiplying(by: -1) : quantity
            guard qtyAbs.compare(0) == .orderedDescending else { continue }
            total = total.adding(qtyAbs.multiplying(by: price))
        }

        let newAmountText = total.stringValue
        if legs[cashIndex].amountText != newAmountText {
            legs[cashIndex].amountText = newAmountText
        }
    }

    private func addManualCashLeg() {
        var draft = LegDraft.cashDefault(assetID: assets.first?.objectID)
        draft.role = .expense
        draft.direction = .out
        draft.isRequired = false
        draft.titleText = ""
        legs.append(draft)
        editingDraftRoute = DraftEditRoute(id: draft.id)
    }

    private func draft(from leg: Leg) -> LegDraft {
        var draft = LegDraft.cashDefault(assetID: leg.asset?.objectID)
        draft.existingID = leg.objectID
        draft.role = leg.roleEnum
        draft.direction = leg.directionEnum
        draft.titleText = dynamicStringValue(leg, key: "title") ?? ""
        draft.isRequired = dynamicBoolValue(leg, key: "isRequired")

        if let cash = leg as? CashLeg {
            draft.kind = .cash
            draft.amountText = cash.amount?.stringValue ?? ""
            draft.currency = cash.currency ?? "KRW"
        } else if let position = leg as? PositionLeg {
            draft.kind = .position
            draft.ticker = position.ticker ?? ""
            draft.market = position.market ?? ""
            draft.quantityText = position.quantity?.stringValue ?? ""
            draft.unit = position.unit ?? "share"
            draft.priceText = position.price?.stringValue ?? ""
        }

        return draft
    }

    private func save() {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? selectedTemplate.title : trimmedTitle
        let input = TransactionEditorInput(
            transactionTitle: resolvedTitle,
            date: date,
            executionDate: showsExecutionDate ? executionDate : nil,
            categoryID: selectedCategoryID,
            dividendTicker: selectedTemplate == .dividend ? stockTicker : dividendTicker,
            stockTicker: stockTicker,
            stockMarket: stockMarket,
            memo: memoText,
            transactionTagsText: txTagsText,
            transactionType: selectedTemplate,
            legs: legs
        )
        guard validateDrafts().isValid else { return }
        let saved = onSave(input)
        if saved {
            dismiss()
        }
    }

    private func bindingForDraft(_ id: UUID) -> Binding<LegDraft>? {
        guard let index = legs.firstIndex(where: { $0.id == id }) else { return nil }
        return $legs[index]
    }

    private func validateDrafts(drafts: [LegDraft]? = nil) -> ValidationResult {
        let target = drafts ?? legs
        let cashLegs = target.filter { $0.kind == .cash }
        let posLegs = target.filter { $0.kind == .position }

        func directionCount(in list: [LegDraft], _ direction: LegDirection) -> Int {
            list.filter { $0.direction == direction }.count
        }

        switch selectedTemplate {
        case .income:
            return ValidationResult(
                isValid: directionCount(in: cashLegs.filter { $0.role == .income }, .in) >= 1,
                message: "수입은 입금 항목이 1개 이상 필요합니다."
            )
        case .expense:
            return ValidationResult(
                isValid: directionCount(in: cashLegs.filter { $0.role == .expense }, .out) >= 1,
                message: "지출은 출금 항목이 1개 이상 필요합니다."
            )
        case .transfer:
            return ValidationResult(
                isValid: directionCount(in: cashLegs, .in) >= 1 && directionCount(in: cashLegs, .out) >= 1,
                message: "이체는 수입/지출 항목이 각각 1개 이상 필요합니다."
            )
        case .exchange:
            let inCurrencies = Set(cashLegs.filter { $0.direction == .in }.map { normalizedCurrency($0.currency) })
            let outCurrencies = Set(cashLegs.filter { $0.direction == .out }.map { normalizedCurrency($0.currency) })
            let hasPair = !inCurrencies.isEmpty && !outCurrencies.isEmpty
            let hasDifferentCurrency = inCurrencies.contains { inCode in
                outCurrencies.contains { outCode in inCode != outCode }
            }
            return ValidationResult(
                isValid: hasPair && hasDifferentCurrency,
                message: "환전은 서로 다른 통화의 in/out exchange leg가 필요합니다."
            )
        case .buy:
            let buyPositions = posLegs.filter { $0.role == .positionIn && $0.direction == .in }
            let cashOut = cashLegs.filter { $0.role == .expense && $0.direction == .out }
            return ValidationResult(
                isValid: !buyPositions.isEmpty && !cashOut.isEmpty,
                message: "매수는 주식 입고 항목이 1개 이상과 현금 출금 항목이 필요합니다."
            )
        case .sell:
            let sellPositions = posLegs.filter { $0.role == .positionOut && $0.direction == .out }
            let cashIn = cashLegs.filter { $0.role == .income && $0.direction == .in }
            return ValidationResult(
                isValid: !sellPositions.isEmpty && !cashIn.isEmpty,
                message: "매도는 주식 출고 항목이 1개 이상과 현금 입금 항목이 필요합니다."
            )
        case .move:
            let inPositions = posLegs.filter { $0.role == .positionIn && $0.direction == .in }
            let outPositions = posLegs.filter { $0.role == .positionOut && $0.direction == .out }
            return ValidationResult(
                isValid: inPositions.count == 1 && outPositions.count == 1,
                message: "이관은 주식 입고/출고 항목이 각각 1개 필요합니다."
            )
        case .dividend:
            return ValidationResult(
                isValid: directionCount(in: cashLegs.filter { $0.role == .income }, .in) >= 1,
                message: "배당은 입금 항목이 1개 이상 필요합니다."
            )
        case .positionIn:
            return ValidationResult(
                isValid: posLegs.filter { $0.role == .positionIn && $0.direction == .in }.count == 1,
                message: "입고는 주식 입고 항목이 1개 필요합니다."
            )
        case .positionOut:
            return ValidationResult(
                isValid: posLegs.filter { $0.role == .positionOut && $0.direction == .out }.count == 1,
                message: "출고는 주식 출고 항목이 1개 필요합니다."
            )
        }
    }

    private func normalizedCurrency(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "KRW" : trimmed
    }

    private func inferredExchangeRate(from drafts: [LegDraft]) -> NSDecimalNumber? {
        let cashDrafts = drafts.filter { $0.kind == .cash }
        let outDrafts = cashDrafts.filter { $0.direction == .out }
        let inDrafts = cashDrafts.filter { $0.direction == .in }

        guard
            let out = outDrafts.max(by: { (decimal(from: $0.amountText) ?? 0).doubleValue < (decimal(from: $1.amountText) ?? 0).doubleValue }),
            let input = inDrafts.max(by: { (decimal(from: $0.amountText) ?? 0).doubleValue < (decimal(from: $1.amountText) ?? 0).doubleValue }),
            let outAmount = decimal(from: out.amountText),
            let inAmount = decimal(from: input.amountText),
            inAmount.compare(NSDecimalNumber.zero) == .orderedDescending,
            normalizedCurrency(out.currency) != normalizedCurrency(input.currency)
        else {
            return nil
        }

        return outAmount.dividing(by: inAmount)
    }

    private func inferredAveragePrice(from drafts: [LegDraft], type: TransactionType) -> NSDecimalNumber? {
        guard type == .buy || type == .sell else { return nil }
        let direction: LegDirection = type == .buy ? .in : .out
        let targets = drafts.filter { $0.kind == .position && $0.direction == direction }

        var totalQty: NSDecimalNumber = 0
        var totalAmount: NSDecimalNumber = 0
        for draft in targets {
            guard let qtyRaw = decimal(from: draft.quantityText), let price = decimal(from: draft.priceText) else { continue }
            let qty = qtyRaw.compare(0) == .orderedAscending ? qtyRaw.multiplying(by: -1) : qtyRaw
            guard qty.compare(0) == .orderedDescending else { continue }
            totalQty = totalQty.adding(qty)
            totalAmount = totalAmount.adding(qty.multiplying(by: price))
        }
        guard totalQty.compare(0) == .orderedDescending else { return nil }
        return totalAmount.dividing(by: totalQty)
    }

    private func amountText(_ value: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.string(from: value) ?? value.stringValue
    }

    private func decimal(from text: String) -> NSDecimalNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let value = NSDecimalNumber(string: normalized)
        return value == NSDecimalNumber.notANumber ? nil : value
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }

    private func dynamicDecimalValue(_ object: NSManagedObject, key: String) -> NSDecimalNumber? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? NSDecimalNumber
    }

    private func dynamicBoolValue(_ object: NSManagedObject, key: String) -> Bool {
        guard object.entity.attributesByName[key] != nil else { return false }
        return object.value(forKey: key) as? Bool ?? false
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

    @ViewBuilder
    private func lineLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func koreanDateText(_ date: Date) -> String {
        Self.koreanDateFormatter.string(from: date)
    }

    private static let koreanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M. d. (E)"
        return formatter
    }()

    private func datePickerSheet(title: String, selection: Binding<Date>) -> some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: selection, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        if title == "날짜 선택" {
                            showingDatePicker = false
                        } else {
                            showingExecutionDatePicker = false
                        }
                    }
                }
            }
        }
    }
}

private struct DraftEditRoute: Identifiable {
    let id: UUID
}

private struct ValidationResult {
    let isValid: Bool
    let message: String

    init(isValid: Bool, message: String = "") {
        self.isValid = isValid
        self.message = message
    }
}

private struct LegDraftSummaryRow: View {
    let draft: LegDraft
    let assets: [Asset]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(assetName)
                    .font(AppTypography.body)
                    .lineLimit(1)
                if !draft.titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(draft.titleText)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if draft.kind == .cash {
                HStack(spacing: 4) {
                    Text(amountSignedText)
                        .font(AppTypography.body)
                        .foregroundStyle(summaryColor(cashValue))
                    Text(amountCurrency)
                        .font(AppTypography.body)
                        .foregroundStyle(.primary)
                }
            } else {
                HStack(spacing: 0) {
                    Text(positionTickerSummary)
                        .font(AppTypography.body)
                    if !positionTickerSummary.isEmpty {
                        Text(" ")
                            .font(AppTypography.body)
                    }
                    Text(positionSignedQuantitySummary)
                        .font(AppTypography.body)
                        .foregroundStyle(summaryColor(positionValue))
                    Text("주")
                        .font(AppTypography.body)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, AppSpacing.rowVertical)
    }

    private var assetName: String {
        assets.first(where: { $0.objectID == draft.assetID })?.name ?? "자산 없음"
    }

    private var amountSignedText: String {
        let amount = draft.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let numeric = NSDecimalNumber(string: amount.replacingOccurrences(of: ",", with: "."))
        let safeNumber = (amount.isEmpty || numeric == NSDecimalNumber.notANumber) ? NSDecimalNumber.zero : numeric
        let absNumber = safeNumber.compare(0) == .orderedAscending ? safeNumber.multiplying(by: -1) : safeNumber
        let sign = absNumber.compare(0) == .orderedSame ? "" : (draft.direction == .in ? "+" : "-")
        let display = absNumber.stringValue
        return "\(sign)\(display)"
    }

    private var amountCurrency: String {
        let currency = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines)
        return currency.isEmpty ? "KRW" : currency
    }

    private var positionTickerSummary: String {
        let ticker = draft.ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        return ticker
    }

    private var positionSignedQuantitySummary: String {
        let numeric = NSDecimalNumber(string: draft.quantityText.replacingOccurrences(of: ",", with: "."))
        let safeNumber = (draft.quantityText.isEmpty || numeric == NSDecimalNumber.notANumber) ? NSDecimalNumber.zero : numeric
        let absNumber = safeNumber.compare(0) == .orderedAscending ? safeNumber.multiplying(by: -1) : safeNumber
        let sign = absNumber.compare(0) == .orderedSame ? "" : (draft.direction == .in ? "+" : "-")
        return "\(sign)\(absNumber.stringValue)"
    }

    private var cashValue: NSDecimalNumber {
        let normalized = draft.amountText.replacingOccurrences(of: ",", with: ".")
        let number = NSDecimalNumber(string: normalized)
        if draft.amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || number == NSDecimalNumber.notANumber {
            return 0
        }
        let absValue = number.compare(0) == .orderedAscending ? number.multiplying(by: -1) : number
        return draft.direction == .in ? absValue : absValue.multiplying(by: -1)
    }

    private var positionValue: NSDecimalNumber {
        let normalized = draft.quantityText.replacingOccurrences(of: ",", with: ".")
        let number = NSDecimalNumber(string: normalized)
        if draft.quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || number == NSDecimalNumber.notANumber {
            return 0
        }
        let absValue = number.compare(0) == .orderedAscending ? number.multiplying(by: -1) : number
        return draft.direction == .in ? absValue : absValue.multiplying(by: -1)
    }

    private func summaryColor(_ value: NSDecimalNumber) -> Color {
        let cmp = value.compare(0)
        if cmp == .orderedDescending { return AppPalette.red }
        if cmp == .orderedAscending { return AppPalette.blue }
        return .primary
    }
}

private struct LegDraftEditorView: View {
    @Binding var draft: LegDraft
    let assets: [Asset]
    let transactionType: TransactionType
    let fixedTicker: String
    let fixedMarket: String
    @Environment(\.dismiss) private var dismiss
    @State private var editedDraft: LegDraft

    private var currencyOptions: [String] {
        let base = CurrencyCatalog.codes
        let current = editedDraft.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !current.isEmpty && !base.contains(current) {
            return ([current] + base).sorted()
        }
        return base
    }

    init(draft: Binding<LegDraft>, assets: [Asset], transactionType: TransactionType, fixedTicker: String, fixedMarket: String) {
        self._draft = draft
        self.assets = assets
        self.transactionType = transactionType
        self.fixedTicker = fixedTicker
        self.fixedMarket = fixedMarket
        self._editedDraft = State(initialValue: draft.wrappedValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                lineSection {
                    if !editedDraft.isRequired {
                        lineRow("구분") {
                            Picker("구분", selection: $editedDraft.role) {
                                ForEach(optionalRoleCandidates, id: \.self) { role in
                                    Text(role.title).tag(role)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    if editedDraft.isRequired {
                        lineRow("구분") {
                            Text(editedDraft.role.title)
                                .foregroundStyle(.secondary)
                        }
                    }

                    lineRow("자산") {
                        Picker("자산", selection: $editedDraft.assetID) {
                            Text("자동 선택").tag(NSManagedObjectID?.none)
                            ForEach(assets, id: \.objectID) { asset in
                                Text(asset.name ?? "이름 없음").tag(Optional(asset.objectID))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    lineRow("항목 제목") {
                        TextField("항목 제목", text: $editedDraft.titleText)
                            .multilineTextAlignment(.trailing)
                    }

                    if editedDraft.kind == .cash {
                        lineRow("금액") {
                            TextField("금액", text: $editedDraft.amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .disabled(isAutoTradeCashDraft)
                        }
                        lineRow("통화") {
                            Picker("통화", selection: $editedDraft.currency) {
                                ForEach(currencyOptions, id: \.self) { code in
                                    Text(code).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppPalette.green)
                        }
                        if isAutoTradeCashDraft {
                            lineRow("안내") {
                                Text("수량 x 가격 자동 계산")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        lineRow("시장") {
                            TextField("Market", text: $editedDraft.market)
                                .multilineTextAlignment(.trailing)
                                .disabled(positionUsesTransactionTickerMarket)
                        }
                        lineRow("티커") {
                            TextField("Ticker", text: $editedDraft.ticker)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .multilineTextAlignment(.trailing)
                                .disabled(positionUsesTransactionTickerMarket)
                        }
                        lineRow("수량") {
                            TextField("수량", text: $editedDraft.quantityText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        lineRow("가격") {
                            TextField("Price", text: $editedDraft.priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        lineRow("단위") {
                            TextField("Unit", text: $editedDraft.unit)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("세부 거래 내역 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    draft = editedDraft
                    dismiss()
                }
            }
        }
        .onChange(of: editedDraft.kind) { _, newKind in
            guard !editedDraft.isRequired else { return }
            let candidates = newKind == .cash ? optionalCashRoleCandidates : optionalPositionRoleCandidates
            if !candidates.contains(editedDraft.role), let first = candidates.first {
                editedDraft.role = first
                if let fixed = first.fixedDirection { editedDraft.direction = fixed }
            }
        }
        .onChange(of: editedDraft.role) { _, newRole in
            guard !editedDraft.isRequired else { return }
            if optionalPositionRoleCandidates.contains(newRole) {
                editedDraft.kind = .position
            } else {
                editedDraft.kind = .cash
            }
            if let fixed = newRole.fixedDirection {
                editedDraft.direction = fixed
            }
            applyFixedPositionTickerMarketIfNeeded()
        }
        .onAppear {
            let normalized = editedDraft.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            editedDraft.currency = normalized.isEmpty ? "KRW" : normalized
            applyFixedPositionTickerMarketIfNeeded()
        }
    }

    @ViewBuilder
    private func lineSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
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

    private var isAutoTradeCashDraft: Bool {
        guard editedDraft.isRequired, editedDraft.kind == .cash else { return false }
        if transactionType == .buy {
            return editedDraft.role == .expense && editedDraft.direction == .out
        }
        if transactionType == .sell {
            return editedDraft.role == .income && editedDraft.direction == .in
        }
        return false
    }

    private var optionalRoleCandidates: [LegRole] {
        optionalCashRoleCandidates + optionalPositionRoleCandidates
    }

    private var optionalCashRoleCandidates: [LegRole] {
        [.income, .expense]
    }

    private var optionalPositionRoleCandidates: [LegRole] {
        switch transactionType {
        case .buy:
            return [.positionIn]
        case .sell:
            return [.positionOut]
        default:
            return []
        }
    }

    private var positionUsesTransactionTickerMarket: Bool {
        switch transactionType {
        case .buy, .sell, .dividend, .move, .positionIn, .positionOut:
            return true
        default:
            return false
        }
    }

    private func applyFixedPositionTickerMarketIfNeeded() {
        guard positionUsesTransactionTickerMarket, editedDraft.kind == .position else { return }
        editedDraft.ticker = fixedTicker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        editedDraft.market = fixedMarket.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

struct LegEditorView: View {
    @ObservedObject var leg: Leg
    let assets: [Asset]
    let onSave: () -> Void
    let onDelete: () -> Void
    let fallbackAssetProvider: () -> Asset

    @Environment(\.dismiss) private var dismiss

    @State private var role: LegRole = .expense
    @State private var direction: LegDirection = .out
    @State private var selectedAssetID: NSManagedObjectID?
    @State private var legTitleText: String = ""

    @State private var cashAmountText: String = ""
    @State private var cashCurrency: String = "KRW"

    @State private var posTicker: String = ""
    @State private var posMarket: String = ""
    @State private var posQuantityText: String = ""
    @State private var posUnit: String = "share"
    @State private var posPriceText: String = ""

    private var currencyOptions: [String] {
        let base = CurrencyCatalog.codes
        let current = cashCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !current.isEmpty && !base.contains(current) {
            return ([current] + base).sorted()
        }
        return base
    }

    private var kind: LegDraftKind {
        leg is PositionLeg ? .position : .cash
    }

    private var legIsRequired: Bool {
        guard leg.entity.attributesByName["isRequired"] != nil else { return false }
        return leg.value(forKey: "isRequired") as? Bool ?? false
    }

    private var parentTradeType: TransactionType? {
        guard let tx = leg.transaction else { return nil }
        let legs = ((tx.legs as? Set<Leg>) ?? [])
        let hasPosIn = legs.contains { $0 is PositionLeg && $0.directionEnum == .in }
        let hasPosOut = legs.contains { $0 is PositionLeg && $0.directionEnum == .out }
        let hasCashIn = legs.contains { $0 is CashLeg && $0.directionEnum == .in }
        let hasCashOut = legs.contains { $0 is CashLeg && $0.directionEnum == .out }
        if hasPosIn && hasCashOut && !hasPosOut { return .buy }
        if hasPosOut && hasCashIn && !hasPosIn { return .sell }
        return nil
    }

    private var isAutoTradeCashLocked: Bool {
        guard legIsRequired, kind == .cash else { return false }
        if parentTradeType == .buy { return role == .expense && direction == .out }
        if parentTradeType == .sell { return role == .income && direction == .in }
        return false
    }

    private var legUsesTransactionTickerMarket: Bool {
        guard let tx = leg.transaction else { return false }
        let ticker = dynamicStringValue(tx, key: "ticker")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ticker.isEmpty { return true }
        let roles = Set((((tx.legs as? Set<Leg>) ?? [])).map(\.roleEnum))
        return roles.contains(.positionIn) || roles.contains(.positionOut)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                lineSection {
                    if !legIsRequired && kind == .cash {
                        lineRow("방향") {
                            Picker("방향", selection: $direction) {
                                Text("지출").tag(LegDirection.out)
                                Text("수입").tag(LegDirection.in)
                            }
                            .pickerStyle(.menu)
                            .onChange(of: direction) { _, newDirection in
                                role = newDirection == .in ? .income : .expense
                            }
                        }
                    }

                    if legIsRequired {
                        lineRow("구분") {
                            Text(role.title)
                                .foregroundStyle(.secondary)
                        }
                    }

                    lineRow("자산") {
                        Picker("자산", selection: $selectedAssetID) {
                            Text("자동 선택").tag(NSManagedObjectID?.none)
                            ForEach(assets, id: \.objectID) { asset in
                                Text(asset.name ?? "이름 없음").tag(Optional(asset.objectID))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    lineRow("항목 제목") {
                        TextField("항목 제목", text: $legTitleText)
                            .multilineTextAlignment(.trailing)
                    }

                    if kind == .cash {
                        lineRow("금액") {
                            TextField("금액", text: $cashAmountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .disabled(isAutoTradeCashLocked)
                        }
                        lineRow("통화") {
                            Picker("통화", selection: $cashCurrency) {
                                ForEach(currencyOptions, id: \.self) { code in
                                    Text(code).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppPalette.green)
                        }
                        if isAutoTradeCashLocked {
                            lineRow("안내") {
                                Text("수량 x 가격 자동 계산")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        lineRow("시장") {
                            TextField("Market", text: $posMarket)
                                .multilineTextAlignment(.trailing)
                                .disabled(legUsesTransactionTickerMarket)
                        }
                        lineRow("티커") {
                            TextField("Ticker", text: $posTicker)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .multilineTextAlignment(.trailing)
                                .disabled(legUsesTransactionTickerMarket)
                        }
                        lineRow("수량") {
                            TextField("수량", text: $posQuantityText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        lineRow("가격") {
                            TextField("Price", text: $posPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        lineRow("단위") {
                            TextField("Unit", text: $posUnit)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                lineSection {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("삭제")
                            .font(AppTypography.body)
                    }
                    .disabled(legIsRequired)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.rowVertical)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("세부 거래 내역 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    applyChanges()
                    onSave()
                    dismiss()
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        role = leg.roleEnum
        direction = leg.directionEnum
        selectedAssetID = leg.asset?.objectID
        legTitleText = dynamicStringValue(leg, key: "title") ?? ""

        if let cash = leg as? CashLeg {
            cashAmountText = cash.amount?.stringValue ?? ""
            let normalizedCurrency = (cash.currency ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            cashCurrency = normalizedCurrency.isEmpty ? "KRW" : normalizedCurrency
        }

        if let pos = leg as? PositionLeg {
            posTicker = pos.ticker ?? ""
            posMarket = pos.market ?? ""
            posQuantityText = pos.quantity?.stringValue ?? ""
            posUnit = pos.unit ?? "share"
            posPriceText = pos.price?.stringValue ?? ""
            if legUsesTransactionTickerMarket {
                let sourceObject: NSManagedObject = leg.transaction ?? pos
                if let ticker = dynamicStringValue(sourceObject, key: "ticker"), !ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    posTicker = ticker
                }
                if let market = dynamicStringValue(sourceObject, key: "market"), !market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    posMarket = market
                }
            }
        }

        if isAutoTradeCashLocked, let auto = autoTradeCashAmount() {
            cashAmountText = auto.stringValue
        }
    }

    private func applyChanges() {
        if legIsRequired {
            leg.directionEnum = leg.roleEnum.fixedDirection ?? leg.directionEnum
        } else {
            leg.directionEnum = role.fixedDirection ?? direction
            leg.roleEnum = role
        }
        setValueIfAttributeExists(on: leg, key: "title", value: trimmedOrNil(legTitleText))

        if let selectedAsset = assets.first(where: { $0.objectID == selectedAssetID }) {
            leg.asset = selectedAsset
        } else if leg.asset == nil {
            leg.asset = fallbackAssetProvider()
        }

        if let cash = leg as? CashLeg {
            if isAutoTradeCashLocked, let auto = autoTradeCashAmount() {
                cash.amount = auto
            } else {
                cash.amount = decimalOrZero(cashAmountText)
            }
            let normalizedCurrency = cashCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            cash.currency = normalizedCurrency.isEmpty ? "KRW" : normalizedCurrency
        }

        if let pos = leg as? PositionLeg {
            if legUsesTransactionTickerMarket {
                let sourceObject: NSManagedObject = leg.transaction ?? pos
                let txTicker = dynamicStringValue(sourceObject, key: "ticker")?.trimmingCharacters(in: .whitespacesAndNewlines)
                let txMarket = dynamicStringValue(sourceObject, key: "market")?.trimmingCharacters(in: .whitespacesAndNewlines)
                pos.ticker = txTicker?.isEmpty == false ? txTicker : posTicker
                pos.market = txMarket?.isEmpty == false ? txMarket : posMarket
            } else {
                pos.ticker = posTicker
                pos.market = posMarket
            }
            pos.quantity = decimalOrZero(posQuantityText)
            pos.unit = posUnit.isEmpty ? "share" : posUnit
            pos.price = decimalOrNil(posPriceText)
        }
    }

    private func decimalOrZero(_ text: String) -> NSDecimalNumber {
        decimalOrNil(text) ?? 0
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func decimalOrNil(_ text: String) -> NSDecimalNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let value = NSDecimalNumber(string: normalized)
        return value == NSDecimalNumber.notANumber ? nil : value
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }

    private func setValueIfAttributeExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }

    private func autoTradeCashAmount() -> NSDecimalNumber? {
        guard let tx = leg.transaction else { return nil }
        let legs = ((tx.legs as? Set<Leg>) ?? [])
        let targetDirection: LegDirection = parentTradeType == .buy ? .in : .out
        guard let position = legs.first(where: { $0 is PositionLeg && $0.directionEnum == targetDirection }) as? PositionLeg else {
            return nil
        }
        let quantity = position.quantity ?? 0
        let price = position.price ?? 0
        let result = quantity.multiplying(by: price)
        return result == NSDecimalNumber.notANumber ? nil : result
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
