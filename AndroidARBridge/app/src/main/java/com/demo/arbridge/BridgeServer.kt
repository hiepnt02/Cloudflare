package com.demo.arbridge

import android.util.Log
import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import java.net.InetSocketAddress
import java.net.NetworkInterface

/** WebSocket server: app iOS (Simulator trên Mac) kết nối ws://<ip-điện-thoại>:PORT để nhận frame. */
class BridgeServer(port: Int) : WebSocketServer(InetSocketAddress(port)) {

    init {
        isReuseAddr = true
        isTcpNoDelay = true
    }

    val clientCount: Int get() = connections.size

    /** Client đọc chậm hơn tốc độ gửi → bỏ frame thay vì dồn hàng đợi (trễ sẽ tăng dần). */
    val isBackedUp: Boolean get() = connections.any { it.hasBufferedData() }

    override fun onOpen(conn: WebSocket, handshake: ClientHandshake) {
        Log.i(TAG, "Client vào: ${conn.remoteSocketAddress}")
    }

    override fun onClose(conn: WebSocket, code: Int, reason: String?, remote: Boolean) {
        Log.i(TAG, "Client ra: ${conn.remoteSocketAddress} ($code)")
    }

    override fun onMessage(conn: WebSocket, message: String) {}

    override fun onError(conn: WebSocket?, ex: Exception) {
        Log.e(TAG, "WebSocket lỗi", ex)
    }

    override fun onStart() {
        Log.i(TAG, "Server chạy cổng $port")
    }

    companion object {
        private const val TAG = "BridgeServer"

        /** IPv4 trong LAN (Wi-Fi) để hiện lên màn hình cho dễ nhập bên iOS. */
        fun lanAddress(): String? = NetworkInterface.getNetworkInterfaces().toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.toList() }
            .firstOrNull { it.isSiteLocalAddress && it.hostAddress?.contains(':') == false }
            ?.hostAddress
    }
}
