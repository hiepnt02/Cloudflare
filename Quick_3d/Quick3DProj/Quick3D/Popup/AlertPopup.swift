//
//  AlertPopup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 13/10/2022.
//

import SwiftUI

private struct AlertView: View {

    /// parameter to hide and show loader
    @Binding var isShowing: Bool

    let titleText: String
    let messageText: String
    let buttonText: String

    var body: some View {

        ZStack(alignment: .center) {

            VStack(spacing: 10) {

                if !titleText.isEmpty {
                    Text(titleText)
                        .foregroundColor(.white)
                        .font(.system(size: 17).bold())
                        .padding(.top, 20)
                }

                Text(messageText)
                    .lineSpacing(3)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)

                Divider()
                    .frame(height: 1)

                Button(action: {
                    APAlert.shared.remove()
                }) {
                    Text(buttonText)
                        .font(.system(size: 16).bold())
                        .foregroundColor(.blue)
                }
                .frame(width: 100, height: 30)
                .padding(.bottom, 10)
            }
            .frame(width: 400)
            .background(Color(hex: 0x17171a))
            .cornerRadius(10.0)
        }
    }
}

private struct AlertWithTheme: View {
    @EnvironmentObject var userManager: UserManager
    
    let titleText: String
    let messageText: String
    let buttonText: String
    
    var body: some View {
        ZStack {
            Color(userManager.setting.colorTheme == .light ? .black : .white)
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .center, spacing: 0) {
                if !titleText.isEmpty {
                    Text(titleText)
                        .foregroundColor(userManager.setting.textColor)
                        .font(.title3)
                        .padding(.bottom, 20)
                }
                
                Text(messageText)
                    .foregroundColor(userManager.setting.textColor)
                    .font(.body)
                    .padding(.bottom, 30)
                
                Button(
                    action: {
                        withAnimation(.linear(duration: 0.3)) {
                            APAlert.shared.remove()
                        }
                    },
                    label: {
                        Text(buttonText)
                            .frame(height: 40, alignment: .center)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .background(.blue)
                            .cornerRadius(2)
                    }
                )
                .buttonStyle(PlainButtonStyle())
                .frame(width: 250)
            }
            .padding(30)
            .frame(width: 500)
            .background(userManager.setting.themeColor)
            .border(.gray, width: 1)
        }
    }
}

public class APAlert {
    public static var shared = APAlert()
    private init() { }
    private var popupWindow: AlertWindow?

    public func showAlert(title: String = "Error", message: String = "Request could not be processed due to a server error. The request may succeed if you try again.", buttonTitle: String = "Ok") {
        setAlertBody(title: title, message: message, buttonTitle: buttonTitle)
    }
    
    func showAlertWithTheme(
        title: String,
        message: String,
        buttonTitle: String = "OK",
        userManager: UserManager
    ) {
        alertBodyWithTheme(
            title: title,
            message: message,
            buttonTitle: buttonTitle,
            userManager: userManager
        )
    }

    /// function to remove loader from screen.
    public func remove() {
        removeAlert()
    }
}

// MARK: - AlertWindow
private class AlertWindow: UIWindow {}

private extension APAlert {

    func setAlertBody(title: String = "", message: String = "", buttonTitle: String = "") {

        let windowScene = UIApplication.shared
            .connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first
        if let windowScene = windowScene as? UIWindowScene {
            popupWindow = AlertWindow(windowScene: windowScene)
            popupWindow?.frame = UIScreen.main.bounds
            popupWindow?.backgroundColor = .clear
            popupWindow?.rootViewController = UIHostingController(rootView: AlertView(isShowing: .constant(true), titleText: title, messageText: message, buttonText: buttonTitle))
            popupWindow?.rootViewController?.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            popupWindow?.makeKeyAndVisible()
        }
    }
    
    func alertBodyWithTheme(
        title: String = "",
        message: String = "",
        buttonTitle: String = "",
        userManager: UserManager
    ) {
        let windowScene = UIApplication.shared
            .connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first
        if let windowScene = windowScene as? UIWindowScene {
            popupWindow = AlertWindow(windowScene: windowScene)
            popupWindow?.frame = UIScreen.main.bounds
            popupWindow?.backgroundColor = .clear
            popupWindow?.rootViewController = UIHostingController(
                rootView: AlertWithTheme(
                    titleText: title,
                    messageText: message,
                    buttonText: buttonTitle
                )
                .environmentObject(userManager)
            )
            popupWindow?.rootViewController?.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            popupWindow?.makeKeyAndVisible()
        }
    }
    
    /// Remove loader from screen
    func removeAlert() {
        let alertwindows = UIApplication.shared.windows.filter { $0 is AlertWindow }
        alertwindows.forEach { (window) in
            window.removeFromSuperview()
        }
        popupWindow = nil
    }
}
