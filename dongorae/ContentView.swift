import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var didSeed = false

    var body: some View {
        TabView {
            HomeDashboardPage()
                .tabItem {
                    Label("홈", systemImage: "house")
                }

            TransactionsPage()
                .tabItem {
                    Label("거래내역", systemImage: "list.bullet.rectangle.portrait")
                }

            InvestmentsPage()
                .tabItem {
                    Label("투자", systemImage: "chart.line.uptrend.xyaxis")
                }

            AssetsPage()
                .tabItem {
                    Label("자산", systemImage: "wallet.bifold")
                }

            SettingsPage()
                .tabItem {
                    Label("더보기", systemImage: "ellipsis")
                }
        }
        .tint(AppPalette.green)
        .task {
            guard !didSeed else { return }
            didSeed = true
            PersistenceController.seedSampleDataIfNeeded(context: context)
        }
    }
}

private struct HomeDashboardPage: View {
    @FetchRequest(entity: Asset.entity(), sortDescriptors: [])
    private var assets: FetchedResults<Asset>

    @FetchRequest(
        entity: CashLeg.entity(),
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
    )
    private var cashLegs: FetchedResults<CashLeg>

    @FetchRequest(entity: PositionLeg.entity(), sortDescriptors: [])
    private var positionLegs: FetchedResults<PositionLeg>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    SummaryCard(
                        title: "총 자산",
                        value: "\(assets.count)개 자산",
                        subtitle: "은행/투자/기타 자산 기준"
                    )

                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "월간 수입",
                            value: amountString(monthlyCashFlow(direction: .in)),
                            subtitle: "이번 달 CashLeg 유입"
                        )
                        SummaryCard(
                            title: "월간 지출",
                            value: amountString(monthlyCashFlow(direction: .out)),
                            subtitle: "이번 달 CashLeg 유출"
                        )
                    }

                    SummaryCard(
                        title: "포트폴리오 요약",
                        value: "보유 종목 \(positionLegs.count)건",
                        subtitle: topTickerText
                    )
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, AppSpacing.sectionVertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("대시보드")
                        .font(AppTypography.title)
                }
            }
        }
    }

    private var topTickerText: String {
        let counts = Dictionary(
            grouping: positionLegs.compactMap { $0.ticker?.trimmingCharacters(in: .whitespacesAndNewlines) },
            by: { $0 }
        )
        guard let (ticker, items) = counts.max(by: { $0.value.count < $1.value.count }) else {
            return "보유 종목 데이터 없음"
        }
        return "주요 종목: \(ticker) (\(items.count)건)"
    }

    private func monthlyCashFlow(direction: LegDirection) -> NSDecimalNumber {
        let calendar = Calendar.current
        let now = Date()
        return cashLegs.reduce(NSDecimalNumber.zero) { partial, leg in
            guard
                leg.directionEnum == direction,
                let createdAt = leg.createdAt,
                calendar.isDate(createdAt, equalTo: now, toGranularity: .month)
            else { return partial }
            return partial.adding(leg.amount ?? 0)
        }
    }

    private func amountString(_ value: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: value) ?? value.stringValue
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
