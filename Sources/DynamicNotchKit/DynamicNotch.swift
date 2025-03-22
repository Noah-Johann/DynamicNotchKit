//
//  DynamicNotch.swift
//  DynamicNotchKit
//
//  Created by Kai Azim on 2023-08-24.
//

import Combine
import SwiftUI
import AppKit

// MARK: - DynamicNotch

public class DynamicNotch<Content>: NSResponder, ObservableObject where Content: View {
    public enum Style {
        case notch
        case floating
        case auto
    }

    public var windowController: NSWindowController?
    @Published var content: () -> Content
    @Published var contentID: UUID
    @Published var isVisible: Bool = false
    @Published var notchWidth: CGFloat = 0
    @Published var notchHeight: CGFloat = 0
    @Published var isMouseInside: Bool = false
    @Published public var isHovered: Bool = false
    
    private var timer: Timer?
    var workItem: DispatchWorkItem?
    private var subscription: AnyCancellable?
    private var notchStyle: Style = .notch
    
    private var maxAnimationDuration: Double = 0.3
    var animation: Animation {
        if #available(macOS 14.0, *), notchStyle == .notch {
            Animation.spring(response: 0.3, dampingFraction: 0.7)
        } else {
            Animation.easeInOut(duration: 0.2)
        }
    }

    public init(contentID: UUID = .init(), style: Style = .auto, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.contentID = contentID
        self.notchStyle = style
        super.init()
        self.subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = NSScreen.screens.first else { return }
                initializeWindow(screen: screen)
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Mouse Event Handling
    
    override public func mouseEntered(with event: NSEvent) {
        isHovered = true
        isMouseInside = true
        NotificationCenter.default.post(name: NSNotification.Name("NotchHoverStateChanged"), object: nil, userInfo: ["isHovered": true])
    }
    
    override public func mouseExited(with event: NSEvent) {
        isHovered = false
        isMouseInside = false
        NotificationCenter.default.post(name: NSNotification.Name("NotchHoverStateChanged"), object: nil, userInfo: ["isHovered": false])
    }
}

// MARK: - Public

public extension DynamicNotch {

    /// Set this DynamicNotch's content.
    /// - Parameter content: A SwiftUI View
    func setContent(contentID: UUID = .init(), content: @escaping () -> Content) {
        self.content = content
        self.contentID = .init()
    }

    /// Show the DynamicNotch.
    /// - Parameters:
    ///   - screen: Screen to show on. Default is the primary screen.
    ///   - time: Time to show in seconds. If 0, the DynamicNotch will stay visible until `hide()` is called.
    func show(on screen: NSScreen = NSScreen.screens[0], for time: Double = 0) {
        func scheduleHide(_ time: Double) {
            let workItem = DispatchWorkItem { self.hide() }
            self.workItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: workItem)
        }

        guard !isVisible else {
            if time > 0 {
                self.workItem?.cancel()
                scheduleHide(time)
            }
            return
        }
        timer?.invalidate()

        initializeWindow(screen: screen)

        DispatchQueue.main.async {
            withAnimation(self.animation) {
                self.isVisible = true
            }
        }

        if time != 0 {
            self.workItem?.cancel()
            scheduleHide(time)
        }
    }

    /// Hide the DynamicNotch.
    func hide(ignoreMouse: Bool = false) {
        guard isVisible else { return }

        if !ignoreMouse, isMouseInside {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.hide()
            }
            return
        }

        withAnimation(animation) {
            self.isVisible = false
        }

        timer = Timer.scheduledTimer(withTimeInterval: maxAnimationDuration, repeats: false) { _ in
            self.deinitializeWindow()
        }
    }

    /// Toggle the DynamicNotch's visibility.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Check if the cursor is inside the screen's notch area.
    /// - Returns: If the cursor is inside the notch area.
    static func checkIfMouseIsInNotch() -> Bool {
        guard let screen = NSScreen.screenWithMouse else {
            return false
        }

        let notchWidth: CGFloat = 300
        let notchHeight: CGFloat = screen.frame.maxY - screen.visibleFrame.maxY
        let padding: CGFloat = 5 // Add some padding for easier hover detection

        let notchFrame = screen.notchFrame ?? NSRect(
            x: screen.frame.midX - (notchWidth / 2) - padding,
            y: screen.frame.maxY - notchHeight - padding,
            width: notchWidth + (padding * 2),
            height: notchHeight + (padding * 2)
        )

        return notchFrame.contains(NSEvent.mouseLocation)
    }
}

// MARK: - Private

extension DynamicNotch {

    func refreshNotchSize(_ screen: NSScreen) {
        if let notchSize = screen.notchSize {
            notchWidth = notchSize.width
            notchHeight = notchSize.height
        } else {
            notchWidth = 300
            notchHeight = screen.frame.maxY - screen.visibleFrame.maxY // menubar height
        }
    }

    func initializeWindow(screen: NSScreen) {
        // so that we don't have a duplicate window
        deinitializeWindow()

        refreshNotchSize(screen)

        let view = MouseTrackingView(dynamicNotch: self)
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        
        switch notchStyle {
        case .notch:
            view.contentView = NSHostingView(rootView: NotchView(dynamicNotch: self).foregroundStyle(.white))
        case .floating:
            view.contentView = NSHostingView(rootView: NotchlessView(dynamicNotch: self))
        case .auto:
            if screen.hasNotch {
                view.contentView = NSHostingView(rootView: NotchView(dynamicNotch: self).foregroundStyle(.white))
            } else {
                view.contentView = NSHostingView(rootView: NotchlessView(dynamicNotch: self))
            }
        }

        // Add tracking area for hover with a larger detection area
        let trackingArea = NSTrackingArea(
            rect: view.bounds.insetBy(dx: -5, dy: -5),
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: view,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)

        let panel = DynamicNotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = view
        panel.orderFrontRegardless()
        
        // Calculate notch position
        let notchFrame = screen.notchFrame ?? NSRect(
            x: screen.frame.midX - (notchWidth / 2),
            y: screen.frame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        panel.setFrame(notchFrame, display: true)
        panel.level = .statusBar

        windowController = .init(window: panel)
    }

    func deinitializeWindow() {
        guard let windowController else { return }
        windowController.close()
        self.windowController = nil
    }
}

// MARK: - Mouse Tracking View
private class MouseTrackingView<T: View>: NSView {
    weak var dynamicNotch: DynamicNotch<T>?
    var contentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let contentView = contentView {
                addSubview(contentView)
                contentView.frame = bounds
            }
        }
    }
    
    init(dynamicNotch: DynamicNotch<T>) {
        super.init(frame: .zero)
        self.dynamicNotch = dynamicNotch
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with event: NSEvent) {
        dynamicNotch?.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        dynamicNotch?.mouseExited(with: event)
    }
}
