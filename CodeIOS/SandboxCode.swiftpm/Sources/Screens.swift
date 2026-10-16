//
//  Screens.swift
//  Quick3DDemo
//
//  Tầng ① — màn hình SwiftUI. Giữ context, nhét vào view, chỉ nói chuyện với 3D
//  qua Event (xuống) và Delegate (lên).
//  Trong project thật: Camera/UI/ViewAR/ViewARScreen.swift
//

import SwiftUI
import UniformTypeIdentifiers
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

                            ModelControls(perform: perform, pointCloudVisible: $visible)

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

/// Chọn model thay cho point cloud: file trong Files, URL http, hoặc nhà mẫu.
/// Trên Simulator dễ nhất là URL: trên Mac chạy `python3 -m http.server 8000` trong thư mục chứa
/// model rồi nhập http://localhost:8000/ten.usdz (Simulator dùng chung localhost với Mac).
struct ModelControls: View {
    let perform: (DemoEvent) -> Void
    @Binding var pointCloudVisible: Bool

    @AppStorage("model.url") private var modelURL = "http://localhost:8000/model.usdz"
    @AppStorage("ply.url") private var plyURL = "http://localhost:8000/lorem.ply"
    @State private var showImporter = false
    @State private var showPLYImporter = false
    @State private var cloudSizeLog: Double = 0.7       // 10^0.7 ≈ 5 m
    @State private var cloudOriginal = true             // địa hình mẫu đã là mét
    @State private var splatMode = true                 // 3DGS: ellipse mờ thay vì chấm tròn
    @State private var sizeLog: Double = 0          // 10^sizeLog m: 0.1 … ~30 m
    @State private var originalSize = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Model").font(.caption).frame(width: 48, alignment: .leading)
                TextField("http://…/model.usdz", text: $modelURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Tải") {
                    if let url = URL(string: modelURL.trimmingCharacters(in: .whitespaces)) { load(.url(url)) }
                }
                .buttonStyle(.bordered)
            }
            HStack {
                Button("Chọn file…") { showImporter = true }
                Button("Bỏ model") {
                    perform(LoadModelEvent(.none))
                    pointCloudVisible = true
                }
            }
            .buttonStyle(.bordered)
            // Model mẫu: dải nút cuộn ngang (Menu ở màn ngang bị iOS cắt còn ~8 dòng)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Mẫu").font(.caption).foregroundStyle(.secondary)
                    ForEach(SampleModel.allCases) { kind in
                        Button(kind.rawValue) { load(.sample(kind)) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            HStack {
                Text("Cỡ model").frame(width: 90, alignment: .leading)
                Slider(value: $sizeLog, in: -1...1.5)
                    .disabled(originalSize)
                    .onChange(of: sizeLog) { _ in sendSize() }
                Text(originalSize ? "gốc" : String(format: "%.1f m", pow(10, sizeLog))).frame(width: 52)
            }
            Toggle("Kích thước gốc trong file (mét)", isOn: $originalSize)
                .onChange(of: originalSize) { _ in sendSize() }

            // Point cloud từ file .ply (thường hoặc Gaussian splatting) thay cho địa hình mẫu
            HStack {
                Text("PLY").font(.caption).frame(width: 48, alignment: .leading)
                TextField("http://…/scene.ply", text: $plyURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Tải") {
                    if let url = URL(string: plyURL.trimmingCharacters(in: .whitespaces)) { loadPLY(.url(url)) }
                }
                .buttonStyle(.bordered)
                Button("Chọn…") { showPLYImporter = true }
                    .buttonStyle(.bordered)
                    .fileImporter(isPresented: $showPLYImporter, allowedContentTypes: [.item]) { result in
                        guard case .success(let url) = result else { return }
                        do { loadPLY(.url(try ModelLoader.copyPicked(url))) }
                        catch { print("Không copy được file PLY: \(error)") }
                    }
                Button("Địa hình") { loadPLY(.none) }
                    .buttonStyle(.bordered)
            }
            // File .ply đóng gói sẵn trong app (Sources/Resources) — không cần server
            if !PLYReader.bundled.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Kèm app").font(.caption).foregroundStyle(.secondary)
                        ForEach(PLYReader.bundled, id: \.self) { url in
                            Button(url.lastPathComponent) { loadPLY(.url(url)) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
            HStack {
                Text("Cỡ cloud").frame(width: 90, alignment: .leading)
                Slider(value: $cloudSizeLog, in: -0.5...1.7)          // 0.3 … 50 m
                    .disabled(cloudOriginal)
                    .onChange(of: cloudSizeLog) { _ in sendCloudSize() }
                Text(cloudOriginal ? "gốc" : String(format: "%.1f m", pow(10, cloudSizeLog))).frame(width: 52)
                Toggle("gốc", isOn: $cloudOriginal).labelsHidden()
                    .onChange(of: cloudOriginal) { _ in sendCloudSize() }
            }
            Toggle("3DGS: vẽ ellipse mờ (splat thật)", isOn: $splatMode)
                .onChange(of: splatMode) { on in perform(SetSplatModeEvent(on)) }
            Text("Tối đa \(PLYReader.maxPoints / 1000)k splat. Toạ độ 3DGS không phải mét → tắt \"gốc\" và kéo Cỡ cloud. Point size: splat = độ phình (14 = đúng file), điểm = pixel.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            do { load(.url(try ModelLoader.copyPicked(url))) }
            catch { print("Không copy được file model: \(error)") }
        }
    }

    private func load(_ source: ModelSource) {
        perform(LoadModelEvent(source))
        pointCloudVisible = false                   // onChange của toggle sẽ gửi TogglePointCloudEvent
    }

    private func loadPLY(_ source: ModelSource) {
        perform(LoadPointCloudEvent(source))
        pointCloudVisible = true
        // PLY thường không có đơn vị mét → mặc định ép về cỡ slider; địa hình mẫu thì giữ gốc
        if case .url = source { cloudOriginal = false } else { cloudOriginal = true }
    }

    private func sendCloudSize() {
        perform(ChangePointCloudSizeEvent(cloudOriginal ? nil : Float(pow(10, cloudSizeLog))))
    }

    private func sendSize() {
        perform(ChangeModelSizeEvent(originalSize ? nil : Float(pow(10, sizeLog))))
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
