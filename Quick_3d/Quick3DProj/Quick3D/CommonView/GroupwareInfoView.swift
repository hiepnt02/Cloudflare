//
//  GroupwareInfoView.swift
//  Quick3D
//
//  Created by HungNT on 18/6/26.
//

import SwiftUI

struct GroupwareInfoView: View {
    @EnvironmentObject var userManager: UserManager
    
    var fileName: String
    var filePath: String
    var frameWidth: CGFloat?
    var frameHeight: CGFloat?
    var offsetValue: CGSize
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("FILE_NAME".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .font(.caption)
            
            Text(fileName)
                .foregroundColor(userManager.setting.textColor)
                .font(.caption.bold())
                .padding(.bottom, 5)
            
            Text("PATH".localized(userManager.userLanguage))
                .foregroundColor(userManager.setting.textColor.opacity(0.5))
                .font(.caption)
            
            Text(filePath)
                .foregroundColor(userManager.setting.textColor)
                .font(.caption.bold())
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: frameWidth, height: frameHeight, alignment: .leading)
        .padding(.all, 8)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(userManager.setting.themeColor.opacity(0.3))
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 3))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.gray, lineWidth: 1)
        }
        .dynamicTypeSize(DynamicTypeSize.medium)
        .offset(x: offsetValue.width, y: offsetValue.height)
    }
}
