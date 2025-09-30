import Foundation

// MARK: - Stripe Service for Income Tracking
class StripeService: ObservableObject {
    @Published var isConnected = false
    @Published var accountBalance: StripeBalance?
    @Published var recentPayouts: [StripePayout] = []
    @Published var recentCharges: [StripeCharge] = []
    @Published var subscriptions: [StripeSubscription] = []
    @Published var customers: [StripeCustomer] = []
    @Published var disputedCharges: [StripeDispute] = []

    private let apiKey: String? = ProcessInfo.processInfo.environment["STRIPE_API_KEY"]
    private let accountId: String? = ProcessInfo.processInfo.environment["STRIPE_ACCOUNT_ID"]

    init() {
        // Load mock data for development
        loadMockData()
    }

    // MARK: - Connect Stripe Account (for OAuth)
    func connectAccount() async {
        // In production, this would handle OAuth flow
        await MainActor.run {
            self.isConnected = true
        }
    }

    // MARK: - Fetch Balance
    func fetchBalance() async {
        // Mock implementation - would call Stripe API in production
        await MainActor.run {
            self.accountBalance = StripeBalance(
                available: 12888.89,
                pending: 2345.67,
                currency: "usd"
            )
        }
    }

    // MARK: - Fetch Recent Transactions
    func fetchRecentTransactions(limit: Int = 100) async {
        // Would call Stripe API: GET /v1/charges
        await MainActor.run {
            self.recentCharges = generateMockCharges()
        }
    }

    // MARK: - Fetch Payouts
    func fetchPayouts() async {
        // Would call Stripe API: GET /v1/payouts
        await MainActor.run {
            self.recentPayouts = generateMockPayouts()
        }
    }

    // MARK: - Request Payout (tracking only)
    func requestPayout(amount: Double, account: String) async {
        // This would log the payout request for tracking
        // Actual payout would be handled through Stripe Dashboard
        let payout = StripePayout(
            id: "po_\(UUID().uuidString.prefix(24))",
            amount: amount,
            currency: "usd",
            arrivalDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            created: Date(),
            status: .pending,
            type: .bank,
            method: .standard,
            description: "Manual payout request"
        )

        await MainActor.run {
            self.recentPayouts.insert(payout, at: 0)
        }
    }

    // MARK: - Fetch Subscriptions
    func fetchSubscriptions() async {
        // Would call Stripe API: GET /v1/subscriptions
        await MainActor.run {
            self.subscriptions = generateMockSubscriptions()
        }
    }

