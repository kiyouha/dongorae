import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            TransactionsPage()
                .tabItem {
                    Label("거래", systemImage: "list.bullet")
                }

            AssetsPage()
                .tabItem {
                    Label("자산", systemImage: "creditcard")
                }

            InvestmentsPage()
                .tabItem {
                    Label("투자", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
    }
}

private struct TransactionsPage: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Transaction.date, ascending: false)
        ]
    ) private var transactions: FetchedResults<Transaction>

    @State private var isPresentingForm = false
    @State private var editingTransaction: Transaction? = nil
    @State private var headerAddDate: Date? = nil

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "거래가 없습니다",
                        systemImage: "list.bullet.rectangle",
                        description: Text("오른쪽 상단의 + 버튼으로 거래를 추가하세요.")
                    )
                } else {
                    List {
                        ForEach(groupedByDay(transactions: Array(transactions)), id: \.day) { section in
                            Section(header:
                                Button(action: { headerAddDate = section.day }) {
                                    HStack {
                                        Text(formatSectionDate(section.day))
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.tint)
                                            .imageScale(.medium)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            ) {
                                ForEach(section.items, id: \.objectID) { tx in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tx.type ?? "유형 없음")
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            Text(formatUUID(tx.id))
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            Text(formatDate(tx.date))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatPrice(tx.price))
                                            .font(.footnote.monospacedDigit())
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 4)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                    .onTapGesture { beginEditing(tx) }
                                    .contextMenu {
                                        Button {
                                            beginEditing(tx)
                                        } label: {
                                            Label("수정", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            if let index = transactions.firstIndex(of: tx) {
                                                deleteTransactions(at: IndexSet(integer: index))
                                            }
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteTransactions)
                        .onMove(perform: moveTransactions)
                    }
                    .listStyle(.grouped)
                    .listRowSpacing(4)
                }
            }
            .navigationTitle("거래")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !transactions.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isPresentingForm = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("거래 추가")
                }
            }
            .sheet(isPresented: $isPresentingForm) {
                TransactionFormView(
                    title: "거래 추가",
                    initialType: "",
                    initialPrice: 0,
                    initialDate: Date(),
                    onCancel: { isPresentingForm = false },
                    onSave: { type, price, date in
                        addTransaction(type: type, price: price, date: date)
                        isPresentingForm = false
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: Binding(
                get: {
                    headerAddDate.map { IdentifiedDate(value: $0) }
                },
                set: { newValue in
                    headerAddDate = newValue?.value
                }
            )) { identified in
                TransactionFormView(
                    title: "거래 추가",
                    initialType: "",
                    initialPrice: 0,
                    initialDate: identified.value,
                    onCancel: { headerAddDate = nil },
                    onSave: { type, price, date in
                        addTransaction(type: type, price: price, date: date)
                        headerAddDate = nil
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionFormView(
                    title: "거래 수정",
                    initialType: tx.type ?? "",
                    initialPrice: tx.price,
                    initialDate: tx.date ?? Date(),
                    onCancel: { editingTransaction = nil },
                    onSave: { type, price, date in
                        updateTransaction(tx, type: type, price: price, date: date)
                        editingTransaction = nil
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Actions
    private func addTransaction(type: String, price: Double, date: Date) {
        withAnimation(.easeInOut) {
            let tx = Transaction(context: context)
            tx.type = type
            tx.price = price
            tx.date = date
            saveContext()
        }
    }

    private func updateTransaction(_ tx: Transaction, type: String, price: Double, date: Date) {
        withAnimation(.easeInOut) {
            tx.type = type
            tx.price = price
            tx.date = date
            saveContext()
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            offsets.map { transactions[$0] }.forEach(context.delete)
            saveContext()
        }
    }

    private func moveTransactions(from source: IndexSet, to destination: Int) {
        // Snapshot current visual order
        var current = Array(transactions)

        // Extract the items being moved (preserve their relative order)
        let movingItems = source.map { current[$0] }

        // Remove them from the snapshot
        current.remove(atOffsets: source)

        // Insert them at the new destination
        current.insert(contentsOf: movingItems, at: destination)

        // Helper to compute a date slightly between two dates
        func midDate(between newer: Date?, and older: Date?) -> Date {
            switch (newer, older) {
            case let (n?, o?):
                // If both exist, pick the midpoint
                let mid = n.timeIntervalSinceReferenceDate + (o.timeIntervalSinceReferenceDate - n.timeIntervalSinceReferenceDate) / 2.0
                return Date(timeIntervalSinceReferenceDate: mid)
            case let (n?, nil):
                // Only newer exists (inserted at end visually): make slightly older
                return n.addingTimeInterval(-1)
            case let (nil, o?):
                // Only older exists (inserted at start visually): make slightly newer
                return o.addingTimeInterval(1)
            default:
                // No neighbors: fallback to now
                return Date()
            }
        }

        // For each moved item now at its final indices, set its date between its neighbors
        // List is sorted by date descending, so index 0 should be newest (largest date)
        for item in movingItems {
            if let idx = current.firstIndex(of: item) {
                let newerNeighborDate = idx > 0 ? current[idx - 1].date : nil
                let olderNeighborDate = idx + 1 < current.count ? current[idx + 1].date : nil
                item.date = midDate(between: newerNeighborDate, and: olderNeighborDate)
            }
        }

        saveContext()
    }

    private func beginEditing(_ tx: Transaction) {
        withAnimation(.easeInOut) {
            editingTransaction = tx
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // 간단한 오류 처리: 개발 단계에서는 fatalError로 원인 파악
            #if DEBUG
            fatalError("Unresolved Core Data error: \(error.localizedDescription)")
            #else
            print("Core Data save error: \(error)")
            #endif
        }
    }

    // MARK: - Formatters
    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: value)) ?? "-"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatUUID(_ value: UUID?) -> String {
        guard let value else { return "-" }
        return value.uuidString
    }

    private struct IdentifiedDate: Identifiable {
        let id = UUID()
        let value: Date
    }

    private struct DaySection: Identifiable {
        let id = UUID()
        let day: Date
        let items: [Transaction]
    }

    private func groupedByDay(transactions: [Transaction]) -> [DaySection] {
        // Normalize dates to the start of day using current calendar
        let calendar = Calendar.current
        let groups = Dictionary(grouping: transactions) { (tx: Transaction) -> Date in
            let date = tx.date ?? Date()
            return calendar.startOfDay(for: date)
        }
        // Sort sections by day descending (to match list sort)
        let sortedDays = groups.keys.sorted(by: { $0 > $1 })
        return sortedDays.map { day in
            let items = groups[day]?.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) ?? []
            return DaySection(day: day, items: items)
        }
    }

    private func formatSectionDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }
}

private struct AssetsPage: View {
    var body: some View {
        NavigationStack {
            Text("자산 페이지")
                .padding()
                .navigationTitle("자산")
        }
    }
}

private struct InvestmentsPage: View {
    var body: some View {
        NavigationStack {
            Text("투자 페이지")
                .padding()
                .navigationTitle("투자")
        }
    }
}

// MARK: - Form View
private struct TransactionFormView: View {
    let title: String
    @State var typeText: String
    @State var priceText: String
    @State var date: Date

    var onCancel: () -> Void
    var onSave: (_ type: String, _ price: Double, _ date: Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field { case type, price }

    init(title: String, initialType: String, initialPrice: Double, initialDate: Date, onCancel: @escaping () -> Void, onSave: @escaping (_ type: String, _ price: Double, _ date: Date) -> Void) {
        self.title = title
        self._typeText = State(initialValue: initialType)
        self._priceText = State(initialValue: initialPrice == 0 ? "" : String(initialPrice))
        self._date = State(initialValue: initialDate)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("유형", text: $typeText)
                        .focused($focusedField, equals: .type)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .price }

                    TextField("금액", text: $priceText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)

                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { focusedField = .type }
        }
    }

    private var canSave: Bool {
        !typeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedPrice != nil
    }

    private var parsedPrice: Double? {
        if priceText.isEmpty { return 0 }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: priceText)?.doubleValue
    }

    private func save() {
        guard let price = parsedPrice else { return }
        onSave(typeText.trimmingCharacters(in: .whitespacesAndNewlines), price, date)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
