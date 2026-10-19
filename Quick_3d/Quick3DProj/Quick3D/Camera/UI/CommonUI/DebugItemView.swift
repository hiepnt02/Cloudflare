//
//  DebugRowView.swift
//  Quick3D
//
//  Created by HungNT on 3/6/26.
//

import SwiftUI

struct DebugItemView: View {
    let label: String
    let value: String
    var lineLimit: Int = 1
    
    var body: some View {
        Text("\(label): \(value)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(lineLimit)
            .font(.system(size: UIDevice.current.isIphone ? 12 : 16))
    }
}

struct DebugTitleView: View {
    let label: String
    
    var body: some View {
        Text("\(label)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .font(.system(size: UIDevice.current.isIphone ? 12 : 16).bold())
    }
}
