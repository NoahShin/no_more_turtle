import AppKit
import QuartzCore

@MainActor
final class TurtleOverlayWindow {

    private static let size = CGSize(width: 600, height: 600)
    private static let margin: CGFloat = 24
    private static let animationDuration: TimeInterval = 0.4

    private var window: NSWindow?
    private var isShown = false

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

    private func restingFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSScreen.screens.first!.frame
        return NSRect(
            x: screen.maxX - Self.size.width - Self.margin,
            y: screen.maxY - Self.size.height - Self.margin,
            width: Self.size.width,
            height: Self.size.height
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
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.alphaValue = 0.55
        w.hasShadow = false
        w.level = .floating
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let label = NSTextField(labelWithString: "🐢")
        label.font = .systemFont(ofSize: 500)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(origin: .zero, size: Self.size)
        w.contentView = label

        return w
    }
}
