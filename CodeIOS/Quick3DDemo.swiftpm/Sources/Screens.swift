//
//  Screens.swift
//  Quick3DDemo
//
//  Tầng ① — màn hình SwiftUI. Giữ context, nhét vào view, chỉ nói chuyện với 3D
//  qua Event (xuống) và Delegate (lên).
//  Trong project thật: Camera/UI/ViewAR/ViewARScreen.swift
//

import SwiftUI
import simd

/// Nhận delegate từ 3D và đẩy vào @Published để SwiftUI vẽ lại.
@MainActor
final class DemoStatus: ObservableObject, DemoDelegate {
    @Published var status: String = "…"
    @Published var pointCount: Int = 0
    @Published var placedAt: String = "—"

    nonisolated func demo(didLoad pointCount: Int) {
        Task { @MainActor in
            self.pointCount = pointCount
            self.status = "Đã tạo \(pointCount) điểm"
        }
    }
    nonisolated func demo(didPlaceAt position: SIMD3<Float>) {
        Task { @MainActor in
            self.placedAt = String(format: "x %.2f  y %.2f  z %.2f", position.x, position.y, position.z)
            self.status = "Đã đặt model trước mặt"
        }
    }
    nonisolated func demo(status: String) {
        Task { @MainActor in self.status = status }
    }
}

// MARK: - Bảng điều khiển dùng chung

struct ControlPanel: View {
    let perform: (DemoEvent) -> Void
    let showRecenter: Bool
    @ObservedObject var model: DemoStatus

    @State private var pointSize: Double = 14
    @State private var opacity: Double = 1
    @State private var visible = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.status).font(.footnote.bold())
            if showRecenter { Text("Vị trí arNode: \(model.placedAt)").font(.footnote) }

            HStack {
                Text("Point size").frame(width: 90, alignment: .leading)
                Slider(value: $pointSize, in: 2...40)
                    .onChange(of: pointSize) { v in perform(ChangePointSizeEvent(Float(v))) }
                Text("\(Int(pointSize))").frame(width: 30)
            }
            HStack {
                Text("Opacity").frame(width: 90, alignment: .leading)
                Slider(value: $opacity, in: 0...1)
                    .onChange(of: opacity) { v in perform(ChangeOpacityEvent(Float(v))) }
                Text(String(format: "%.2f", opacity)).frame(width: 40)
            }
            HStack {
                Toggle("Hiện point cloud", isOn: $visible)
                    .onChange(of: visible) { v in perform(TogglePointCloudEvent(v)) }
                if showRecenter {
                    Button("Đặt lại trước mặt") { perform(RecenterEvent()) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .font(.callout)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(12)
    }
}

// MARK: - Màn 1: 3D thường

struct Demo3DScreen: View {
    @State private var context = Demo3DContext()
    @StateObject private var model = DemoStatus()

    var body: some View {
        ZStack(alignment: .bottom) {
            Demo3DView(context: context)
                .ignoresSafeArea()
            ControlPanel(perform: { context.perform($0) }, showRecenter: false, model: model)
        }
        .navigationTitle("View 3D")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { context.delegate = model }        // kênh 3D → UI
    }
}

// MARK: - Màn 2: AR

struct DemoARScreen: View {
    @State private var context = DemoARContext()
    @StateObject private var model = DemoStatus()

    var body: some View {
        ZStack(alignment: .bottom) {
            DemoARView(context: context)
                .ignoresSafeArea()
            ControlPanel(perform: { context.perform($0) }, showRecenter: true, model: model)
        }
        .navigationTitle("View AR")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { context.delegate = model }
    }
}
