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

### Bám theo gyro (AR 3 bậc tự do)

IP Webcam không xuất cảm biến (`/sensors.json` trả `{}` trên nhiều máy), nên hướng máy lấy từ app
**Sensor Server** (Play Store, tác giả umer0586, mã nguồn mở):

1. Android: cài Sensor Server. Nó dùng 2 port: **WebSocket** (mặc định 8080, trùng IP Webcam) và
   **HTTP** (8081, trang liệt kê sensor). → STOP → *Settings* → **Port number / WebSocket port = 8082** → START.
   Màn hình phải hiện `ws://192.168.0.106:8082`. Chạy song song với IP Webcam (vẫn 8080).
2. Trong app → ô **Sensor** để `ws://192.168.0.106:8082` → bật toggle **"Bám theo gyro điện thoại"**.
   App mở WebSocket `ws://<ip>:8082/sensor/connect?type=android.sensor.rotation_vector`
   (`Sources/CameraStream.swift` → `PhoneOrientationStream`, ~50 Hz, tự kết nối lại khi rớt),
   parse `{"values":[x,y,z,w]}` thành quaternion và gán `cameraNode.simdOrientation`
   (`FakeARContext.updateOrientation`).
3. Chĩa camera vào mặt bàn, bấm **Đặt lại trước mặt**: model đặt 1.5 m trước mặt, thấp hơn mắt 0.9 m.
   Từ đó **xoay** điện thoại, model đứng yên đúng chỗ — giống "magic window".

- Ô Sensor nhập cổng **8082** (cổng WebSocket); 8081 chỉ là trang HTTP của Sensor Server.
- Chọn đúng **chiều cầm máy** (Dọc / Ngang ← / Ngang →) để trục xoay khớp ảnh; chọn sai thì xoay
  ngang sẽ thành xoay dọc.
- Kiểm tra nhanh Sensor Server: trong Safari của Mac mở `http://192.168.0.106:8081/` — trang của nó
  liệt kê sensor; phải có `android.sensor.rotation_vector`. Không có → dùng `android.sensor.game_rotation_vector`
  (đổi `PhoneOrientationStream.sensorType`).

Giới hạn của màn 3: **không có dịch chuyển** (6DoF) — đi tới/lùi thì model không bám, vì vị trí
camera do ARKit tính bằng visual-inertial odometry từ camera + IMU. Gyro không giả được → xem màn 4.

## Màn 4 — AR 6DoF bằng ARCore trên Android

Thay ARKit bằng **ARCore** (cùng thuật toán VIO) chạy trên Android, app iOS chỉ nhận kết quả:

```
Android (AndroidARBridge/)                         iOS Simulator (Sources/BridgeAR.swift)
ARCore Frame ─┬─ ảnh CPU (YUV→JPEG)  ┐             scene.background = ảnh
              ├─ camera.pose (4×4)   ├─ 1 message ─→ cameraNode.simdTransform = pose
              ├─ intrinsics (fy)     │   WebSocket   camera.fieldOfView = 2·atan(h/2/fy)
              └─ hitTest giữa màn    ┘   :8090       arNode đặt tại điểm hit trên mặt phẳng
```

Ảnh và pose cùng một frame nên không lệch trễ như IP Webcam + Sensor Server; đi tới/lùi/sang ngang
thì model bám đúng chỗ.

