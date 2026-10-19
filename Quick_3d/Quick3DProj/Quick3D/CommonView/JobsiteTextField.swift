//
//  JobSiteTextField.swift
//  Quick3D
//
//  Created by HungNT on 7/7/25.
//

import Foundation
import SwiftUI

struct JobsiteTextField: View {
    @EnvironmentObject var userManager: UserManager
    
    var listData: [JobSite.Site] = []
    
    @Binding var isShowPopup: Bool
    @Binding var inputText: String
    @Binding var jobSiteSelected: JobSite.Site?
    @FocusState var isFocus: Bool
    
    // Should return Site each time user has selected JobSite
    var handler: (JobSite.Site?) -> Void
    
    @State var filteredJobsites: [JobSite.Site] = []
    @State private var scrollHeight: CGFloat = 0
    
    private let itemHeight: CGFloat = UserSession.isIPhone ? 40 : 55
    private let popupMaxHeight: CGFloat = 160
    private let offsetY: CGFloat = UserSession.isIPhone ? 45 : 60
    
    var body: some View {
        HStack(spacing: 0) {
            TextField(
                "PLS_SELECT".localized(userManager.userLanguage),
                text: $inputText
            )
            .foregroundColor(userManager.setting.textColor)
            .focused($isFocus)
            .padding(.leading, 10)

            if !inputText.isEmpty {
                Button(
                    action: {
                        inputText = ""
                        handler(nil)
                    }
                ) {
                    Text("✖")
                        .font(.system(size: 20).bold())
                        .foregroundColor(userManager.setting.textColor)
                }
                .frame(width: 40, height: 40)
            }

            Button(action: {
                isShowPopup.toggle()
                inputText = jobSiteSelected?.name ?? ""
                isFocus = false
                if isShowPopup {
                    filterList()
                }
            }) {
                Image("arrowDown")
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.textColor)
                    .rotationEffect(.degrees(isShowPopup ? 180 : 0))
            }
            .frame(width: 40, height: 40)
        }
        .foregroundColor(userManager.setting.textColor)
        .frame(height: itemHeight, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(.lightGray), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if isShowPopup {
                listJobSitesView()
            }
        }
        .padding(.bottom, 10)
        .onChange(of: inputText) { value in
            filterList()
        }
        .onChange(of: isFocus) { focus in
            if focus {
                filterList()
                isShowPopup = true
            }
            
            if !focus && filteredJobsites.isEmpty {
                inputText = jobSiteSelected?.name ?? ""
                isShowPopup = false
                handler(nil)
            }
        }
    }
    
    func listJobSitesView() -> some View {
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredJobsites, id: \.self) { jobSite in
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            inputText = jobSite.name
                            isFocus = false
                            isShowPopup = false
                            handler(jobSite)
                        }) {
                            Text(jobSite.name)
                                .font(.system(size: 16))
                                .multilineTextAlignment(.center)
                                .foregroundColor(userManager.setting.textColor)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .contentShape(Rectangle())
                        }

                        if filteredJobsites.count > 1 {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(height: scrollHeight)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(.lightGray), lineWidth: 1)
                .background((userManager.setting.colorTheme == .light) ? .white : Color.colorBgDark)
        )
        .frame(alignment: .bottomLeading)
        .offset(y: -offsetY)
        .zIndex(30)
    }
    
    private func filterList() {
        if inputText.isEmpty {
            filteredJobsites = listData
        } else {
            filteredJobsites = listData.filter {$0.name.localizedCaseInsensitiveContains(inputText)}
        }

        scrollHeight =
        filteredJobsites.count < 4 ? (40 * CGFloat(filteredJobsites.count)) : popupMaxHeight
    }
}
