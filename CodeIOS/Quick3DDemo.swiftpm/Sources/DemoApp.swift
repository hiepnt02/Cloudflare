//
//  DemoApp.swift
//  Quick3DDemo
//
//  Tầng ① — vỏ SwiftUI. Tương đương App/router của web.
//  Trong project thật: MainScreen.swift → NavigationLink(ViewARScreen(...))
//

import SwiftUI
import Metal

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeScreen()
            }
        }
    }
}

struct HomeScreen: View {
    private var metalName: String {
        MTLCreateSystemDefaultDevice()?.name ?? "KHÔNG CÓ Metal (máy ảo?) — demo sẽ không vẽ được"
    }

    var body: some View {
        List {
            Section("Demo") {
                NavigationLink("1. View 3D (SCNView, xoay bằng tay — chạy được Simulator)") {
                    Demo3DScreen()
                }
                NavigationLink("2. View AR (ARSCNView — cần iPad/iPhone thật)") {
                    DemoARScreen()
                }
            }
            Section("Thiết bị") {
                Text("Metal: \(metalName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Mỗi màn hình đi qua đúng 6 tầng như project") {
                Text("SwiftUI screen → UIViewRepresentable → SCNView/ARSCNView → Context (scene graph) → SCNGeometry từ MTLBuffer + SCNProgram → Shaders.metal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Quick3D 3D demo")
    }
}
