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
        title: "DubCub",
        subtitle: "欢迎来到你的配音工作台",
        message: "这是用于验证 iPhone 和 iPad 安装的起始页面，配音功能将在后续加入。"
    )
}
