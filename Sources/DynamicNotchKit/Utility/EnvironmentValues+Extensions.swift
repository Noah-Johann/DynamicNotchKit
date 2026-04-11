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
    
    @Entry var horizontalIslandSafeAreaInset: CFloat = 20
    @Entry var vertivalIslandSafeAreaInset: CGFloat = 20
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
