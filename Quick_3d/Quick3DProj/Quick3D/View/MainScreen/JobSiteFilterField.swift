//
//  JobSiteFilterField.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct JobSiteFilterField: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var jobSiteInputText: String
    @Binding var jobSiteSearchText: String
    @Binding var isPopupJobSitesPresented: Bool
    @Binding var tfJobSitePosition: CGPoint
    @Binding var tfJobSiteWidth: CGFloat
    @Binding var tfJobSiteHeight: CGFloat
    @Binding var jobsite: JobSite.Site?
    @FocusState var focusStateJobSite: Bool
    let isIPhone: Bool
    let onClearOrSubmit: () -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            TextField("ALL".localized(userManager.userLanguage), text: $jobSiteInputText)
                .font(.system(size: isIPhone ? 12 : 15))
                .lineLimit(1)
                .padding(.leading, 10)
                .focused($focusStateJobSite)
                .onChange(of: focusStateJobSite) { isFocus in
                    if isFocus { isPopupJobSitesPresented = true }
                }
                .onSubmit {
                    hideKeyboard()
                }
            
            if !jobSiteInputText.isEmpty {
                Button(action: {
                    jobsite = nil
                    jobSiteSearchText = ""
                    jobSiteInputText = ""
                    DispatchQueue.main.async {
                        onClearOrSubmit()
                    }
                }) {
                    Text("✖")
                        .font(.system(size: 20).bold())
                        .foregroundColor(userManager.setting.textColor)
                }
                .deferredRendering(for: 0.5)
            }
            
            Button(action: { isPopupJobSitesPresented.toggle() }) {
                Image("arrowDown")
                    .renderingMode(.template)
                    .foregroundColor(userManager.setting.textColor)
                    .rotationEffect(.degrees(isPopupJobSitesPresented ? 180 : 0))
                    .padding(.trailing, isIPhone ? 0 : 8)
            }
        }
        .frame(width: isIPhone ? 115 : 190, height: isIPhone ? 32 : 42)
        .border(Color.gray, width: 1)
        .overlay(alignment: .topLeading) {
            Text("JOBSITE_NAME".localized(userManager.userLanguage))
                .font(.system(size: isIPhone ? 12 : 15))
                .foregroundColor(userManager.setting.labelColor)
                .background(userManager.setting.themeColor)
                .font(.subheadline)
                .offset(x: 10, y: -8)
        }
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        tfJobSitePosition = geometry.frame(in: .global).origin
                        tfJobSiteWidth = geometry.size.width
                        tfJobSiteHeight = geometry.size.height
                    }
                    .onChange(of: geometry.frame(in: .global).origin) { newPos in
                        tfJobSitePosition = newPos
                    }
            }
        )
        .onChange(of: jobSiteInputText) { value in
            jobSiteSearchText = value.isEmpty ? "" : value
        }
        .onChange(of: focusStateJobSite) { value in
            if value { jobSiteSearchText = "" }
        }
    }
}
