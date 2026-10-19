//
//  RenameAlert.swift
//  Quick3D
//

import SwiftUI
import Alamofire

struct RenameAlert: View {
    @Binding var presentedAsModal: Bool
    var cat: Cat?
    @State var newName: String = ""
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var productData: ProductData
    @EnvironmentObject var uploadProject: UploadProject
    @EnvironmentObject var editProject: EditProject
    
    @State private var isIPhone = UIDevice.current.isIphone
    @State private var isKeyboardShow = false
    @FocusState var focusedField: Bool
    @State private var isPjNameValid = false
    
    var handler: (String) -> Void
    
    var body: some View {
        ZStack {
            if presentedAsModal {
                Color(userManager.setting.colorTheme ==
                    .light ? .black : .white)
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    contentView.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = true
                    }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {_ in
                        // Bool変数を変更
                        isKeyboardShow = false
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * (focusedField ? 0.45 : 1.0))
                .frame(height: isIPhone ? 350 : 350)
            }
        }
    }
    
    private var contentView: some View {
            ZStack() {
                VStack(spacing: 0) {
                    HStack {
                        Text("CHANGE_PROJECT".localized(userManager.userLanguage))
                            .foregroundColor(userManager.setting.textColor)
                            .font(.title2.bold())
                        Spacer()
                        Button(action: {
                            self.presentedAsModal.toggle()
                            
                            // Should send event back to add project in queue
                            // in case previous state this project is in queue
                            if editProject.isInQueue {
                                handler(newName)
                            }
                        }, label: {
                            Image(systemName: "xmark")
                                .foregroundColor(userManager.setting.textColor)
                        })
                    }.padding(EdgeInsets(top: 30, leading: 0, bottom: 10, trailing: 0))

                    Divider()
                        .frame(height: 1)
                        .background(userManager.setting.textColor)
                        .padding(.bottom, 20)

                    TextField("Title", text: $newName)
                        .focused($focusedField)
                        .foregroundColor(userManager.setting.textColor)
                        .disableAutocorrection(true)
                        .padding(15)
                        .overlay(
                            Rectangle().stroke(Color(.lightGray), lineWidth: 1)
                        )
                        .modifier(ClearButton(text: $newName))
                        .font(.body)
                        .padding(.bottom, 5)
                        .onAppear() {
                            if let cat = cat {
                                newName = cat.title
                            } else {
                                newName = editProject.projectName
                            }
                        }
                        .onChange(of: newName) { textInputted in
                            isPjNameValid = textInputted.validateProjectName()
                        }
                    
                    Text("PROJECT_NAME_IS_INVALID".localized(userManager.userLanguage))
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)
                        .opacity(isPjNameValid ? 0.0 : 1.0)

                    HStack(spacing: 25) {
                        Button(
                            action: {
                                self.presentedAsModal.toggle()
                                
                                // Should send event back to add project in queue
                                // in case previous state this project is in queue
                                if editProject.isInQueue {
                                    handler(newName)
                                }
                            },
                            label: {
                                Text("CANCEL".localized(userManager.userLanguage))
                                    .frame(height: 40, alignment: .center)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .foregroundColor(userManager.setting.textColor)
                                    .font(.footnote.bold())
                                    .contentShape(Rectangle())
                            }
                        )
                        .buttonStyle(PlainButtonStyle())
                        .border(.gray, width: 1)

                        Button(
                            action: {
                                guard validate(newName: newName) else {
                                    APAlert.shared.showAlert(title: "", message: "PROHIBITED_CHARACTER_MESSAGE".localized(userManager.userLanguage), buttonTitle: "CLOSE".localized(userManager.userLanguage))
                                    return
                                }
                                
                                // Old case
                                if let cat = cat {
                                    if cat.projectId != nil {
                                        self.save(newName: newName, for: cat.projectId!)
                                    }
                                    productData.updateTitle(for: cat, title: newName)
                                }
                                
                                // New case
                                if let currentCat = editProject.currentCat {
                                    if let projectId = currentCat.projectId {
                                        self.save(newName: newName, for: projectId)
                                    }
                                    productData.updateTitle(for: currentCat, title: newName)
                                }
                                
                                self.presentedAsModal.toggle()
                                
                                // Should send event back to add project in queue
                                // in case previous state this project is in queue
                                if editProject.isInQueue {
                                    handler(newName)
                                }
                            },
                            label: {
                                Text("SAVE".localized(userManager.userLanguage))
                                    .frame(height: 40, alignment: .center)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .font(.footnote.bold())
                                    .foregroundColor(.white)
                                    .background(
                                        (newName.isEmpty || !isPjNameValid)
                                        ? Color.gray.opacity(0.7)
                                        : userManager.setting.buttonColor
                                    )
                                    .cornerRadius(2)
                                    .contentShape(Rectangle())
                            }
                        )
                        .buttonStyle(PlainButtonStyle())
                        .disabled(newName.isEmpty || !isPjNameValid)
                    }.padding(.bottom, 30)
                }
            }
            .frame(width: isIPhone ? 500 : 700)
            .padding(.horizontal, isIPhone ? 20 : 30)
            .background(userManager.setting.themeColor)
            .border(.gray, width: 1)
        }
}

extension RenameAlert {
    func validate(newName: String) -> Bool {
        focusedField = false
        return ProductUtil.validationCheck(newName)
    }

    func save(newName: String, for projectID: String) {
        AF.request(URL(string: Constant.baseUrl + "api/v1/project/\(projectID)")!, method: .put, parameters: ["name": newName])
            .validate()
            .response {
                data in
                print(data)
            }
    }
}
