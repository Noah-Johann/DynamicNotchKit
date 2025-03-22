//
//  DynamicNotch.swift
//  DynamicNotchKit
//
//  Created by Kai Azim on 2023-08-24.
//

import Combine
import SwiftUI

// MARK: - DynamicNotch

public class DynamicNotch<Content>: ObservableObject where Content: View {

    public var windowController: NSWindowController? // Make public in case user wants to modify the NSPanel

    // Content Properties
    @Published var content: () -> Content
    @Published var contentID: UUID
    @Published var isVisible: Bool = false // Used to animate the fading in/out of the user's view

    // Notch Size
    @Published var notchWidth: CGFloat = 0
    @Published var notchHeight: CGFloat = 0

    // Notch Closing Properties
    @Published var isMouseInside: Bool = false // If the mouse is inside, the notch will not auto-hide
    private var timer: Timer?
    var workItem: DispatchWorkItem?
    private var subscription: AnyCancellable?

    // Notch Style
    private var notchStyle: Style = .notch
    public enum Style {
        case notch
        case floating
        case auto
    }

    // Hover State
    @Published var isHovered: Bool = false

    private var maxAnimationDuration: Double = 0.3 // Reduced from 0.8 for snappier transitions
    var animation: Animation {
        if #available(macOS 14.0, *), notchStyle == .notch {
            Animation.spring(response: 0.3, dampingFraction: 0.7)
        } else {
            Animation.easeInOut(duration: 0.2)
        }
    }

    /// Makes a new DynamicNotch with custom content and style.
    /// - Parameters:
    ///   - content: A SwiftUI View
    ///   - style: The popover's style. If unspecified, the style will be automatically set according to the screen.
    public init(contentID: UUID = .init(), style: DynamicNotch.Style = .auto, @ViewBuilder content: @escaping () -> Content) {
        self.contentID = contentID
        self.content = content
        self.notchStyle = style
        self.subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = NSScreen.screens.first else { return }
                initializeWindow(screen: screen)
            }
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

        let view: NSView = {
            switch notchStyle {
            case .notch: 
                let view = NSHostingView(rootView: NotchView(dynamicNotch: self).foregroundStyle(.white))
                view.wantsLayer = true
                view.layer?.masksToBounds = true
                return view
            case .floating: 
                let view = NSHostingView(rootView: NotchlessView(dynamicNotch: self))
                view.wantsLayer = true
                view.layer?.masksToBounds = true
                return view
            case .auto: 
                let view = screen.hasNotch ? 
                    NSHostingView(rootView: NotchView(dynamicNotch: self).foregroundStyle(.white)) : 
                    NSHostingView(rootView: NotchlessView(dynamicNotch: self))
                view.wantsLayer = true
                view.layer?.masksToBounds = true
                return view
            }
        }()

        // Add tracking area for hover with a larger detection area
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: -5, y: -5, width: view.bounds.width + 10, height: view.bounds.height + 10),
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
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
        panel.setFrame(screen.frame, display: false)

        windowController = .init(window: panel)
    }

    func deinitializeWindow() {
        guard let windowController else { return }
        windowController.close()
        self.windowController = nil
    }

    // Add hover handling methods
    public func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}
