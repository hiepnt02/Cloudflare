//
//  ViewARScreen.swift
//  Quick3D
//
//  Created by HaNST on 9/3/26.
//

import SwiftUI

struct ViewPointCloudScreen: View {
    
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject var userManager: UserManager
        
    @Binding var selectedCat: Cat?
    
    @State private var context = ViewPointCloudContext()
    
    @State private var isError: Bool = false
    
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            SCNPreviewView(context: $context)
                .ignoresSafeArea()
                .onLoad {
                    context.delegate = self
                    if let cat = selectedCat {
                        context.load(for: cat)
                    }
                }
            
            VStack {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.backward")
                                .frame(width: UIDevice.current.isIphone ? 18 : 24,
                                       height: UIDevice.current.isIphone ? 18 : 24)
                            
                            Text("BACK".localized(userManager.userLanguage))
                                .font(.system(size: 16))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.leading, 16)
                    .contentShape(Rectangle())
                    
                    Spacer()
                }
                
                Spacer()
                
            }
            
            if isLoading {
                ProgressLoadingView(text: "")
                    .ignoresSafeArea()
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Error".localized(userManager.userLanguage), isPresented: $isError, actions: {
            Button("OK".localized(userManager.userLanguage)) {
                presentationMode.wrappedValue.dismiss()
            }
        }, message: {
            Text("DOWNLOAD_AR_FAILED_500".localized(userManager.userLanguage))
        })
    }
    
}

extension ViewPointCloudScreen : ViewPointCloudDelegate {
    
    func view(project: Cat, error: any Error) {
        isError = true
    }
    
    func view(project: Cat, loading: Bool) {
        isLoading = loading
    }
    
}
