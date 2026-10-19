//
//  ListColumnHeader.swift
//  Quick3D
//
//  Created by HungNT on 26/5/26.
//

import Foundation
import SwiftUI

struct ProjectColumnHeader: View {
    @EnvironmentObject var userManager: UserManager
    
    let isIPhone: Bool
    @Binding var isEditing: Bool
    
    // Define a structure for each column to make layout management easier
    private enum ColumnType: CaseIterable {
        case name, jobsite, photographer, type, date, photos, status
        
        var localizationKey: String {
            switch self {
            case .name:         return "NAME"
            case .jobsite:      return "JOBSITE"
            case .photographer: return "PHOTOGRAPHER"
            case .type:         return "TYPE"
            case .date:         return "DATE"
            case .photos:       return "NUMBER_OF_PHOTOS"
            case .status:       return "STATUS"
            }
        }
        
        func width(isIPhone: Bool) -> CGFloat? {
            switch self {
            case .name:         return nil // Tương đương minWidth: 0, maxWidth: .infinity
            case .jobsite:      return isIPhone ? 70  : 80
            case .photographer: return isIPhone ? 70  : 130
            case .type:         return isIPhone ? 40  : 54
            case .date:         return isIPhone ? 70  : 100
            case .photos:       return isIPhone ? 60  : 80
            case .status:       return isIPhone ? 80 : 100
            }
        }
        
        var alignment: Alignment {
            self == .type ? .center : .leading
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: isIPhone ? 8 : 12) {
                
                // Leading space while editing (use padding instead of Spacer to optimize rendering)
                if isEditing {
                    Color.clear.frame(width: isIPhone ? 22 : 26)
                }
                
                // Icon placeholder (Thay Spacer bằng Color.clear hoặc padding)
                Color.clear.frame(width: isIPhone ? 150 : 220)
                
                // Iterate over the columns to render them automatically
                ForEach(ColumnType.allCases, id: \.self) { column in
                    let text = column.localizationKey.localized(userManager.userLanguage)
                    
                    if column == .name {
                        Text(text)
                            .font(.system(size: isIPhone ? 13 : 17, weight: .bold))
                            .foregroundColor(userManager.setting.textColor.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: column.alignment) // The name column takes up all the remaining space
                    } else {
                        Text(text)
                            .font(.system(size: isIPhone ? 13 : 17, weight: .bold))
                            .foregroundColor(userManager.setting.textColor.opacity(0.6))
                            // Force unwrap is safe here because every remaining column has an explicit width
                            .frame(width: column.width(isIPhone: isIPhone)!, alignment: column.alignment)
                    }
                }
                
                // Trailing space
                Color.clear.frame(width: isIPhone ? 24 : 32)
            }
            .padding(.horizontal, isIPhone ? 8 : 12)
            .background(userManager.setting.themeColor)
            .frame(height: 50)
            
            Divider()
                .background(Color.gray.opacity(0.5))
        }
    }
}
