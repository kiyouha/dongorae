import SwiftUI
import CoreData

struct InvestmentsPage: View {
    @FetchRequest(entity: PositionLeg.entity(), sortDescriptors: [])
    private var positions: FetchedResults<PositionLeg>

    @FetchRequest(entity: CashLeg.entity(), sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var cashLegs: FetchedResults<CashLeg>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    summaryRow

                    AppCard("보유 종목") {
                        if groupedTickers.isEmpty {
                            Text("보유 종목이 없습니다")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(groupedTickers.keys).sorted(), id: \.self) { ticker in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ticker)
                                                .font(AppTypography.body.weight(.semibold))
                                            Text("거래 \(groupedTickers[ticker]?.count ?? 0)건")
                                                .font(AppTypography.body)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(quantityText(for: ticker))
                                            .font(AppTypography.body.monospacedDigit())
                                    }
                                }
                            }
                        }
                    }

                    AppCard("배당/현금흐름") {
                        metricRow("배당 유입", amountString(dividendIncome))
                        metricRow("총 포지션 레그", "\(positions.count)건")
                    }

                    AppCard("안내") {
                        Text("매수/매도 상세 내역은 거래내역 탭에서 Transaction-Leg 구조로 확인할 수 있습니다.")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("투자")
                        .font(AppTypography.title)
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            AppSummaryChip(title: "보유 종목", value: "\(groupedTickers.keys.count)")
            AppSummaryChip(title: "포지션 레그", value: "\(positions.count)")
            AppSummaryChip(title: "배당", value: amountString(dividendIncome))
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.body)
            Spacer()
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var groupedTickers: [String: [PositionLeg]] {
        Dictionary(grouping: positions) { ($0.ticker ?? "-") }
    }

    private var dividendIncome: NSDecimalNumber {
        cashLegs.reduce(NSDecimalNumber.zero) { partial, leg in
            let isDividendTransaction = !(leg.transaction?.dividendTicker?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            guard leg.roleEnum == .income, leg.directionEnum == .in, isDividendTransaction else { return partial }
            return partial.adding(leg.amount ?? 0)
        }
    }

    private func quantityText(for ticker: String) -> String {
        let total = (groupedTickers[ticker] ?? []).reduce(NSDecimalNumber.zero) { partial, leg in
            let sign: NSDecimalNumber = leg.directionEnum == .in ? 1 : -1
            return partial.adding((leg.quantity ?? 0).multiplying(by: sign))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: total) ?? total.stringValue
    }

    private func amountString(_ value: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: value) ?? value.stringValue
    }
}
