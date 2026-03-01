import AppKit
import Combine

struct UsageData: Codable {
    struct DailyEntry: Codable {
        let date: String
        let totalCost: Double
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let modelsUsed: [String]
    }

    struct Totals: Codable {
        let totalCost: Double
        let totalTokens: Int
    }

    let daily: [DailyEntry]
    let totals: Totals
}

class UsageService: ObservableObject {
    @Published var currentCost: Double = 0
    @Published var percentage: Double = 0
    @Published var rawOutput: String = "Loading..."
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var usageData: UsageData?

    var dailyBudget: Double {
        get { UserDefaults.standard.object(forKey: "dailyBudget") as? Double ?? 100.0 }
        set { UserDefaults.standard.set(newValue, forKey: "dailyBudget"); objectWillChange.send() }
    }

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

    func fetchUsage() {
        isLoading = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let today = dateFormatter.string(from: Date())

        let jsonTask = Process()
        jsonTask.executableURL = URL(fileURLWithPath: "/bin/zsh")
        jsonTask.arguments = ["-l", "-c", "ccusage daily --json --since \(today)"]

        let jsonPipe = Pipe()
        jsonTask.standardOutput = jsonPipe
        jsonTask.standardError = Pipe()

        let textTask = Process()
        textTask.executableURL = URL(fileURLWithPath: "/bin/zsh")
        textTask.arguments = ["-l", "-c", "ccusage daily --since \(today)"]

        let textPipe = Pipe()
        textTask.standardOutput = textPipe
        textTask.standardError = Pipe()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try jsonTask.run()
                try textTask.run()

                jsonTask.waitUntilExit()
                textTask.waitUntilExit()

                let jsonData = jsonPipe.fileHandleForReading.readDataToEndOfFile()
                let textData = textPipe.fileHandleForReading.readDataToEndOfFile()
                let textOutput = String(data: textData, encoding: .utf8) ?? "No output"

                var cost: Double = 0
                var parsed: UsageData?

                if let data = try? JSONDecoder().decode(UsageData.self, from: jsonData) {
                    cost = data.totals.totalCost
                    parsed = data
                }

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.currentCost = cost
                    self.percentage = self.dailyBudget > 0 ? min((cost / self.dailyBudget) * 100, 100) : 0
                    self.rawOutput = textOutput
                    self.usageData = parsed
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

    var usageColor: UsageLevel {
        if percentage >= redThreshold {
            return percentage >= 100 ? .critical : .high
        } else if percentage >= yellowThreshold {
            return .medium
        } else {
            return .low
        }
    }
}

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
