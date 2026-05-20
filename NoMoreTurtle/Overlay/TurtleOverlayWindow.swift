import AppKit

@MainActor
final class TurtleOverlayWindow {

    private var window: NSWindow?

    func show() {
        if window == nil {
            window = makeWindow()
        }
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first!.frame
        let size = CGSize(width: 240, height: 240)
        let origin = CGPoint(
            x: screenFrame.maxX - size.width - 24,
            y: screenFrame.maxY - size.height - 24
        )
        let frame = NSRect(origin: origin, size: size)

        let w = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let label = NSTextField(labelWithString: "🐢")
        label.font = .systemFont(ofSize: 200)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(origin: .zero, size: size)
        w.contentView = label

        return w
    }
}
