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

/// Bảng điều khiển: ẩn/hiện bằng `isPresented` (nút ⚙ nổi ở màn hình), cao tối đa ~45% màn,
/// cuộn được. `extra` là phần riêng của từng màn (vd. ô URL của Fake AR), hiện trên các slider.
struct ControlPanel<Extra: View>: View {
    let perform: (DemoEvent) -> Void
    let showRecenter: Bool
    @ObservedObject var model: DemoStatus
    @Binding var isPresented: Bool
    @ViewBuilder let extra: () -> Extra

    @State private var pointSize: Double = 14
    @State private var opacity: Double = 1
    @State private var visible = true

    init(perform: @escaping (DemoEvent) -> Void,
         showRecenter: Bool,
         model: DemoStatus,
         isPresented: Binding<Bool>,
         @ViewBuilder extra: @escaping () -> Extra) {
        self.perform = perform
        self.showRecenter = showRecenter
        self._model = ObservedObject(wrappedValue: model)
        self._isPresented = isPresented
        self.extra = extra
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                if isPresented {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            extra()

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
                        .padding(12)
                    }
                    .font(.callout)
                    .frame(maxWidth: 520)
                    .frame(maxHeight: geo.size.height * 0.45)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Ẩn: chỉ còn một dòng trạng thái nhỏ
                    Text(model.status)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

/// Dùng không có phần extra (màn 3D và AR thật).
extension ControlPanel where Extra == EmptyView {
    init(perform: @escaping (DemoEvent) -> Void, showRecenter: Bool, model: DemoStatus, isPresented: Binding<Bool>) {
        self.init(perform: perform, showRecenter: showRecenter, model: model, isPresented: isPresented) { EmptyView() }
    }
}

/// Nút ⚙ nổi góc phải trên để ẩn/hiện bảng điều khiển — luôn bấm được, không nằm trong panel.
struct PanelToggleButton: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isPresented.toggle() }
        } label: {
            Image(systemName: isPresented ? "xmark.circle.fill" : "slider.horizontal.3")
                .font(.title2)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
    }
}

// MARK: - Màn 1: 3D thường

struct Demo3DScreen: View {
    @State private var context = Demo3DContext()
    @StateObject private var model = DemoStatus()
    @State private var showPanel = true

    var body: some View {
        ZStack {
            Demo3DView(context: context)
                .ignoresSafeArea()
            ControlPanel(perform: { context.perform($0) }, showRecenter: false, model: model, isPresented: $showPanel)
        }
        .overlay(alignment: .topTrailing) { PanelToggleButton(isPresented: $showPanel) }
        .navigationTitle("View 3D")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { context.delegate = model }        // kênh 3D → UI
    }
}

// MARK: - Màn 2: AR

struct DemoARScreen: View {
    @State private var context = DemoARContext()
    @StateObject private var model = DemoStatus()
    @State private var showPanel = true

    var body: some View {
        ZStack {
            DemoARView(context: context)
                .ignoresSafeArea()
            ControlPanel(perform: { context.perform($0) }, showRecenter: true, model: model, isPresented: $showPanel)
        }
        .overlay(alignment: .topTrailing) { PanelToggleButton(isPresented: $showPanel) }
        .navigationTitle("View AR")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { context.delegate = model }
    }
}
