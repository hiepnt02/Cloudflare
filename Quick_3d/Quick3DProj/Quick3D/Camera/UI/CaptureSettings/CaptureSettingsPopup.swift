//
//  CaptureSettingView.swift
//  Quick3D
//
//  Created by Admin on 30/12/25.
//

import SwiftUI

enum CaptureMenuTypeEnum: String, Hashable, CaseIterable {
    case captureSetting

    var title: String {
        switch self {
        case .captureSetting:
            return "CAPTURE_SETTING"
        }
    }
}

struct CaptureSettingsPopup: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var pendingSettings: CapturePendingSettings

    @Binding var isShow: Bool

    var onSave: (() -> Void)? = nil

    @State private var showUnsavedAlert = false
    @State private var isSaved = false
    @State private var isLoading = false

    // Lifted navigation state
    @State private var iphonePath: [String] = []
    @State private var ipadDetailPath: [String] = []
    @State private var ipadSelection: CaptureMenuTypeEnum? = .captureSetting

    private var isIphone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    private var currentTitle: String {
        if isIphone {
            return titleForRoute(iphonePath.last)
        } else {
            return ipadDetailPath.isEmpty
                ? (ipadSelection?.title ?? "SETTINGS")
                : titleForRoute(ipadDetailPath.last)
        }
    }

    private var showSaveButton: Bool {
        isIphone ? !iphonePath.isEmpty : ipadSelection != nil
    }

    private func titleForRoute(_ route: String?) -> String {
        switch route {
        case CaptureMenuTypeEnum.captureSetting.rawValue: return "CAPTURE_SETTING"
        case "DetailCaptureSetting": return "DETAIL_CAPTURE_SETTING"
        default: return "SETTINGS"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader

            if isIphone {
                StackRootView(path: $iphonePath)
            } else {
                SplitRootView(detailPath: $ipadDetailPath, selection: $ipadSelection)
            }
        }
        .environmentObject(pendingSettings)
        .onChange(of: pendingSettings.isDirty) { isDirty in
            if isDirty { isSaved = false }
        }
        .alert(
            "WARNING".localized(userManager.userLanguage),
            isPresented: $showUnsavedAlert
        ) {
            Button("CANCEL".localized(userManager.userLanguage), role: .none) {}
            Button("YES".localized(userManager.userLanguage), role: .none) {
                pendingSettings.reset()
                isShow = false
            }
        } message: {
            Text("CHANGES_NOT_SAVED".localized(userManager.userLanguage))
        }
    }

    private var settingsHeader: some View {
        Group {
            if isIphone {
                ZStack {
                    Text(currentTitle.localized(userManager.userLanguage).capitalized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(userManager.setting.textColor)

                    HStack {
                        Button(action: handleBack) {
                            Image("ic_arrow_down_white")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(90))
                                .foregroundColor(userManager.setting.textColor)
                        }

                        Spacer()

                        if showSaveButton {
                            saveButtonContent
                        } else {
                            Color.clear.frame(width: 18, height: 18)
                        }
                    }
                }
            } else {
                HStack {
                    Button(action: handleBack) {
                        HStack {
                            Image("ic_arrow_down_white")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(90))
                                .foregroundColor(userManager.setting.textColor)

                            Text("SETTINGS".localized(userManager.userLanguage))
                                .font(.system(size: 20))
                                .foregroundColor(userManager.setting.textColor)
                        }
                    }

                    Spacer()

                    saveButtonContent
                }
            }
        }
        .frame(height: isIphone ? 22 : 28)
        .padding(contentPadding)
    }

    @ViewBuilder
    private var saveButtonContent: some View {
        if isLoading {
            ProgressView()
                .tint(userManager.setting.textColor)
        } else if isSaved {
            Button("SAVED".localized(userManager.userLanguage)) {}
                .foregroundColor(userManager.setting.textColor)
        } else {
            Button("SAVE".localized(userManager.userLanguage)) {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pendingSettings.apply()
                    onSave?()
                    isSaved = true
                    isLoading = false
                    hideKeyboard()
                }
            }
            .foregroundColor(pendingSettings.isDirty
                ? userManager.setting.textColor
                : userManager.setting.textColor.opacity(0.3))
            .disabled(!pendingSettings.isDirty)
        }
    }

    private func handleBack() {
        if isIphone {
            if !iphonePath.isEmpty { iphonePath.removeLast(); return }
        } else {
            if !ipadDetailPath.isEmpty {
                ipadDetailPath.removeLast()
                return
            }
        }
        if pendingSettings.isDirty {
            showUnsavedAlert = true
        } else {
            isShow = false
        }
    }
}

// MARK: - Router
@ViewBuilder
func DetailRouter(selection: String?, pushDetail: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) -> some View {
    switch selection {
    case CaptureMenuTypeEnum.captureSetting.rawValue:
        CaptureSettingView(pushDetail: pushDetail)
    case "DetailCaptureSetting":
        CaptureSettingDetailView()
    default:
        Text("Select an item").foregroundColor(.secondary)
    }
}

// MARK: - iPad View (Split)
struct SplitRootView: View {
    @Binding var detailPath: [String]
    @Binding var selection: CaptureMenuTypeEnum?

    var body: some View {
        HStack(spacing: 0) {
            CaptureItemMenuView(selection: $selection) {
                detailPath = []
            }
            .frame(width: 400)

            if #available(iOS 16.0, *) {
                NavigationStack(path: $detailPath) {
                    DetailRouter(
                        selection: selection?.rawValue,
                        pushDetail: {
                            detailPath.append("DetailCaptureSetting")
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: String.self) { route in
                        if route == "DetailCaptureSetting" {
                            CaptureSettingDetailView()
                                .toolbar(.hidden, for: .navigationBar)
                        } else {
                            DetailRouter(selection: route)
                                .toolbar(.hidden, for: .navigationBar)
                        }
                    }
                }
            } else {
                NavigationView {
                    VStack {
                        if detailPath.last == "DetailCaptureSetting" {
                            CaptureSettingDetailView()
                                .navigationBarHidden(true)
                        } else {
                            DetailRouter(
                                selection: selection?.rawValue,
                                pushDetail: {
                                    detailPath.append("DetailCaptureSetting")
                                }
                            )
                            .navigationBarHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - iPhone View (Stack)
struct StackRootView: View {
    @Binding var path: [String]
    @State private var selection: CaptureMenuTypeEnum?

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(path: $path) {
                CaptureItemMenuView(selection: $selection) {
                    if let sel = selection { path.append(sel.rawValue) }
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { route in
                    DetailRouter(
                        selection: route,
                        pushDetail: { path.append("DetailCaptureSetting") }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
        } else {
            NavigationView {
                CaptureItemMenuView(selection: $selection)
                    .navigationBarHidden(true)
                DetailRouter(selection: selection?.rawValue)
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(.stack)
        }
    }
}
