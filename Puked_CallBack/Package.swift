// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Puked_CallBack",
    platforms: [
        .macOS(.v15) // 确保支持 macOS 15 Sequoia 及以上
    ],
    products: [
        .executable(name: "Puked_CallBack", targets: ["Puked_CallBack"])
    ],
    dependencies: [
        // 如果后续需要添加第三方库，可以在这里添加
    ],
    targets: [
        .executableTarget(
            name: "Puked_CallBack",
            path: "Sources",
            resources: [
                .process("../Resources") // 包含资源文件夹
            ]
        )
    ]
)
