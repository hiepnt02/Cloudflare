// swift-tools-version: 5.9
// App Playground package: Xcode 15+ mở thẳng folder Quick3DDemo.swiftpm là build/run được.
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Quick3DDemo",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "Quick3DDemo",
            targets: ["Quick3DDemo"],
            bundleIdentifier: "local.demo.quick3d-3dview",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bird),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
            // Màn AR cần quyền camera → sinh NSCameraUsageDescription
            capabilities: [.camera(purposeString: "Demo AR: vẽ point cloud lên hình camera")],
            appCategory: .developerTools
        )
    ],
    targets: [
        .executableTarget(
            name: "Quick3DDemo",
            path: "Sources",
            // Xcode biên dịch Shaders.metal → default.metallib trong Bundle.module
            resources: [.process("Shaders.metal")]
        )
    ]
)
