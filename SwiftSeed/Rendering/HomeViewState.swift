public struct HomeViewState: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let message: String

    public init(title: String, subtitle: String, message: String) {
        self.title = title
        self.subtitle = subtitle
        self.message = message
    }

    public static let initial = HomeViewState(
        title: "SwiftSeed",
        subtitle: "从这里开始你的下一个 App",
        message: "这是支持 iPhone 和 iPad 的 Swift 应用模板。替换此页面，开始你的第一个功能。"
    )
}
