//
//  IslandView.swift
//  DynamicNotchKit
//
//  Created by Noah Johann on 10.04.26.
//

import SwiftUI

struct IslandView<Expanded, CompactLeading, CompactTrailing>: View where Expanded: View, CompactLeading: View, CompactTrailing: View {
    @ObservedObject private var dynamicNotch: DynamicNotch<Expanded, CompactLeading, CompactTrailing>
    @State private var compactLeadingWidth: CGFloat = 0
    @State private var compactTrailingWidth: CGFloat = 0
    private let safeAreaInset: CGFloat = 20
    
    @Environment(\.islandCornerRadius) private var expandedCornerRadius
    @Environment(\.horizontalIslandSafeAreaInset) private var horizontalSafeAreaInset
    @Environment(\.verticalIslandSafeAreaInset) private var verticalSafeAreaInset
    
    init(dynamicNotch: DynamicNotch<Expanded, CompactLeading, CompactTrailing>) {
        self.dynamicNotch = dynamicNotch
    }
    
    private var compactIslandCornerRadius: CGFloat {
        dynamicNotch.menubarHeight / 2
    }
    
    private var minWidth: CGFloat {
        if dynamicNotch.isHovering && dynamicNotch.state != .expanded {
            (dynamicNotch.menubarHeight * 4) + (dynamicNotch.menubarHeight * 0.2)
        } else {
            dynamicNotch.menubarHeight * 4
        }
    }
    
    private var cornerRadius: CGFloat {
        dynamicNotch.state == .expanded ? expandedCornerRadius : compactIslandCornerRadius
    }
    
    private var xOffset: CGFloat {
        if dynamicNotch.state != .compact {
           0
        } else {
            compactXOffset
        }
    }
    
    private var topIslandPadding: CGFloat {
        if dynamicNotch.state == .expanded {
            dynamicNotch.menubarHeight * 0.1
        } else {
            dynamicNotch.menubarHeight * 0.05
        }
    }
    
    private var bottomIslandPadding: CGFloat {
        if dynamicNotch.state == .expanded {
            0
        } else {
            if dynamicNotch.isHovering {
                0
            } else {
                dynamicNotch.menubarHeight * 0.05
            }
        }
    }
    
    private var horizontalIslandPadding: CGFloat {
        if dynamicNotch.state != .expanded && dynamicNotch.isHovering {
            dynamicNotch.menubarHeight * 0.1
        } else {
            0
        }
    }
 
    private var compactXOffset: CGFloat {
        (compactTrailingWidth - compactLeadingWidth) / 2
    }
    
    var body: some View {
        islandContent()
            .background {
                Rectangle()
                    .foregroundStyle(.black)
                    .padding(-50)
            }
            .mask {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, topIslandPadding)
                    .padding(.bottom, bottomIslandPadding)
                    .padding(.horizontal, horizontalIslandPadding)
            }
            .offset(x: xOffset)
            .animation(.smooth, value: [compactLeadingWidth, compactTrailingWidth])
    }
    
    private func islandContent() -> some View {
        ZStack {
            compactContent()
                .fixedSize()
                .offset(x: dynamicNotch.state == .compact ? 0 : compactXOffset)
                .frame(
                    width: dynamicNotch.state == .compact ? minWidth + compactLeadingWidth + compactTrailingWidth : minWidth,
                    height: dynamicNotch.menubarHeight - topIslandPadding - bottomIslandPadding
                )

            expandedContent()
                .fixedSize()
                .frame(
                    maxWidth: dynamicNotch.state == .expanded ? nil : 0,
                    maxHeight: dynamicNotch.state == .expanded ? nil : 0
                )
                .offset(x: dynamicNotch.state == .compact ? -compactXOffset : 0)
        }
        .fixedSize()
        .frame(minWidth: minWidth, minHeight: dynamicNotch.menubarHeight - topIslandPadding - bottomIslandPadding)
        .onHover(perform: dynamicNotch.updateHoverState)
    }
    
    func compactContent() -> some View {
        HStack(spacing: 0) {
            if dynamicNotch.state == .compact, !dynamicNotch.disableCompactLeading {
                dynamicNotch.compactLeadingContent
                    .environment(\.notchSection, .compactLeading)
                    .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: topIslandPadding + 6) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: bottomIslandPadding + 6) }
                    .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: horizontalIslandPadding + 6) }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactLeadingWidth = $0 }
                    .transition(.blur(intensity: 10).combined(with: .scale(x: 0, anchor: .trailing)).combined(with: .opacity))
            }

            Spacer()
                .frame(width: dynamicNotch.menubarHeight * 4)

            if dynamicNotch.state == .compact, !dynamicNotch.disableCompactTrailing {
                dynamicNotch.compactTrailingContent
                    .environment(\.notchSection, .compactTrailing)
                    .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: topIslandPadding + 6) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: bottomIslandPadding + 6) }
                    .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: horizontalIslandPadding + 6) }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactTrailingWidth = $0 }
                    .transition(.blur(intensity: 10).combined(with: .scale(x: 0, anchor: .leading)).combined(with: .opacity))
            }
        }
        .frame(height: dynamicNotch.menubarHeight)
        .onChange(of: dynamicNotch.disableCompactLeading) { _ in
            if dynamicNotch.disableCompactLeading {
                compactLeadingWidth = 0
            }
        }
        .onChange(of: dynamicNotch.disableCompactTrailing) { _ in
            if dynamicNotch.disableCompactTrailing {
                compactTrailingWidth = 0
            }
        }
    }

    func expandedContent() -> some View {
        HStack(spacing: 0) {
            if dynamicNotch.state == .expanded {
                dynamicNotch.expandedContent
                    .transition(.blur(intensity: 10).combined(with: .scale(y: 0.6, anchor: .top)).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: topIslandPadding)}
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: verticalSafeAreaInset) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: verticalSafeAreaInset) }
        .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: horizontalSafeAreaInset) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: horizontalSafeAreaInset) }
        .frame(minWidth: minWidth)
    }
}
