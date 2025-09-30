import SwiftUI
import Charts

/// NN/g Enhanced Income Tracker with Improved Financial Interface
public struct IncomeTrackerView: View {
    @StateObject private var financeManager = FinanceManager()
    @StateObject private var stripeService = StripeService()
    @State private var selectedTimeFrame = TimeFrame.month
    @State private var showingAddIncome = false
    @State private var showingPayoutSheet = false
    @State private var showingTaxDetails = false
    @State private var selectedPlatform: RevenuePlatform? = nil
    @State private var viewMode = FinancialViewMode.overview

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Clear Navigation and Context
            FinancialHeaderNavigation(
                selectedTimeFrame: $selectedTimeFrame,
                viewMode: $viewMode,
                onAddIncome: { showingAddIncome = true }
            )

            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xxl) {
                    // NN/g: Primary Financial Status - Always Visible
                    EnhancedFinancialSummary(
                        financeManager: financeManager,
                        onRequestPayout: { showingPayoutSheet = true },
                        onViewTaxDetails: { showingTaxDetails = true }
                    )

                    // NN/g: Conditional Content Based on View Mode
                    Group {
                        switch viewMode {
                        case .overview:
                            OverviewSections(financeManager: financeManager, selectedPlatform: $selectedPlatform)
                        case .analytics:
                            AnalyticsSections(financeManager: financeManager, timeFrame: selectedTimeFrame)
                        case .transactions:
                            TransactionsSections(financeManager: financeManager)
                        case .taxes:
                            TaxSections(financeManager: financeManager)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(Color(.windowBackgroundColor))
        }
        .sheet(isPresented: $showingAddIncome) {
            EnhancedAddIncomeSheet(financeManager: financeManager)
        }
        .sheet(isPresented: $showingPayoutSheet) {
            EnhancedPayoutRequestSheet(
                stripeService: stripeService,
                availableBalance: financeManager.availableBalance
            )
        }
        .sheet(isPresented: $showingTaxDetails) {
            TaxDetailSheet(financeManager: financeManager)
        }
        .onAppear {
            Task {
                await financeManager.loadData(for: selectedTimeFrame)
                await stripeService.connectAccount()
            }
        }
        .onChange(of: selectedTimeFrame) { _ in
            Task {
                await financeManager.loadData(for: selectedTimeFrame)
            }
        }
    }
}

// MARK: - Finance Header
struct FinanceHeaderView: View {
    let totalBalance: Double
    let pendingBalance: Double
    let availableBalance: Double
    let onAddIncome: () -> Void
    let onRequestPayout: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Main Balance Display
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Total Balance")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))

                Text("$\(totalBalance, specifier: "%.2f")")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: DesignSystem.Spacing.section) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.8))
                        Text("$\(availableBalance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.green)
                    }

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.8))
                        Text("$\(pendingBalance, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
            }

            // Quick Actions
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: onAddIncome) {
                    Label("Add Income", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onRequestPayout) {
                    Label("Request Payout", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(availableBalance < 10) // Minimum payout threshold
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Time Frame Selector
struct TimeFrameSelector: View {
    @Binding var selectedTimeFrame: TimeFrame

    var body: some View {
        Picker("Time Frame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases, id: \.self) { frame in
                Text(frame.rawValue).tag(frame)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: 400)
    }
}

// MARK: - Revenue Overview Cards
struct RevenueOverviewCards: View {
    let revenues: [PlatformRevenue]
    @Binding var selectedPlatform: RevenuePlatform?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(revenues) { revenue in
                    IncomeRevenueCard(
                        platform: revenue.platform,
                        amount: revenue.amount,
                        change: revenue.changePercent,
                        isSelected: selectedPlatform == revenue.platform,
                        onTap: {
                            withAnimation {
                                selectedPlatform = selectedPlatform == revenue.platform ? nil : revenue.platform
                            }
                        }
                    )
                }
            }
        }
    }
}