    // MARK: - Calculate Revenue Metrics
    func calculateMonthlyRecurringRevenue() -> Double {
        subscriptions
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    func calculateChurn() -> Double {
        let total = Double(subscriptions.count)
        let cancelled = Double(subscriptions.filter { $0.status == .canceled }.count)
        return total > 0 ? (cancelled / total) * 100 : 0
    }

    func calculateAverageTransactionValue() -> Double {
        let total = recentCharges.reduce(0) { $0 + $1.amount }
        return recentCharges.count > 0 ? total / Double(recentCharges.count) : 0
    }

    // MARK: - Export for Tax Purposes
    func exportTransactionsCSV(startDate: Date, endDate: Date) -> String {
        var csv = "Date,Description,Amount,Fee,Net,Type,Status\n"

        for charge in recentCharges {
            if charge.created >= startDate && charge.created <= endDate {
                let net = charge.amount - charge.fee
                csv += "\(charge.created),\(charge.description),\(charge.amount),\(charge.fee),\(net),charge,\(charge.status.rawValue)\n"
            }
        }

        for payout in recentPayouts {
            if payout.created >= startDate && payout.created <= endDate {
                csv += "\(payout.created),\(payout.description ?? "Payout"),\(payout.amount),0,\(payout.amount),payout,\(payout.status.rawValue)\n"
            }
        }

        return csv
    }

    // MARK: - Mock Data Generation
    private func loadMockData() {
        accountBalance = StripeBalance(
            available: 12888.89,
            pending: 2345.67,
            currency: "usd"
        )

        recentCharges = generateMockCharges()
        recentPayouts = generateMockPayouts()
        subscriptions = generateMockSubscriptions()
        customers = generateMockCustomers()
        disputedCharges = generateMockDisputes()
    }

    private func generateMockCharges() -> [StripeCharge] {
        return [
            StripeCharge(
                id: "ch_1",
                amount: 99.99,
                currency: "usd",
                description: "Premium Subscription - John Doe",
                created: Date().addingTimeInterval(-3600),
                status: .succeeded,
                fee: 3.20,
                customer: "cus_1",
                paymentMethod: .card
            ),
            StripeCharge(
                id: "ch_2",
                amount: 49.99,
                currency: "usd",
                description: "One-time donation - Jane Smith",
                created: Date().addingTimeInterval(-7200),
                status: .succeeded,
                fee: 1.75,
                customer: "cus_2",
                paymentMethod: .card
            ),
            StripeCharge(
                id: "ch_3",
                amount: 199.99,
                currency: "usd",
                description: "Annual Subscription - Bob Wilson",
                created: Date().addingTimeInterval(-10800),
                status: .succeeded,
                fee: 6.10,
                customer: "cus_3",
                paymentMethod: .card
            ),
            StripeCharge(
                id: "ch_4",
                amount: 25.00,
                currency: "usd",
                description: "Tip - Anonymous",
                created: Date().addingTimeInterval(-14400),
                status: .succeeded,
                fee: 1.03,
                customer: nil,
                paymentMethod: .card
            ),
            StripeCharge(
                id: "ch_5",
                amount: 500.00,
                currency: "usd",
                description: "Corporate Sponsorship - TechCorp",
                created: Date().addingTimeInterval(-86400),
                status: .succeeded,
                fee: 15.00,
                customer: "cus_4",
                paymentMethod: .bank_transfer
            )
        ]
    }

    private func generateMockPayouts() -> [StripePayout] {
        return [
            StripePayout(
                id: "po_1",
                amount: 5000.00,
                currency: "usd",
                arrivalDate: Date().addingTimeInterval(-86400),
                created: Date().addingTimeInterval(-259200),
                status: .paid,
                type: .bank,
                method: .standard,
                description: "Regular payout"
            ),
            StripePayout(
                id: "po_2",
                amount: 3500.00,
                currency: "usd",
                arrivalDate: Date().addingTimeInterval(-604800),
                created: Date().addingTimeInterval(-777600),
                status: .paid,
                type: .bank,
                method: .standard,
                description: "Regular payout"
            ),
            StripePayout(
                id: "po_3",
                amount: 1500.00,
                currency: "usd",
                arrivalDate: Date().addingTimeInterval(172800),
                created: Date(),
                status: .pending,
                type: .bank,
                method: .instant,
                description: "Instant payout"
            )
        ]
    }

    private func generateMockSubscriptions() -> [StripeSubscription] {
        return [
            StripeSubscription(
                id: "sub_1",
                customer: "cus_1",
                status: .active,
                currentPeriodStart: Date().addingTimeInterval(-2592000),
                currentPeriodEnd: Date().addingTimeInterval(86400),
                monthlyAmount: 9.99,
                currency: "usd",
                productName: "Basic Tier"
            ),
            StripeSubscription(
                id: "sub_2",
                customer: "cus_2",
                status: .active,
                currentPeriodStart: Date().addingTimeInterval(-1296000),
                currentPeriodEnd: Date().addingTimeInterval(1296000),
                monthlyAmount: 24.99,
                currency: "usd",
                productName: "Pro Tier"
            ),
            StripeSubscription(
                id: "sub_3",
                customer: "cus_3",
                status: .active,
                currentPeriodStart: Date().addingTimeInterval(-864000),
                currentPeriodEnd: Date().addingTimeInterval(1728000),
                monthlyAmount: 49.99,
                currency: "usd",
                productName: "Premium Tier"
            ),
            StripeSubscription(
                id: "sub_4",
                customer: "cus_4",
                status: .canceled,
                currentPeriodStart: Date().addingTimeInterval(-5184000),
                currentPeriodEnd: Date().addingTimeInterval(-2592000),
                monthlyAmount: 9.99,
                currency: "usd",
                productName: "Basic Tier"
            )
        ]
    }

    private func generateMockCustomers() -> [StripeCustomer] {
        return [
            StripeCustomer(
                id: "cus_1",
                email: "john.doe@example.com",
                name: "John Doe",
                created: Date().addingTimeInterval(-2592000),
                subscriptions: 1,
                totalSpent: 299.70
            ),
            StripeCustomer(
                id: "cus_2",
                email: "jane.smith@example.com",
                name: "Jane Smith",
                created: Date().addingTimeInterval(-1296000),
                subscriptions: 1,
                totalSpent: 374.85
            ),
            StripeCustomer(
                id: "cus_3",
                email: "bob.wilson@example.com",
                name: "Bob Wilson",
                created: Date().addingTimeInterval(-864000),
                subscriptions: 1,
                totalSpent: 499.95
            )
        ]
    }

    private func generateMockDisputes() -> [StripeDispute] {
        return [
            StripeDispute(
                id: "dp_1",
                amount: 99.99,
                currency: "usd",
                reason: .fraudulent,
                status: .under_review,
                created: Date().addingTimeInterval(-86400),
                chargeId: "ch_disputed"
            )
        ]
    }
}

// MARK: - Stripe Data Models
struct StripeBalance {
    let available: Double
    let pending: Double
    let currency: String
}

struct StripeCharge: Identifiable {
    let id: String
    let amount: Double
    let currency: String
    let description: String
    let created: Date
    let status: ChargeStatus
    let fee: Double
    let customer: String?
    let paymentMethod: PaymentMethod

