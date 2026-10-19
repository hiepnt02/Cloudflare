//
//  UploadBatchResultPopup.swift
//  Quick3D
//
//  QU3DW-1423 — the one summary shown when a whole upload batch is done.
//

import SwiftUI

struct UploadBatchResultPopup: View {

    @EnvironmentObject var userManager: UserManager

    let result: UploadBatchResult?
    var onClose: () -> Void

    @State private var listHeight: CGFloat = 0

    private var isIPhone: Bool { UserSession.isIPhone }
    private var popupWidth: CGFloat { isIPhone ? 300 : 420 }
    private var maxListHeight: CGFloat { UIScreen.main.bounds.height * (isIPhone ? 0.45 : 0.5) }

    var body: some View {
        ZStack {
            if let result {
                Color(userManager.setting.colorTheme == .light ? .black : .white)
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                contentView(result)
                    .frame(width: popupWidth)
                    .background(userManager.setting.themeColor)
                    .border(.gray, width: 1)
            }
        }
    }

    private func contentView(_ result: UploadBatchResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("UPLOAD_RESULT_TITLE".localized(userManager.userLanguage))
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 15 : 18, weight: .bold))

                Spacer(minLength: 0)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(userManager.setting.textColor)
                }
            }

            Divider()

            entryList(result)

            Button {
                onClose()
            } label: {
                Text("CLOSE".localized(userManager.userLanguage))
                    .font(.system(size: isIPhone ? 14 : 16))
                    .foregroundColor(.white)
                    .frame(height: isIPhone ? 32 : 40)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .background(.blue)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, isIPhone ? 14 : 18)
        .padding(.vertical, isIPhone ? 12 : 16)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func entryList(_ result: UploadBatchResult) -> some View {
        ScrollView(showsIndicators: listHeight > maxListHeight) {
            VStack(alignment: .leading, spacing: isIPhone ? 10 : 12) {
                ForEach(result.entries) { entry in
                    entryRow(entry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .frame(height: min(max(listHeight, 1), maxListHeight))
        .onPreferenceChange(ContentHeightKey.self) { listHeight = $0 }
    }

    private func entryRow(_ entry: UploadBatchResult.Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.displayName)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.system(size: isIPhone ? 13 : 15, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusKey(for: entry).localized(userManager.userLanguage))
                    .foregroundColor(entry.outcome.isSuccess ? userManager.setting.textColor : .red)
                    .font(.system(size: isIPhone ? 12 : 14))
                    .fixedSize()
            }

            ForEach(entry.fileNames, id: \.self) { fileName in
                Text(fileName)
                    .foregroundColor(userManager.setting.textColor.opacity(0.7))
                    .font(.system(size: isIPhone ? 11 : 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statusKey(for entry: UploadBatchResult.Entry) -> String {
        entry.outcome.isSuccess ? "UPLOAD_COMPLETED" : "UPLOAD_ERROR"
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
