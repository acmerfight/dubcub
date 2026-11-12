import Foundation
import SwiftParser
import SwiftSyntax

/// These checks enforce structural boundaries, not semantic purity or good schema design.
final class RenderingRules: SyntaxVisitor {
    private let location: SourceLocationConverter
    private(set) var diagnostics: [String] = []

    init(tree: SourceFileSyntax, file: String) {
        location = SourceLocationConverter(fileName: file, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    private func reject(_ node: some SyntaxProtocol, _ message: String) {
        let position = location.location(for: node.positionAfterSkippingLeadingTrivia)
        diagnostics.append("\(position.file):\(position.line):\(position.column): error: \(message)")
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.path.first?.name.text != "SwiftUI" {
            reject(node, "Rendering may only import SwiftUI; connect services and state in outer layers.")
        }
        return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.attributeName.trimmedDescription.split(separator: ".").last.map(String.init) ?? ""
        if !["ViewBuilder", "available", "MainActor"].contains(name) {
            reject(node, "Rendering cannot use @\(name); own, observe, and bind state in outer layers.")
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isMember = node.parent?.is(MemberBlockItemSyntax.self) == true
        let isGlobal = node.parent?.parent?.parent?.is(SourceFileSyntax.self) == true
        guard node.bindingSpecifier.text == "var", isMember || isGlobal else { return .visitChildren }

        for binding in node.bindings {
            guard let block = binding.accessorBlock else {
                reject(binding, "Rendering stored properties must use let; mutable state is not allowed.")
                continue
            }
            switch block.accessors {
            case .getter:
                break
            case let .accessors(accessors):
                if accessors.contains(where: { $0.accessorSpecifier.text != "get" }) {
                    reject(binding, "Rendering cannot provide setters or property observers.")
                }
            @unknown default:
                reject(binding, "Unknown property accessor; update the architecture checker first.")
            }
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        reject(node, "Use value types in rendering; keep reference state and services in outer layers.")
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        reject(node, "Rendering must not define state owners or services.")
        return .visitChildren
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        guard case let .identifier(name) = token.tokenKind else { return .visitChildren }
        let forbidden: Set = [
            "Task", "TaskGroup", "DispatchQueue", "URLSession", "FileManager", "UserDefaults",
            "NotificationCenter", "ModelContext", "NSManagedObjectContext", "UIApplication",
            "AVAudioSession", "AVAudioRecorder", "AVPlayer", "Binding",
            "task", "onAppear", "onDisappear", "onChange", "onReceive",
        ]
        if forbidden.contains(name) {
            reject(
                token,
                "Rendering cannot use \(name); handle lifecycle, bindings, and side effects in outer layers."
            )
        }
        return .visitChildren
    }
}

func check(source: String, file: String) -> [String] {
    let tree = Parser.parse(source: source)
    guard !tree.hasError
    else { return ["\(file):1:1: error: Cannot parse source; architecture checks must not be skipped."] }
    let rules = RenderingRules(tree: tree, file: file)
    rules.walk(tree)
    return rules.diagnostics
}

func selfTest() -> Bool {
    let allowed = [
        "import SwiftUI; struct Screen: View { let title: String; var body: some View { Text(title) } }",
        "struct Input { let value: Int; var doubled: Int { value * 2 }; let onTap: () -> Void }",
        "struct Input { let text = \"@State var count = 0; Task {}\" /* @State var count = 0 */ }",
        "struct Input { func sum() -> Int { var result = 0; result += 1; return result } }",
    ]
    let rejected = [
        "import SwiftData",
        "import class Foundation.UserDefaults",
        "struct Screen { @State var count = 0 }",
        "struct Screen { @SwiftUI.State private var count = 0 }",
        "struct Screen { @Query var records: [Record] }",
        "struct Screen { @Environment(Service.self) var service }",
        "struct Input { var count = 0 }",
        "var count = 0",
        "struct Input { var count: Int { get { 0 } set {} } }",
        "struct Input { var count = 0 { didSet {} } }",
        "class Store {}",
        "actor Store {}",
        "func render() { Task { await save() } }",
        "func render() { Text(\"Hi\").task { await load() } }",
        "func render() { URLSession.shared }",
        "func render() { Text(\"\\(UserDefaults.standard)\") }",
        "struct Broken {",
    ]
    var failures = 0
    for (index, source) in allowed.enumerated()
        where !check(source: source, file: "allowed-\(index)").isEmpty
    {
        print("error: Architecture checker rejected valid fixture \(index)")
        failures += 1
    }
    for (index, source) in rejected.enumerated()
        where check(source: source, file: "rejected-\(index)").isEmpty
    {
        print("error: Architecture checker accepted invalid fixture \(index)")
        failures += 1
    }
    print("Architecture checks: \(allowed.count + rejected.count) fixtures, \(failures) failures.")
    return failures == 0
}

if CommandLine.arguments.dropFirst() == ["--self-test"] {
    exit(selfTest() ? 0 : 1)
}

let roots = CommandLine.arguments.dropFirst()
guard !roots.isEmpty else {
    print("error: Provide the rendering source directory.")
    exit(1)
}

var files: [URL] = []
for root in roots {
    guard let entries = FileManager.default.enumerator(
        at: URL(fileURLWithPath: root),
        includingPropertiesForKeys: nil
    ) else {
        print("error: Cannot read directory \(root)")
        exit(1)
    }
    for case let file as URL in entries where file.pathExtension == "swift" {
        files.append(file)
    }
}

guard !files.isEmpty else {
    print("error: No rendering source found; checks must not run empty.")
    exit(1)
}

var diagnostics: [String] = []
for file in files.sorted(by: { $0.path < $1.path }) {
    diagnostics += try check(source: String(contentsOf: file, encoding: .utf8), file: file.path)
}

diagnostics.forEach { print($0) }
if diagnostics.isEmpty {
    print("Rendering boundary checks passed (\(files.count) files).")
}

exit(diagnostics.isEmpty ? 0 : 1)