    enum ChargeStatus: String {
        case succeeded = "succeeded"
        case pending = "pending"
        case failed = "failed"
    }

    enum PaymentMethod {
        case card
        case bank_transfer
        case ach
        case sepa
    }
}

struct StripePayout: Identifiable {
    let id: String
    let amount: Double
    let currency: String
    let arrivalDate: Date
    let created: Date
    let status: PayoutStatus
    let type: PayoutType
    let method: PayoutMethod
    let description: String?

    enum PayoutStatus: String {
        case paid = "paid"
        case pending = "pending"
        case in_transit = "in_transit"
        case canceled = "canceled"
        case failed = "failed"
    }

    enum PayoutType {
        case bank
        case card
    }

    enum PayoutMethod {
        case standard
        case instant
    }
}

struct StripeSubscription: Identifiable {
    let id: String
    let customer: String
    let status: SubscriptionStatus
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let monthlyAmount: Double
    let currency: String
    let productName: String

    enum SubscriptionStatus: String {
        case active = "active"
        case past_due = "past_due"
        case canceled = "canceled"
        case trialing = "trialing"
        case incomplete = "incomplete"
    }
}

struct StripeCustomer: Identifiable {
    let id: String
    let email: String
    let name: String
    let created: Date
    let subscriptions: Int
    let totalSpent: Double
}

struct StripeDispute: Identifiable {
    let id: String
    let amount: Double
    let currency: String
    let reason: DisputeReason
    let status: DisputeStatus
    let created: Date
    let chargeId: String

    enum DisputeReason: String {
        case duplicate = "duplicate"
        case fraudulent = "fraudulent"
        case subscription_canceled = "subscription_canceled"
        case product_unacceptable = "product_unacceptable"
        case product_not_received = "product_not_received"
        case unrecognized = "unrecognized"
        case credit_not_processed = "credit_not_processed"
        case general = "general"
    }

    enum DisputeStatus: String {
        case warning_needs_response = "warning_needs_response"
        case warning_under_review = "warning_under_review"
        case warning_closed = "warning_closed"
        case needs_response = "needs_response"
        case under_review = "under_review"
        case charge_refunded = "charge_refunded"
        case won = "won"
        case lost = "lost"
    }
}