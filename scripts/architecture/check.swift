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
            reject(node, "渲染模块只能导入 SwiftUI；服务和状态实现应由外层连接。")
        }
        return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.attributeName.trimmedDescription.split(separator: ".").last.map(String.init) ?? ""
        if !["ViewBuilder", "available", "MainActor"].contains(name) {
            reject(node, "渲染层不允许 @\(name)；状态持有、观察和绑定应由外层处理。")
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isMember = node.parent?.is(MemberBlockItemSyntax.self) == true
        let isGlobal = node.parent?.parent?.parent?.is(SourceFileSyntax.self) == true
        guard node.bindingSpecifier.text == "var", isMember || isGlobal else { return .visitChildren }

        for binding in node.bindings {
            guard let block = binding.accessorBlock else {
                reject(binding, "渲染层的存储属性必须是 let，不能持有可变状态。")
                continue
            }
            switch block.accessors {
            case .getter:
                break
            case let .accessors(accessors):
                if accessors.contains(where: { $0.accessorSpecifier.text != "get" }) {
                    reject(binding, "渲染层不能提供 setter 或属性观察器。")
                }
            @unknown default:
                reject(binding, "未知属性访问方式，需先更新架构检查。")
            }
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        reject(node, "渲染模块使用值类型；引用状态和服务应放在外层。")
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        reject(node, "渲染模块不得定义状态所有者或服务。")
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
            reject(token, "渲染层不能使用 \(name)；生命周期、绑定和副作用应由外层处理。")
        }
        return .visitChildren
    }
}

func check(source: String, file: String) -> [String] {
    let tree = Parser.parse(source: source)
    guard !tree.hasError else { return ["\(file):1:1: error: 无法解析，不能跳过架构检查。"] }
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
        print("error: 架构检查误拒绝合法样例 \(index)")
        failures += 1
    }
    for (index, source) in rejected.enumerated()
        where check(source: source, file: "rejected-\(index)").isEmpty
    {
        print("error: 架构检查漏过违规样例 \(index)")
        failures += 1
    }
    print("架构规则验证：\(allowed.count + rejected.count) 个样例，\(failures) 个失败。")
    return failures == 0
}

if CommandLine.arguments.dropFirst() == ["--self-test"] {
    exit(selfTest() ? 0 : 1)
}

let roots = CommandLine.arguments.dropFirst()
guard !roots.isEmpty else {
    print("error: 请提供渲染代码目录。")
    exit(1)
}

var files: [URL] = []
for root in roots {
    guard let entries = FileManager.default.enumerator(
        at: URL(fileURLWithPath: root),
        includingPropertiesForKeys: nil
    ) else {
        print("error: 无法读取目录 \(root)")
        exit(1)
    }
    for case let file as URL in entries where file.pathExtension == "swift" {
        files.append(file)
    }
}

guard !files.isEmpty else {
    print("error: 未找到渲染代码，检查不能空跑。")
    exit(1)
}

var diagnostics: [String] = []
for file in files.sorted(by: { $0.path < $1.path }) {
    diagnostics += try check(source: String(contentsOf: file, encoding: .utf8), file: file.path)
}

diagnostics.forEach { print($0) }
if diagnostics.isEmpty {
    print("渲染边界检查通过（\(files.count) 个文件）。")
}

exit(diagnostics.isEmpty ? 0 : 1)
