//
//  ViewExt.swift
//  Quick3D
//
//  Created by HungNT on 24/12/24.
//
import Foundation
import SwiftUI
extension View {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }
}