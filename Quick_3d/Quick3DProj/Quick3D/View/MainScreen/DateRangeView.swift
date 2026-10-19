//
//  DateRangeView.swift
//  Quick3D
//

import SwiftUI

struct DateRangeView: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var fromDate: Date?
    @Binding var toDate: Date?
    let onFromTap: () -> Void
    let onToTap: () -> Void
    let onClear: () -> Void

    private var isIPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    private var dateFormat: String {
        userManager.userLanguage == LanguageMode.ja.rawValue ? Constant.jpDateFormat : Constant.otherDateFormat
    }

    var body: some View {
        HStack {
            DatePickerButton(
                date: $fromDate,
                placeholder: "From".localized(userManager.userLanguage),
                width: isIPhone ? 90 : 170,
                horizontalPadding: 5,
                clearTrailingPadding: 0,
                dateFormat: dateFormat,
                onTap: onFromTap,
                onClear: { fromDate = nil; onClear() }
            )

            Text("~")
                .foregroundColor(userManager.setting.textColor)

            DatePickerButton(
                date: $toDate,
                placeholder: "To".localized(userManager.userLanguage),
                width: isIPhone ? 90 : 170,
                horizontalPadding: 5,
                clearTrailingPadding: 0,
                dateFormat: dateFormat,
                onTap: onToTap,
                onClear: { toDate = nil; onClear() }
            )
        }
    }
}

// MARK: - DatePickerButton

private struct DatePickerButton: View {
    @EnvironmentObject var userManager: UserManager

    @Binding var date: Date?
    let placeholder: String
    let width: CGFloat
    let horizontalPadding: CGFloat
    let clearTrailingPadding: CGFloat
    let dateFormat: String
    let onTap: () -> Void
    let onClear: () -> Void

    private var isIPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        Button(action: onTap) {
            HStack {
                if date == nil {
                    Text(placeholder)
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.system(size: isIPhone ? 10 : 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(date?.toString(format: dateFormat) ?? "")
                        .foregroundColor(userManager.setting.textColor)
                        .font(.system(size: isIPhone ? 10 : 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .contentShape(Rectangle())
            .frame(width: width, height: isIPhone ? 32 : 42)
            .border(.gray, width: 1)
        }
        .overlay(alignment: .trailing) {
            if date != nil {
                Button(action: onClear) {
                    Text("✖")
                        .font(.system(size: 16).bold())
                        .foregroundColor(userManager.setting.textColor)
                        .padding(.trailing, clearTrailingPadding)
                }
            }
        }
    }
}
