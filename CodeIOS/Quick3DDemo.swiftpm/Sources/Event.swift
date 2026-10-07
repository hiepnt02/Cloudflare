//
//  Event.swift
//  Quick3DDemo
//
//  Tầng ⑤ — kênh UI → 3D. Mỗi lệnh là một class, có id tăng dần để
//  context lọc trùng khi SwiftUI re-render nhiều lần.
//  Trong project thật: Camera/Event/Event.swift + Camera/Event/ViewAR/*.swift
//

import Foundation

protocol Event {
    var id: Int { get }
}

/// Cấp id duy nhất cho mỗi event (giống EventIdentity của project).
class EventIdentity: Event {
    private static var counter = 0
    let id: Int
    init() {
        EventIdentity.counter += 1
        id = EventIdentity.counter
    }
}

/// Những gì một context phải làm được để nhận event.
/// Trong project thật: ViewAREventContext.
protocol DemoEventContext: AnyObject {
    func setPointSize(_ size: Float)
    func setPointCloudVisible(_ visible: Bool)
    func setOpacity(_ opacity: Float)
    func recenter()
    /// Khoảng cách từ mắt tới model (m) — chỉ Fake AR dùng, thay cho tracking dịch chuyển.
    func setDistance(_ meters: Float)
}

extension DemoEventContext {
    func setDistance(_ meters: Float) {}   // mặc định không làm gì (màn 3D / AR thật)
}

protocol DemoEvent: Event {
    func call(_ context: DemoEventContext)
}

// MARK: - Các event cụ thể

final class ChangePointSizeEvent: EventIdentity, DemoEvent {
    let size: Float
    init(_ size: Float) { self.size = size; super.init() }
    func call(_ context: DemoEventContext) { context.setPointSize(size) }
}

final class TogglePointCloudEvent: EventIdentity, DemoEvent {
    let visible: Bool
    init(_ visible: Bool) { self.visible = visible; super.init() }
    func call(_ context: DemoEventContext) { context.setPointCloudVisible(visible) }
}

final class ChangeOpacityEvent: EventIdentity, DemoEvent {
    let opacity: Float
    init(_ opacity: Float) { self.opacity = opacity; super.init() }
    func call(_ context: DemoEventContext) { context.setOpacity(opacity) }
}

/// AR: đặt lại model ra trước mặt camera.
final class RecenterEvent: EventIdentity, DemoEvent {
    func call(_ context: DemoEventContext) { context.recenter() }
}

/// Fake AR: giả việc đi tới/lùi bằng cách đổi khoảng cách model.
final class ChangeDistanceEvent: EventIdentity, DemoEvent {
    let meters: Float
    init(_ meters: Float) { self.meters = meters; super.init() }
    func call(_ context: DemoEventContext) { context.setDistance(meters) }
}
