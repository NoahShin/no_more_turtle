import AppKit
import Combine
import QuartzCore

@MainActor
final class TurtleOverlayWindow {

    private static let margin: CGFloat = 24
    private static let animationDuration: TimeInterval = 0.4

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    private var window: NSWindow?
    private var isShown = false

    init() {
        // Opacity changes apply live to the existing window.
        settings.$overlayOpacity
            .sink { [weak self] newValue in
                self?.window?.alphaValue = newValue
            }
            .store(in: &cancellables)

        // Size changes need a new window — invalidate so the next show() rebuilds.
        settings.$overlaySize
            .dropFirst()
            .sink { [weak self] _ in
                self?.invalidateWindow()
            }
            .store(in: &cancellables)
    }

    func show() {
        guard !isShown else { return }
        isShown = true

        let w = ensureWindow()
        let resting = restingFrame()
        let off = offscreenFrame()

        if !w.isVisible {
            w.setFrame(off, display: false)
            w.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            w.animator().setFrame(resting, display: true)
        }
    }

    func hide() {
        guard isShown else { return }
        isShown = false

        guard let w = window, w.isVisible else { return }
        let off = offscreenFrame()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            w.animator().setFrame(off, display: true)
        }, completionHandler: { [weak self, weak w] in
            // If show() was called again mid-animation, isShown is true; don't hide.
            guard let self, !self.isShown else { return }
            w?.orderOut(nil)
        })
    }

    private func invalidateWindow() {
        if let w = window {
            w.orderOut(nil)
            window = nil
        }
        isShown = false
    }

    private func size() -> CGSize {
        let side = CGFloat(settings.overlaySize)
        return CGSize(width: side, height: side)
    }

    private func restingFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSScreen.screens.first!.frame
        let s = size()
        return NSRect(
            x: screen.maxX - s.width - Self.margin,
            y: screen.maxY - s.height - Self.margin,
            width: s.width,
            height: s.height
        )
    }

    private func offscreenFrame() -> NSRect {
        let resting = restingFrame()
        let fullScreen = NSScreen.main?.frame ?? NSScreen.screens.first!.frame
        return NSRect(
            x: fullScreen.maxX,
            y: resting.origin.y,
            width: resting.width,
            height: resting.height
        )
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let w = makeWindow()
        window = w
        return w
    }

    private func makeWindow() -> NSWindow {
        let s = size()
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: s),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.alphaValue = settings.overlayOpacity
        w.hasShadow = false
        w.level = .floating
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let label = NSTextField(labelWithString: "🐢")
        // Font scales with the configured window size (keep it proportional to the original 600 / 500).
        label.font = .systemFont(ofSize: s.height * (500.0 / 600.0))
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(origin: .zero, size: s)
        w.contentView = label

        return w
    }
}
