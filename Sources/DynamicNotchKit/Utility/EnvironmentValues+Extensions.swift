//
//  EnvironmentValues+Extensions.swift
//  DynamicNotchKit
//
//  Created by Kai Azim on 2025-03-26.
//

import SwiftUI

public extension EnvironmentValues {
    @Entry var horizontalNotchSafeAreaInset: CGFloat = 15
    @Entry var topNotchSafeAreaInset: CGFloat = 15
    @Entry var bottomNotchSafeAreaInset: CGFloat = 15
    
    @Entry var horizontalIslandSafeAreaInset: CGFloat = 20
    @Entry var verticalIslandSafeAreaInset: CGFloat = 20
    
    @Entry var notchTopCornerRadius: CGFloat = 25
    @Entry var notchBottomCornerRadius: CGFloat = 50
    @Entry var islandCornerRadius: CGFloat = 40
}

extension EnvironmentValues {
    @Entry var notchStyle: DynamicNotchStyle = .auto
    @Entry var notchSection: DynamicNotchSection = .expanded
}

enum DynamicNotchSection {
    case expanded
    case compactLeading
    case compactTrailing
}