struct IncomeRevenueCard: View {
    let platform: RevenuePlatform
    let amount: Double
    let change: Double
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: platform.icon)
                    .font(.title2)
                    .foregroundColor(platform.color)

                Spacer()

                if change != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text("\(abs(change), specifier: "%.1f")%")
                            .font(.caption)
                    }
                    .foregroundColor(change > 0 ? .green : .red)
                }
            }

            Text(platform.displayName)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            Text("$\(amount, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? platform.color.opacity(0.2) : (isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? platform.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Revenue Chart
struct RevenueChartView: View {
    let data: [RevenueDataPoint]
    let timeFrame: TimeFrame

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Revenue Trend")
                .font(.headline)
                .foregroundColor(.white)

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Revenue", point.amount)
                )
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Revenue", point.amount)
                )
                .foregroundStyle(LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Revenue", point.amount)
                )
                .foregroundStyle(.white)
                .symbolSize(30)
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("$\(amount, specifier: "%.0f")")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: timeFrame.dateFormat)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Income Sources Breakdown
struct IncomeSourcesBreakdown: View {
    let sources: [IncomeSource]

    var totalAmount: Double {
        sources.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Income Sources")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(sources) { source in
                    IncomeSourceRow(
                        source: source,
                        percentage: totalAmount > 0 ? (source.amount / totalAmount) * 100 : 0
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct IncomeSourceRow: View {
    let source: IncomeSource
    let percentage: Double

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: source.icon)
                    .foregroundColor(source.color)
                    .frame(width: 30)

                Text(source.name)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(source.amount, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(source.color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Recent Transactions
struct RecentTransactionsView: View {
    let transactions: [Transaction]
    @State private var showingAll = false

    var displayedTransactions: [Transaction] {
        showingAll ? transactions : Array(transactions.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(showingAll ? "Show Less" : "Show All") {
                    withAnimation {
                        showingAll.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(displayedTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.type.icon)
                .foregroundColor(transaction.type.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text("\(transaction.type == .expense ? "-" : "+")$\(abs(transaction.amount), specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Tax Estimation Card
struct TaxEstimationCard: View {
    let grossIncome: Double
    let estimatedTax: Double

    var netIncome: Double {
        grossIncome - estimatedTax
    }

    var taxRate: Double {
        grossIncome > 0 ? (estimatedTax / grossIncome) * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Tax Estimation")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Gross Income")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("$\(grossIncome, specifier: "%.2f")")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Estimated Tax (\(taxRate, specifier: "%.1f")%)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("$\(estimatedTax, specifier: "%.2f")")
                        .font(.title3)
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Net Income")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("$\(netIncome, specifier: "%.2f")")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }

            Text("⚠️ This is an estimate. Consult a tax professional for accurate calculations.")
                .font(.caption2)
                .foregroundColor(.yellow.opacity(0.8))
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Payout History
struct PayoutHistoryView: View {
    let payouts: [Payout]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Payout History")
                .font(.headline)
                .foregroundColor(.white)

            if payouts.isEmpty {
                Text("No payouts yet")
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(payouts) { payout in
                        PayoutRow(payout: payout)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct PayoutRow: View {
    let payout: Payout

    var statusColor: Color {
        switch payout.status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("$\(payout.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(payout.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(payout.status.rawValue)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Add Income Sheet
struct AddIncomeSheet: View {
    let financeManager: FinanceManager
    @Environment(\.dismiss) var dismiss

    @State private var amount = ""
    @State private var description = ""
    @State private var source = IncomeSourceType.donations
    @State private var platform = RevenuePlatform.twitch
    @State private var date = Date()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Income")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)

                Button("Save") {
                    saveIncome()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.isEmpty || description.isEmpty)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Form
            Form {
                Section("Details") {
                    TextField("Amount", text: $amount)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description", text: $description)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Source") {
                    Picker("Income Type", selection: $source) {
                        ForEach(IncomeSourceType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Platform", selection: $platform) {
                        ForEach(RevenuePlatform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: platform.icon)
                                    .foregroundColor(platform.color)
                                Text(platform.displayName)
                            }
                            .tag(platform)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
    }

    private func saveIncome() {
        guard let amountValue = Double(amount) else { return }

        let transaction = Transaction(
            id: UUID(),
            date: date,
            amount: amountValue,
            description: description,
            type: .income,
            platform: platform,
            sourceType: source
        )

        financeManager.addTransaction(transaction)
        dismiss()
    }
}

// MARK: - Payout Request Sheet
struct PayoutRequestSheet: View {
    let stripeService: StripeService
    let availableBalance: Double
    @Environment(\.dismiss) var dismiss

    @State private var amount = ""
    @State private var bankAccount = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Request Payout")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .disabled(isProcessing)

                Button(isProcessing ? "Processing..." : "Request") {
                    requestPayout()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.isEmpty || bankAccount.isEmpty || isProcessing)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Form
            Form {
                Section("Payout Details") {
                    HStack {
                        Text("Available Balance:")
                        Spacer()
                        Text("$\(availableBalance, specifier: "%.2f")")
                            .fontWeight(.semibold)
                    }

                    TextField("Amount", text: $amount)
                        .textFieldStyle(.roundedBorder)

                    TextField("Bank Account (last 4 digits)", text: $bankAccount)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Processing Time") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "clock")
                            Text("Standard: 2-3 business days")
                        }
                        HStack {
                            Image(systemName: "bolt")
                            Text("Instant: 30 minutes (1.5% fee)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 400)
    }

    private func requestPayout() {
        guard let amountValue = Double(amount),
              amountValue > 0,
              amountValue <= availableBalance else {
            errorMessage = "Invalid amount"
            return
        }

        isProcessing = true

        Task {
            await stripeService.requestPayout(amount: amountValue, account: bankAccount)
            dismiss()
        }
    }
}

// MARK: - Data Models
enum TimeFrame: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var dateFormat: Date.FormatStyle {
        switch self {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday()
        case .month: return .dateTime.day()
        case .year: return .dateTime.month()
        }
    }
}

enum RevenuePlatform: String, CaseIterable {
    case twitch = "Twitch"
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case kick = "Kick"
    case patreon = "Patreon"
    case donations = "Direct Donations"
    case sponsorships = "Sponsorships"
    case merch = "Merchandise"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle.fill"
        case .tiktok: return "music.note"
        case .kick: return "bolt.fill"
        case .patreon: return "heart.fill"
        case .donations: return "gift"
        case .sponsorships: return "star.fill"
        case .merch: return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .twitch: return .purple
        case .youtube: return .red
        case .tiktok: return .black
        case .kick: return .green
        case .patreon: return .orange
        case .donations: return .blue
        case .sponsorships: return .yellow
        case .merch: return .pink
        }
    }
}

struct PlatformRevenue: Identifiable {
    let id = UUID()
    let platform: RevenuePlatform
    let amount: Double
    let changePercent: Double
}

struct RevenueDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

enum IncomeSourceType: String, CaseIterable {
    case subscriptions = "Subscriptions"
    case donations = "Donations"
    case ads = "Ad Revenue"
    case sponsorships = "Sponsorships"
    case merch = "Merchandise"
    case affiliate = "Affiliate"
    case tips = "Tips"

    var icon: String {
        switch self {
        case .subscriptions: return "person.2.fill"
        case .donations: return "gift.fill"
        case .ads: return "rectangle.stack.fill"
        case .sponsorships: return "star.fill"
        case .merch: return "bag.fill"
        case .affiliate: return "link"
        case .tips: return "dollarsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .subscriptions: return .purple
        case .donations: return .blue
        case .ads: return .green
        case .sponsorships: return .yellow
        case .merch: return .pink
        case .affiliate: return .orange
        case .tips: return .mint
        }
    }
}

struct IncomeSource: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let icon: String
    let color: Color
}

enum TransactionType {
    case income
    case expense

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .income: return .green
        case .expense: return .red
        }
    }
}

struct Transaction: Identifiable {
    let id: UUID
    let date: Date
    let amount: Double
    let description: String
    let type: TransactionType
    let platform: RevenuePlatform?
    let sourceType: IncomeSourceType?

    init(id: UUID = UUID(), date: Date = Date(), amount: Double, description: String, type: TransactionType, platform: RevenuePlatform? = nil, sourceType: IncomeSourceType? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.description = description
        self.type = type
        self.platform = platform
        self.sourceType = sourceType
    }
}

enum PayoutStatus: String {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

struct Payout: Identifiable {
    let id = UUID()
    let amount: Double
    let date: Date
    let status: PayoutStatus
}

// MARK: - Finance Manager
class FinanceManager: ObservableObject {
    @Published var totalBalance: Double = 15234.56
    @Published var pendingBalance: Double = 2345.67
    @Published var availableBalance: Double = 12888.89
    @Published var totalIncome: Double = 45678.90
    @Published var estimatedTax: Double = 11419.73

    @Published var revenueByPlatform: [PlatformRevenue] = []
    @Published var revenueHistory: [RevenueDataPoint] = []
    @Published var incomeSources: [IncomeSource] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var payoutHistory: [Payout] = []

    init() {
        loadMockData()
    }

    func loadData(for timeFrame: TimeFrame) async {
        // In real app, fetch from API/database
        await MainActor.run {
            loadMockData()
        }
    }

    func addTransaction(_ transaction: Transaction) {
        recentTransactions.insert(transaction, at: 0)
        if transaction.type == .income {
            totalBalance += transaction.amount
            availableBalance += transaction.amount
        } else {
            totalBalance -= transaction.amount
            availableBalance -= transaction.amount
        }
    }

    private func loadMockData() {
        // Revenue by platform
        revenueByPlatform = [
            PlatformRevenue(platform: .twitch, amount: 5678.90, changePercent: 12.5),
            PlatformRevenue(platform: .youtube, amount: 3456.78, changePercent: -5.2),
            PlatformRevenue(platform: .tiktok, amount: 2345.67, changePercent: 45.8),
            PlatformRevenue(platform: .sponsorships, amount: 4567.89, changePercent: 8.3),
            PlatformRevenue(platform: .merch, amount: 1234.56, changePercent: 23.4)
        ]

        // Revenue history (last 30 days)
        let calendar = Calendar.current
        revenueHistory = (0..<30).map { day in
            let date = calendar.date(byAdding: .day, value: -day, to: Date())!
            let amount = Double.random(in: 200...800) + (Double(30 - day) * 10)
            return RevenueDataPoint(date: date, amount: amount)
        }.reversed()

        // Income sources
        incomeSources = [
            IncomeSource(name: "Subscriptions", amount: 8234.56, icon: "person.2.fill", color: .purple),
            IncomeSource(name: "Donations", amount: 3456.78, icon: "gift.fill", color: .blue),
            IncomeSource(name: "Ad Revenue", amount: 2345.67, icon: "rectangle.stack.fill", color: .green),
            IncomeSource(name: "Sponsorships", amount: 4567.89, icon: "star.fill", color: .yellow),
            IncomeSource(name: "Merchandise", amount: 1234.56, icon: "bag.fill", color: .pink)
        ]

        // Recent transactions
        recentTransactions = [
            Transaction(amount: 234.56, description: "Twitch Subscription Payout", type: .income, platform: .twitch),
            Transaction(amount: 89.99, description: "Equipment Purchase", type: .expense),
            Transaction(amount: 567.89, description: "YouTube Ad Revenue", type: .income, platform: .youtube),
            Transaction(amount: 1234.56, description: "Sponsorship Payment - NordVPN", type: .income, platform: .sponsorships),
            Transaction(amount: 45.67, description: "Streaming Software License", type: .expense),
            Transaction(amount: 345.67, description: "TikTok Creator Fund", type: .income, platform: .tiktok),
            Transaction(amount: 234.56, description: "Merch Sales", type: .income, platform: .merch)
        ]

        // Payout history
        payoutHistory = [
            Payout(amount: 5000.00, date: Date().addingTimeInterval(-7 * 24 * 60 * 60), status: .completed),
            Payout(amount: 3500.00, date: Date().addingTimeInterval(-14 * 24 * 60 * 60), status: .completed),
            Payout(amount: 2500.00, date: Date().addingTimeInterval(-21 * 24 * 60 * 60), status: .completed),
            Payout(amount: 1500.00, date: Date().addingTimeInterval(-2 * 24 * 60 * 60), status: .processing)
        ]
    }
}

// MARK: - NN/g Enhanced Financial Components

/// Clear financial navigation with view modes
struct FinancialHeaderNavigation: View {
    @Binding var selectedTimeFrame: TimeFrame
    @Binding var viewMode: FinancialViewMode
    let onAddIncome: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Clear page context
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Financial Dashboard")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Track income, expenses, and manage payouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // View mode selector (NN/g: User control)
            Picker("View Mode", selection: $viewMode) {
                ForEach(FinancialViewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 350)

            // Time range selector
            Picker("Time Range", selection: $selectedTimeFrame) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Text(frame.rawValue).tag(frame)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            // Primary action
            Button(action: onAddIncome) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Income")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(.regularMaterial)
    }
}

/// Enhanced financial summary with key metrics
struct EnhancedFinancialSummary: View {
    let financeManager: FinanceManager
    let onRequestPayout: () -> Void
    let onViewTaxDetails: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Primary balance display
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Total Balance")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("$\(financeManager.totalBalance, specifier: "%.2f")")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Status indicators with clear meaning
                HStack(spacing: DesignSystem.Spacing.xxl) {
                    BalanceStatusCard(
                        title: "Available",
                        amount: financeManager.availableBalance,
                        status: .available,
                        description: "Ready for payout"
                    )

                    BalanceStatusCard(
                        title: "Pending",
                        amount: financeManager.pendingBalance,
                        status: .pending,
                        description: "Processing in 2-3 days"
                    )

                    BalanceStatusCard(
                        title: "Tax Reserve",
                        amount: financeManager.estimatedTax,
                        status: .tax,
                        description: "Estimated quarterly tax"
                    )
                }
            }

            // Quick actions with clear affordances
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button(action: onRequestPayout) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Request Payout")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Minimum $10.00")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .disabled(financeManager.availableBalance < 10)

                Button(action: onViewTaxDetails) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "doc.text.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("View estimates")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

/// Balance status card with clear visual indicators
struct BalanceStatusCard: View {
    let title: String
    let amount: Double
    let status: BalanceStatus
    let description: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Text("$\(amount, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(status.color.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.xxl)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Overview sections for main view
struct OverviewSections: View {
    let financeManager: FinanceManager
    @Binding var selectedPlatform: RevenuePlatform?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Revenue overview cards
            RevenueOverviewCards(
                revenues: financeManager.revenueByPlatform,
                selectedPlatform: $selectedPlatform
            )

            // Income sources breakdown
            IncomeSourcesBreakdown(
                sources: financeManager.incomeSources
            )

            // Recent activity
            RecentTransactionsView(
                transactions: financeManager.recentTransactions
            )
        }
    }
}

/// Analytics sections for detailed view
struct AnalyticsSections: View {
    let financeManager: FinanceManager
    let timeFrame: TimeFrame

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Revenue trend chart
            RevenueChartView(
                data: financeManager.revenueHistory,
                timeFrame: timeFrame
            )

            HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                // Platform performance
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    SectionHeaderView(
                        title: "Platform Performance",
                        subtitle: "Revenue by source"
                    )

                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(financeManager.revenueByPlatform.prefix(5), id: \.id) { revenue in
                            PlatformPerformanceRow(revenue: revenue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Growth metrics
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    SectionHeaderView(
                        title: "Growth Metrics",
                        subtitle: "Period over period"
                    )

                    VStack(spacing: DesignSystem.Spacing.md) {
                        GrowthMetricCard(
                            title: "Revenue Growth",
                            value: "+23.4%",
                            trend: .up,
                            description: "vs last month"
                        )

                        GrowthMetricCard(
                            title: "Average Daily",
                            value: "$156.78",
                            trend: .flat,
                            description: "daily average"
                        )

                        GrowthMetricCard(
                            title: "Best Day",
                            value: "$892.45",
                            trend: .up,
                            description: "single day record"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Transactions sections for detailed transaction view
struct TransactionsSections: View {
    let financeManager: FinanceManager

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Transaction filters and search
            TransactionFiltersView()

            // All transactions
            EnhancedTransactionsView(
                transactions: financeManager.recentTransactions
            )

            // Payout history
            PayoutHistoryView(
                payouts: financeManager.payoutHistory
            )
        }
    }
}

/// Tax sections for tax management
struct TaxSections: View {
    let financeManager: FinanceManager

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Quarterly tax estimate
            QuarterlyTaxCard(financeManager: financeManager)

            // Tax category breakdown
            TaxCategoryBreakdown(financeManager: financeManager)

            // Tax tips and reminders
            TaxTipsCard()
        }
    }
}

// MARK: - Supporting Components

/// Section header with consistent styling
struct SectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Platform performance row with clear metrics
struct PlatformPerformanceRow: View {
    let revenue: PlatformRevenue

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: revenue.platform.icon)
                .font(.title3)
                .foregroundColor(revenue.platform.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(revenue.platform.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("$\(revenue.amount, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: revenue.changePercent >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text("\(abs(revenue.changePercent), specifier: "%.1f")%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(revenue.changePercent >= 0 ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (revenue.changePercent >= 0 ? Color.green : Color.red).opacity(0.1)
            )
            .cornerRadius(DesignSystem.Radius.sm)
        }
        .padding(.vertical, 4)
    }
}

/// Growth metric card with trend indication
struct GrowthMetricCard: View {
    let title: String
    let value: String
    let trend: MetricTrend
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(trend.color)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(.regularMaterial)
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

/// Transaction filters with search
struct TransactionFiltersView: View {
    @State private var searchText = ""
    @State private var selectedType = TransactionType.income
    @State private var selectedPlatform: RevenuePlatform?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transactions", text: $searchText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(DesignSystem.Radius.lg)

                // Type filter
                Picker("Type", selection: $selectedType) {
                    Text("Income").tag(TransactionType.income)
                    Text("Expenses").tag(TransactionType.expense)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // Platform filter
                Picker("Platform", selection: $selectedPlatform) {
                    Text("All Platforms").tag(nil as RevenuePlatform?)
                    ForEach(RevenuePlatform.allCases, id: \.self) { platform in
                        Text(platform.displayName).tag(platform as RevenuePlatform?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(.regularMaterial)
        .cornerRadius(DesignSystem.Radius.xxl)
    }
}

/// Enhanced transactions view with better organization
struct EnhancedTransactionsView: View {
    let transactions: [Transaction]
    @State private var sortOrder = TransactionSortOrder.date

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("All Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Picker("Sort", selection: $sortOrder) {
                    Text("Date").tag(TransactionSortOrder.date)
                    Text("Amount").tag(TransactionSortOrder.amount)
                    Text("Platform").tag(TransactionSortOrder.platform)
                }
                .pickerStyle(.menu)
            }

            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(sortedTransactions) { transaction in
                    EnhancedTransactionRow(transaction: transaction)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(.regularMaterial)
        .cornerRadius(16)
    }

    private var sortedTransactions: [Transaction] {
        switch sortOrder {
        case .date:
            return transactions.sorted { $0.date > $1.date }
        case .amount:
            return transactions.sorted { $0.amount > $1.amount }
        case .platform:
            return transactions.sorted { ($0.platform?.displayName ?? "") < ($1.platform?.displayName ?? "") }
        }
    }
}

/// Enhanced transaction row with more detail
struct EnhancedTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Transaction type icon with platform overlay
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: transaction.type.icon)
                    .font(.title3)
                    .foregroundColor(transaction.type.color)

                if let platform = transaction.platform {
                    Image(systemName: platform.icon)
                        .font(.caption2)
                        .foregroundColor(platform.color)
                        .background(Circle().fill(.background))
                        .offset(x: 12, y: -12)
                }
            }

            // Transaction details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(transaction.date.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let platform = transaction.platform {
                        Text("• \(platform.displayName)")
                            .font(.caption)
                            .foregroundColor(platform.color)
                    }

                    if let sourceType = transaction.sourceType {
                        Text("• \(sourceType.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Amount with clear visual treatment
            Text("\(transaction.type == .expense ? "-" : "+")$\(abs(transaction.amount), specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background)
        .cornerRadius(DesignSystem.Radius.xxl)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Enhanced Sheet Components

/// Enhanced add income sheet with better validation
struct EnhancedAddIncomeSheet: View {
    let financeManager: FinanceManager
    @Environment(\.dismiss) var dismiss

    @State private var amount = ""
    @State private var description = ""
    @State private var source = IncomeSourceType.donations
    @State private var platform = RevenuePlatform.twitch
    @State private var date = Date()
    @State private var showingValidationErrors = false
    @State private var validationErrors: [String] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Form content
                Form {
                    Section("Income Details") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Amount *")
                                .font(.caption)
                                .fontWeight(.medium)

                            HStack {
                                Text("$")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                TextField("0.00", text: $amount)
                                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                                    .keyboardType(.decimalPad)
#endif
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Description *")
                                .font(.caption)
                                .fontWeight(.medium)

                            TextField("e.g., Twitch subscription revenue", text: $description)
                                .textFieldStyle(.roundedBorder)
                        }

                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }

                    Section("Categorization") {
                        Picker("Income Type", selection: $source) {
                            ForEach(IncomeSourceType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }

                        Picker("Platform", selection: $platform) {
                            ForEach(RevenuePlatform.allCases, id: \.self) { platform in
                                Label(platform.displayName, systemImage: platform.icon)
                                    .foregroundColor(platform.color)
                                    .tag(platform)
                            }
                        }
                    }

                    if showingValidationErrors && !validationErrors.isEmpty {
                        Section("Errors") {
                            ForEach(validationErrors, id: \.self) { error in
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle("Add Income")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Income") { saveIncome() }
                        .disabled(!isFormValid)
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private var isFormValid: Bool {
        !amount.isEmpty && !description.isEmpty && Double(amount) != nil && Double(amount) ?? 0 > 0
    }

    private func saveIncome() {
        validationErrors.removeAll()

        // Validate amount
        guard let amountValue = Double(amount), amountValue > 0 else {
            validationErrors.append("Please enter a valid amount greater than $0.00")
            showingValidationErrors = true
            return
        }

        // Validate description
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrors.append("Please enter a description")
            showingValidationErrors = true
            return
        }

        let transaction = Transaction(
            id: UUID(),
            date: date,
            amount: amountValue,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .income,
            platform: platform,
            sourceType: source
        )

        financeManager.addTransaction(transaction)
        dismiss()
    }
}

// MARK: - Supporting Types

enum FinancialViewMode: CaseIterable {
    case overview, analytics, transactions, taxes

    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .analytics: return "Analytics"
        case .transactions: return "Transactions"
        case .taxes: return "Taxes"
        }
    }
}

enum BalanceStatus {
    case available, pending, tax

    var color: Color {
        switch self {
        case .available: return .green
        case .pending: return .orange
        case .tax: return .blue
        }
    }
}

enum TransactionSortOrder {
    case date, amount, platform
}

// MARK: - Additional Components (Placeholder implementations)

struct EnhancedPayoutRequestSheet: View {
    let stripeService: StripeService
    let availableBalance: Double
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // Enhanced payout request with better validation and user guidance
        Text("Enhanced Payout Request - Implementation pending")
            .frame(width: 500, height: 400)
    }
}

struct TaxDetailSheet: View {
    let financeManager: FinanceManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // Detailed tax breakdown and projections
        Text("Tax Detail Sheet - Implementation pending")
            .frame(width: 600, height: 500)
    }
}

struct QuarterlyTaxCard: View {
    let financeManager: FinanceManager

    var body: some View {
        // Quarterly tax estimates and recommendations
        Text("Quarterly Tax Card - Implementation pending")
    }
}

struct TaxCategoryBreakdown: View {
    let financeManager: FinanceManager

    var body: some View {
        // Tax deductible categories and amounts
        Text("Tax Category Breakdown - Implementation pending")
    }
}

struct TaxTipsCard: View {
    var body: some View {
        // Tax saving tips and reminders
        Text("Tax Tips Card - Implementation pending")
    }
}

// MARK: - Supporting Types
enum MetricTrend {
    case up, down, flat

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .flat: return .gray
        }
    }

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "minus"
        }
    }
}