1. Cài **Android Studio** → File → Open → thư mục `D:\Project\Cloudflare\AndroidARBridge` → chờ Gradle sync
   (lần đầu nó tự tải Gradle 8.7) → cắm điện thoại (bật USB debugging) → Run.
   Điện thoại phải [hỗ trợ ARCore](https://developers.google.com/ar/devices) (có "Google Play Services for AR").
2. **Tắt IP Webcam** (hai app không dùng chung camera được). Màn hình ARBridge hiện `ws://<ip>:8090`.
3. Cầm điện thoại **ngang, đỉnh máy bên trái**; chạy Simulator cũng ở chế độ ngang cho to hình.
4. App iOS → "4. AR 6DoF" → ⚙ → nhập `ws://<ip>:8090` → **Kết nối**. Quét chậm sàn/bàn đến khi
   "mặt phẳng" > 0, chĩa giữa màn vào chỗ muốn đặt → **Đặt lại trước mặt** → model đứng lên mặt phẳng.

Ghi chú: ảnh CPU của ARCore thường 640×480 (đủ cho demo). Vài máy cảm biến lắp ngược (sensor 270°)
sẽ thấy ảnh lộn ngược → cầm ngang theo chiều kia.

## Thay point cloud bằng model cụ thể (mọi màn)

Bảng ⚙ có mục **Model**:
- **Tải** từ URL — dễ nhất trên Simulator: trên Mac `cd` vào thư mục chứa model, chạy
  `python3 -m http.server 8000`, nhập `http://localhost:8000/ten-model.usdz`.
- **Chọn file…** — từ app Files (OBJ chọn kiểu này sẽ mất file `.mtl`/texture đi kèm → dùng URL hoặc USDZ).
- **Model mẫu** — menu chọn Nhà / Cây / Xe / Bàn ghế / Cột mốc / Cột điện dựng sẵn trong code
  (`ModelLoader.sample`), kích thước thật — bật "Kích thước gốc" để thấy đúng cỡ.
- **Cỡ model**: cạnh dài nhất (0.1–30 m), hoặc bật **Kích thước gốc** để dùng đúng đơn vị mét trong file.

### Point cloud từ file PLY / Gaussian splatting

Ô **PLY** trong bảng ⚙: **Tải** từ URL (cùng cách `python3 -m http.server`), **Chọn…** từ Files, **Địa hình** quay về
mẫu sinh bằng code. `Sources/PLYReader.swift` đọc binary little/big-endian và ascii:
- PLY thường: `x y z` + `red green blue` (uchar hoặc float). Không có màu → tô theo chiều cao.
- **3D Gaussian splatting** (`f_dc_*`, `opacity`, `scale_*`, `rot_*`): màu = `0.5 + 0.2821·f_dc`,
  lật Y/Z (COLMAP Y xuống → SceneKit Y lên). Mặc định vẽ **splat thật**: mỗi splat là một điểm
  (`primitive .point`) nhưng `splatVertex` chiếu covariance 3D (`Σ = R·S·Sᵀ·Rᵀ`, tính sẵn trong
  `PLYReader`) thành ellipse 2D theo công thức EWA của paper (`Σ' = J·W·Σ·Wᵀ·Jᵀ`), `point_size` =
  đường kính 3σ, `splatFragment` tô `alpha = opacity·exp(−½ dᵀΣ'⁻¹d)`. `SplatCloud` sắp xếp lại index
  buffer xa→gần (counting sort 16 bit, thread nền) mỗi khi camera dịch > 2 % hoặc xoay > 1.5°; material
  blend alpha, không ghi depth. Tắt toggle "vẽ ellipse" → về chấm tròn (bỏ splat `opacity < 0.1`).
  Code: `SplatCloud.swift`, `SplatProgram.swift`, `SCNBuilder.createSplatNode`, cuối `Shaders.metal`.
  Giới hạn: splat quá gần camera bị kẹp ở 1024 px; splat có tâm ra khỏi màn biến mất cả cụm (đặc thù
  point sprite); file 1 M splat sắp xếp ~50–100 ms/lần trên Simulator (bản Debug chậm hơn).
- File > 1 triệu điểm được lấy mẫu đều xuống 1 triệu (`PLYReader.maxPoints`). Toạ độ được dời: tâm XZ về 0,
  sàn (phân vị 2 % của Y) về 0 — đặt lên mặt phẳng AR là đứng đúng.
- **Kèm app**: file trong `Sources/Data/*.ply` được đóng gói theo app (`resources: [.copy("Data")]`
  trong `Package.swift`; App Playground không có `Bundle.module` nên tìm trong `Bundle.main`; thư mục
  không được tên `Resources` vì codesign iOS sẽ báo lỗi) và hiện thành nút trong bảng ⚙ — không cần server.
  `lorem.ply` (5 MB) đã có sẵn; thêm file khác chỉ cần thả vào thư mục đó.
  File **> 100 MB** GitHub chặn → cắt thành `ten.ply.part1`, `.part2`… (mỗi mảnh < 100 MB), app tự ghép
  lại vào Caches ở lần dùng đầu (`PLYReader.assembleIfSplit`). `mihama_0_optimized.ply` (187 MB, 3.4 M
  splat) đang ở dạng 2 mảnh. Cắt trên Windows (PowerShell), 95 MB một mảnh:
  ```powershell
  $src="in.ply"; $fs=[IO.File]::OpenRead($src); $b=New-Object byte[] 95MB; $i=1
  while(($n=$fs.Read($b,0,$b.Length)) -gt 0){ $o=[IO.File]::Create("$src.part$i"); $o.Write($b,0,$n); $o.Close(); $i++ }; $fs.Close()
  ```
- Thử: `lorem.ply` (23k điểm) trước, rồi `mihama_0_optimized.ply` (3.4 M → 1 M, ~10 s đọc). Bản
  `mihama_combined_3dgs_10.ply` 810 MB cùng số điểm nhưng thừa 45 hệ số SH, không cần dùng.

Định dạng model: `.usdz/.usd/.usda/.usdc/.scn/.obj`. `.glb/.gltf/.fbx/.dae` iOS không đọc lúc chạy →
đổi sang USDZ bằng Reality Converter (Mac) hoặc Blender (Export → USD). Code: `Sources/ModelLoader.swift`;
model gắn dưới `arNode/modelRoot`, đáy-giữa model nằm ở gốc nên đứng đúng lên mặt phẳng.

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
