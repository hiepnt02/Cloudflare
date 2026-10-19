//
//  FileInfoView.swift
//  Quick3D
//
//  Created by HungNT on 9/9/25.
//

import SwiftUI

struct FileInfoView: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var fileName: String
    @Binding var fileSize: String

    var body: some View {
        HStack {
            Image("icFolderZip")
                .resizable()
                .frame(
                    width: UserSession.isIPhone ? 40 : 55,
                    height: UserSession.isIPhone ? 40 : 55
                )
                .foregroundColor(userManager.setting.textColor)
            
            VStack(alignment: .leading) {
                Text(fileName.removingPercentEncoding ?? "")
                    .lineLimit(1)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.subheadline)

                Text(fileSize)
                    .lineLimit(1)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 5)
        }
        .padding(.leading, 25)
    }
}
