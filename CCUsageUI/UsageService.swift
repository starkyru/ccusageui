import AppKit
import Combine

// MARK: - JSON models for ccusage blocks --active --token-limit max --json

struct BlocksResponse: Codable {
    let blocks: [BlockEntry]
}

struct BlockEntry: Codable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let startTime: String
    let endTime: String
    let tokenLimitStatus: TokenLimitStatus?

    struct Projection: Codable {
        let remainingMinutes: Int?
    }
    let projection: Projection?
}

struct TokenLimitStatus: Codable {
    let limit: Int
    let percentUsed: Double
}

// MARK: - JSON models for ccusage weekly --json

struct WeeklyResponse: Codable {
    let weekly: [WeeklyEntry]
}

struct WeeklyEntry: Codable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
}

// MARK: - Usage level

enum UsageLevel {
    case low, medium, high, critical

    var color: NSColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemYellow
        case .high: return .systemRed
        case .critical: return .black
        }
    }
}

// MARK: - Service

class UsageService: ObservableObject {
    // Session block
    @Published var sessionTokensUsed: Int = 0
    @Published var sessionTokenLimit: Int = 0
    @Published var sessionPercentage: Double = 0
    @Published var sessionResetTime: Date?
    @Published var sessionRemainingMinutes: Int = 0

    // Weekly
    @Published var weeklyTokensUsed: Int = 0
    @Published var weeklyTokenLimit: Int = 0
    @Published var weeklyPercentage: Double = 0

    // General
    @Published var rawOutput: String = "Loading..."
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    // Thresholds
    var greenThreshold: Double {
        get { UserDefaults.standard.object(forKey: "greenThreshold") as? Double ?? 50 }
        set { UserDefaults.standard.set(newValue, forKey: "greenThreshold"); objectWillChange.send() }
    }

    var yellowThreshold: Double {
        get { UserDefaults.standard.object(forKey: "yellowThreshold") as? Double ?? 70 }
        set { UserDefaults.standard.set(newValue, forKey: "yellowThreshold"); objectWillChange.send() }
    }

    var redThreshold: Double {
        get { UserDefaults.standard.object(forKey: "redThreshold") as? Double ?? 90 }
        set { UserDefaults.standard.set(newValue, forKey: "redThreshold"); objectWillChange.send() }
    }

    var refreshInterval: Double {
        get { UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval"); objectWillChange.send() }
    }

    private var timer: Timer?

    init() {
        startTimer()
        fetchUsage()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval * 60, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func restartTimer() {
        startTimer()
    }

    // MARK: - Computed colors

    var sessionColor: UsageLevel { usageLevel(for: sessionPercentage) }
    var weeklyColor: UsageLevel { usageLevel(for: weeklyPercentage) }

    private func usageLevel(for percentage: Double) -> UsageLevel {
        if percentage >= redThreshold {
            return percentage >= 100 ? .critical : .high
        } else if percentage >= yellowThreshold {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Fetch

    func fetchUsage() {
        isLoading = true

        // 1. ccusage blocks --active --token-limit max --json
        let blocksJsonTask = Process()
        blocksJsonTask.executableURL = URL(fileURLWithPath: "/bin/zsh")
        blocksJsonTask.arguments = ["-l", "-c", "ccusage blocks --active --token-limit max --json"]
        let blocksJsonPipe = Pipe()
        blocksJsonTask.standardOutput = blocksJsonPipe
        blocksJsonTask.standardError = Pipe()

        // 2. ccusage weekly --json
        let weeklyTask = Process()
        weeklyTask.executableURL = URL(fileURLWithPath: "/bin/zsh")
        weeklyTask.arguments = ["-l", "-c", "ccusage weekly --json"]
        let weeklyPipe = Pipe()
        weeklyTask.standardOutput = weeklyPipe
        weeklyTask.standardError = Pipe()

        // 3. ccusage blocks --active (plain text for popover)
        let textTask = Process()
        textTask.executableURL = URL(fileURLWithPath: "/bin/zsh")
        textTask.arguments = ["-l", "-c", "ccusage blocks --active"]
        let textPipe = Pipe()
        textTask.standardOutput = textPipe
        textTask.standardError = Pipe()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try blocksJsonTask.run()
                try weeklyTask.run()
                try textTask.run()

                blocksJsonTask.waitUntilExit()
                weeklyTask.waitUntilExit()
                textTask.waitUntilExit()

                let blocksData = blocksJsonPipe.fileHandleForReading.readDataToEndOfFile()
                let weeklyData = weeklyPipe.fileHandleForReading.readDataToEndOfFile()
                let textData = textPipe.fileHandleForReading.readDataToEndOfFile()
                let textOutput = String(data: textData, encoding: .utf8) ?? "No output"

                // Parse blocks
                var sUsed = 0
                var sLimit = 0
                var sPct = 0.0
                var sResetTime: Date?
                var sRemaining = 0

                if let blocks = try? JSONDecoder().decode(BlocksResponse.self, from: blocksData),
                   let active = blocks.blocks.first {
                    sUsed = active.totalTokens
                    sLimit = active.tokenLimitStatus?.limit ?? 0
                    sPct = active.tokenLimitStatus?.percentUsed ?? 0
                    sRemaining = active.projection?.remainingMinutes ?? 0

                    // Parse endTime (ISO8601)
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    sResetTime = formatter.date(from: active.endTime)
                    if sResetTime == nil {
                        formatter.formatOptions = [.withInternetDateTime]
                        sResetTime = formatter.date(from: active.endTime)
                    }
                }

                // Parse weekly
                var wUsed = 0
                var wLimit = 0
                var wPct = 0.0

                if let weekly = try? JSONDecoder().decode(WeeklyResponse.self, from: weeklyData),
                   let lastWeek = weekly.weekly.last {
                    wUsed = lastWeek.totalTokens
                    // Weekly limit = session block limit × 33 blocks per week
                    wLimit = sLimit * 33
                    if wLimit > 0 {
                        wPct = min(Double(wUsed) / Double(wLimit) * 100, 100)
                    }
                }

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.sessionTokensUsed = sUsed
                    self.sessionTokenLimit = sLimit
                    self.sessionPercentage = sPct
                    self.sessionResetTime = sResetTime
                    self.sessionRemainingMinutes = sRemaining
                    self.weeklyTokensUsed = wUsed
                    self.weeklyTokenLimit = wLimit
                    self.weeklyPercentage = wPct
                    self.rawOutput = textOutput
                    self.lastUpdated = Date()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.rawOutput = "Error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }
    }

    // MARK: - Formatting helpers

    static func formatTokens(_ tokens: Int) -> String {
        let millions = Double(tokens) / 1_000_000.0
        return String(format: "%.1fM", millions)
    }
}
