//
//  NetworkView.swift
//  Quick3D
//
//  Created by HungNT on 29/1/26.
//

import SwiftUI

struct NetworkView: View {
    @StateObject private var network = NetworkManager()
    @StateObject private var monitor = RealTimeNetworkMonitor()
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Kết nối")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white)
                
                Spacer()
                
                Text(network.isConnected ? "Online" : "Offline")
                    .font(.system(size: 14))
                    .foregroundColor(network.isConnected ? .green : .red)
            }
            
            HStack {
                Text("Loại mạng")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white)
                
                Spacer()
                
                Text(network.connectionType)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white)
            }
            .padding(.bottom, 8)
            
            Text("Tốc độ mạng")
                .font(.system(size: 14))
                .foregroundColor(Color.white)
            
            HStack(spacing: 8) {
                VStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                    
                    Text(monitor.downloadSpeed)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.white)
                    
                    Text("Download")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white)
                }
                
                VStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text(monitor.uploadSpeed)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.white)
                    
                    Text("Upload")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(imperialBlue.opacity(0.5))
        )
        .frame(maxWidth: 200)
    }
}
