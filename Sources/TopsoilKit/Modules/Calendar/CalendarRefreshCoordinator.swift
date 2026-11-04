import EventKit
import Foundation

public protocol CalendarRefreshTimer: AnyObject {
    func invalidate()
}

extension Timer: CalendarRefreshTimer {}

private final class CallbackBox: @unchecked Sendable {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}

public final class CalendarRefreshCoordinator {
    public typealias AddObserver = (Notification.Name, @escaping () -> Void) -> NSObjectProtocol
    public typealias RemoveObserver = (NSObjectProtocol) -> Void
    public typealias MakeTimer = (@escaping () -> Void) -> CalendarRefreshTimer

    private let addObserver: AddObserver
    private let removeObserver: RemoveObserver
    private let makeTimer: MakeTimer
    private var observerTokens: [NSObjectProtocol] = []
    private var timer: CalendarRefreshTimer?

    public init(
        addObserver: AddObserver? = nil,
        removeObserver: RemoveObserver? = nil,
        makeTimer: MakeTimer? = nil
    ) {
        let center = NotificationCenter.default
        self.addObserver = addObserver ?? { name, action in
            let box = CallbackBox(action)
            return center.addObserver(forName: name, object: nil, queue: .main) { _ in
                box.action()
            }
        }
        self.removeObserver = removeObserver ?? { token in
            center.removeObserver(token)
        }
        self.makeTimer = makeTimer ?? { action in
            let box = CallbackBox(action)
            let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                box.action()
            }
            timer.tolerance = 6
            return timer
        }
    }

    public func activate(refresh: @escaping () -> Void) {
        if observerTokens.isEmpty {
            observerTokens = [
                addObserver(.EKEventStoreChanged, refresh),
                addObserver(.NSCalendarDayChanged, refresh),
            ]
        }

        if timer == nil {
            timer = makeTimer(refresh)
        }
    }

    public func deactivate() {
        timer?.invalidate()
        timer = nil

        observerTokens.forEach(removeObserver)
        observerTokens.removeAll()
    }
}
