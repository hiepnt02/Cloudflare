# Quick3DDemo — demo "view 3D trên iOS" theo kiến trúc module Camera của Quick3D

Mục đích: chạy được một màn hình 3D (và một màn AR) nhỏ, nhưng đi đúng 6 tầng của
`ios/Quick3DProj/Quick3D/Camera/` để đọc code project không bị lạ.

```
SwiftUI screen → UIViewRepresentable → SCNView / ARSCNView → Context (scene graph)
      → SCNGeometry từ MTLBuffer + SCNProgram → Shaders.metal
```

## Mở trên macOS

Yêu cầu: macOS 13+, **Xcode 15+** (App Store). Không cần CocoaPods.

1. Copy folder `Quick3DDemo.swiftpm` sang Mac.
2. Double-click folder `Quick3DDemo.swiftpm` (hoặc Xcode → File → Open… chọn folder) — Xcode mở nó như một app.
3. Chọn đích chạy ở thanh trên:
   - **iPad/iPhone Simulator** → chạy được màn **"1. View 3D"** (SceneKit + Metal trên Simulator OK).
   - **Thiết bị thật** → chạy được cả **"2. View AR"** (cần camera; iPhone/iPad iOS 16+, không bắt buộc LiDAR).
4. Lần đầu chạy lên máy thật: Xcode đòi Team → mở `Package.swift`, điền `teamIdentifier: "XXXXXXXXXX"`
   (Team ID trong Apple Developer, hoặc để Xcode tự điền qua Signing & Capabilities).
5. ⌘R.

Trên máy ảo macOS (VMware/Parallels) thường **không có Metal** → màn Home sẽ báo
"KHÔNG CÓ Metal" và 3D không vẽ được. Cần Mac thật hoặc chạy trên iPad thật.

## Màn 3 — Fake AR bằng camera Android (không cần iPhone)

`ARSCNView` thật = **frame camera làm `scene.background`** + SceneKit vẽ node + ARKit tính pose.
Màn này giữ 2 phần đầu, nguồn ảnh là app **IP Webcam** trên Android:

1. Android: mở IP Webcam → *Start server* → ghi địa chỉ (vd. `http://192.168.0.106:8080`).
2. Mac/Simulator cùng Wi-Fi với điện thoại (Simulator dùng mạng của Mac). Thử mở
   `http://192.168.0.106:8080/shot.jpg` trong Safari của Mac — phải ra một ảnh.
3. Trong app → "3. Fake AR" → sửa URL nếu khác → **Kết nối**. Ảnh JPEG được tải mỗi ~80 ms
   (`Sources/CameraStream.swift`) và gán vào `scene.background.contents` (`Sources/FakeAR.swift`).
4. Point cloud vẽ đè lên y như màn AR thật; xoay bằng ngón tay.

Giới hạn thật: **không có tracking** — xoay điện thoại Android thì nền đổi nhưng model đứng yên,
vì pose camera trong AR thật do ARKit tính từ camera + IMU của chính iPhone. Nếu muốn
"gần thật" hơn, bước tiếp theo là đọc `http://<ip>:8080/sensors.json?sense=rot_vector`
(IP Webcam có xuất gyro/rotation vector) để xoay `cameraNode` theo điện thoại.

`AdditionalInfo.plist` thêm `NSAppTransportSecurity` để iOS cho phép `http://` tới LAN.

## Nếu Xcode không chịu mở `.swiftpm` (fallback 5 phút)

1. Xcode → File → New → Project → iOS → **App** (Interface: SwiftUI, Language: Swift). Đặt tên `Quick3DDemo`.
2. Xoá `ContentView.swift` và `Quick3DDemoApp.swift` mặc định.
3. Kéo toàn bộ file trong `Sources/` (kể cả `Shaders.metal`) vào project, tick *Copy items if needed*.
4. Target → Info → thêm key `Privacy - Camera Usage Description` (NSCameraUsageDescription), giá trị bất kỳ;
   và copy nội dung `AdditionalInfo.plist` (NSAppTransportSecurity, NSLocalNetworkUsageDescription) vào Info của target.
5. ⌘R. (Shaders.metal trong target được Xcode biên dịch vào default.metallib của app, SceneKit tự tìm hàm theo tên.)

## Map file demo → file project thật

| Demo (`Sources/`) | Project (`Camera/`) | Tầng |
|---|---|---|
| `DemoApp.swift` | `View/MainScreen/MainScreen.swift` | ① vỏ / điều hướng |
| `Screens.swift` — `Demo3DScreen`, `DemoARScreen`, `DemoStatus` | `UI/ViewAR/ViewARScreen.swift` (+ `ViewARDelegate`) | ① màn hình + delegate |
| `SceneViews.swift` — `Demo3DView`, `DemoARView` | `UI/CommonUI/ARCameraView.swift`, `CameraContextWrapper.swift` | ② cầu SwiftUI→UIKit |
| `SceneContext.swift` — `DemoSceneContext`, `Demo3DContext`, `DemoARContext` | `UI/ViewAR/SCNViewARContext.swift`, `UI/CommonUI/CameraContextTemplate.swift` | ④ context / scene graph |
| `Event.swift` | `Event/Event.swift`, `Event/ViewAR/*.swift` | ⑤ UI → 3D |
| `MetalPointCloud.swift` | `Metal/MetalPointCloud.swift` (+ `Reader/BVHReader.swift` cấp dữ liệu) | ⑥ dữ liệu trên GPU |
| `SCNBuilder.swift` | `Utils/SCNBuilder.swift` | ⑥ geometry |
| `PointProgram.swift` | `Metal/MetalViewARProgram.swift` | ⑥ SCNProgram / uniform |
| `Shaders.metal` — `demoVertex`, `demoFragment` | `Metal/Shaders.metal` — `scnVertex`, `pointFragment` | ⑥ shader |

Những gì project có mà demo **cố tình bỏ**: RTK/GPS → offset (demo đặt model 1.5 m trước mặt),
BVH streaming từ server (demo sinh ~100k điểm tại chỗ), occlusion LiDAR, IFC/USDZ, manual calibration,
backend RealityKit (`RealityViewARContext` + `RealityARRender`).

## Thử nghiệm gợi ý (mỗi cái chạm đúng một tầng)

1. Đổi màu/hình trong `MetalPointCloud.makeTerrain` → tầng dữ liệu.
2. Đổi công thức `out.pointSize` hoặc màu trong `Shaders.metal` → tầng shader.
3. Thêm một event mới (vd. `RotateEvent` xoay `arNode.simdEulerAngles`) → tầng Event + Context.
4. Thêm hàm delegate mới (vd. báo FPS từ `session(didUpdate:)`) → tầng Delegate.
5. Trong `DemoARContext.place`, thay vị trí cố định bằng hit-test mặt phẳng (`ARWorldTrackingConfiguration.planeDetection = [.horizontal]` + `frame.raycastQuery`) → bước đầu tiến tới cách project đặt model.

## Breakpoint nên đặt

- `SceneViews.swift` `makeUIView` — view được tạo (1 lần).
- `SceneContext.swift` `loadPointCloud` → closure `MainActor.run` — node được tạo.
- `PointProgram.swift` closure `handleBinding("pointSize")` — bắn mỗi frame, uniform đi vào shader.
- `DemoARContext.session(_:didUpdate:)` — "render loop" của AR (bắn 60 lần/giây, đặt điều kiện `placed == false`).
- Metal: Xcode → Debug → **Capture GPU Workload** → xem pipeline `demoVertex`.
