//
//  DatePickerOverlay.swift
//  Quick3D
//
//  Created by HungNT on 20/5/26.
//

import SwiftUI

struct DatePickerOverlay: View {
    @EnvironmentObject var userManager: UserManager
    
    @Binding var dateBinding: Date
    let otherDate: Date?
    let isToDate: Bool
    let isIPhone: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            userManager.setting.textColor.opacity(0.01)
                .ignoresSafeArea(.all)
            
            VStack {
                CustomDatePicker(currentDate: $dateBinding, otherDate: otherDate, isToDate: isToDate)
                    .frame(width: isIPhone ? 300 : 350)
                Spacer()
            }
            .padding(.top, isIPhone ? 7 : UIScreen.main.bounds.height * 0.3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            onDismiss()
        }
    }
}
