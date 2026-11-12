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
        subtitle: "Your next app starts here",
        message: "A Swift app template for iPhone and iPad. Replace this screen to build your first feature."
    )
}
