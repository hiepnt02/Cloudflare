package com.demo.arbridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.NotYetAvailableException
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Chạy ARCore (= ARKit của Android) và mỗi frame gửi cho app iOS:
 *   [4 byte độ dài header][header JSON: pose 6DoF, intrinsics, hit-test][JPEG ảnh camera]
 * Ảnh và pose lấy từ CÙNG một Frame nên khớp nhau tuyệt đối.
 *
 * Màn hình điện thoại không vẽ hình camera (chỉ chữ trạng thái) — nhìn hình trên Simulator.
 */
class MainActivity : Activity(), GLSurfaceView.Renderer {

    private lateinit var surface: GLSurfaceView
    private lateinit var statusView: TextView

    private var session: Session? = null
    private var installRequested = false

    // GL thread
    private var cameraTextureId = -1
    private var textureBound = false
    private var viewWidth = 0
    private var viewHeight = 0
    private var geometryChanged = false
    private var lastSentNs = 0L
    private var lastStatusMs = 0L
    private var planeCount = 0

    private val server = BridgeServer(PORT)
    private val encoder = Executors.newSingleThreadExecutor()
    private val encoding = AtomicBoolean(false)
    @Volatile private var sentFps = 0.0
    private var sentFrames = 0
    private var fpsWindowMs = SystemClock.elapsedRealtime()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        surface = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@MainActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        statusView = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(32, 32, 32, 32)
        }
        setContentView(FrameLayout(this).apply {
            addView(surface)
            addView(statusView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP))
        })

        server.start()
    }

    override fun onResume() {
        super.onResume()
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), 0)
            return
        }
        if (session == null) {
            try {
                if (ArCoreApk.getInstance().requestInstall(this, !installRequested) ==
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                    installRequested = true
                    return
                }
                session = Session(this).also { s ->
                    s.configure(Config(s).apply {
                        planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                        focusMode = Config.FocusMode.AUTO
                        lightEstimationMode = Config.LightEstimationMode.DISABLED
                        updateMode = Config.UpdateMode.BLOCKING
                    })
                }
            } catch (e: Exception) {
                statusView.text = "Không khởi động được ARCore: $e"
                return
            }
        }
        try {
            session?.resume()
        } catch (e: CameraNotAvailableException) {
            statusView.text = "Camera đang bị app khác dùng (tắt IP Webcam?)"
            session = null
            return
        }
        surface.onResume()
    }

    override fun onPause() {
        super.onPause()
        surface.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        session?.close()
        session = null
        server.stop(500)
        encoder.shutdown()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (results.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "Cần quyền camera", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    // ---- GLSurfaceView.Renderer (GL thread) ----

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        // ARCore bắt buộc có texture OES để đổ hình camera vào, dù ta không vẽ nó
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        cameraTextureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        textureBound = false
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewWidth = width
        viewHeight = height
        geometryChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return
        if (!textureBound) {
            s.setCameraTextureName(cameraTextureId)
            textureBound = true
        }
        if (geometryChanged) {
            @Suppress("DEPRECATION")
            s.setDisplayGeometry(windowManager.defaultDisplay.rotation, viewWidth, viewHeight)
            geometryChanged = false
        }
        val frame = try { s.update() } catch (e: Exception) { return }

        maybeSend(frame)

        val now = SystemClock.elapsedRealtime()
        if (now - lastStatusMs > 500) {
            lastStatusMs = now
            planeCount = s.getAllTrackables(Plane::class.java).count { it.trackingState == TrackingState.TRACKING }
            val planes = planeCount
            val text = "ws://${BridgeServer.lanAddress() ?: "?"}:$PORT\n" +
                "Client: ${server.clientCount} · Tracking: ${frame.camera.trackingState} · Mặt phẳng: $planes\n" +
                "Gửi: ${"%.1f".format(sentFps)} fps\n" +
                "Cầm NGANG, đỉnh máy bên trái. Quét chậm sàn/bàn để ARCore bắt mặt phẳng."
            runOnUiThread { statusView.text = text }
        }
    }

    private fun maybeSend(frame: Frame) {
        if (server.clientCount == 0 || encoding.get() || server.isBackedUp) return
        val now = SystemClock.elapsedRealtimeNanos()
        if (now - lastSentNs < MIN_INTERVAL_NS) return

        val image = try { frame.acquireCameraImage() } catch (e: NotYetAvailableException) { return }
        val width = image.width
        val height = image.height
        val nv21 = try { yuvToNv21(image) } finally { image.close() }

        val camera = frame.camera
        val tracking = camera.trackingState
        val pose = FloatArray(16)
        // getPose() theo hướng ảnh CPU (không theo màn hình) — khớp với ảnh gửi đi
        camera.pose.toMatrix(pose, 0)
        val intr = camera.imageIntrinsics
        val focal = intr.focalLength
        val pp = intr.principalPoint
        val dims = intr.imageDimensions
        // Intrinsics tính theo dims; quy về đúng kích thước ảnh CPU nếu khác
        val sx = width.toFloat() / dims[0]
        val sy = height.toFloat() / dims[1]
        val hit = if (tracking == TrackingState.TRACKING) hitTestCenter(frame) else null
        val planes = planeCount
        val timestamp = frame.timestamp

        lastSentNs = now
        encoding.set(true)
        encoder.execute {
            try {
                val jpeg = ByteArrayOutputStream(64 * 1024)
                YuvImage(nv21, ImageFormat.NV21, width, height, null)
                    .compressToJpeg(Rect(0, 0, width, height), JPEG_QUALITY, jpeg)

                val header = JSONObject().apply {
                    put("t", timestamp)
                    put("tracking", tracking.name)
                    put("pose", JSONArray().also { a -> pose.forEach { a.put(it.toDouble()) } })
                    put("fx", (focal[0] * sx).toDouble())
                    put("fy", (focal[1] * sy).toDouble())
                    put("cx", (pp[0] * sx).toDouble())
                    put("cy", (pp[1] * sy).toDouble())
                    put("w", width)
                    put("h", height)
                    put("hit", hit?.let { h -> JSONArray().also { a -> h.forEach { a.put(it.toDouble()) } } } ?: JSONObject.NULL)
                    put("planes", planes)
                }.toString().toByteArray(Charsets.UTF_8)

                val jpegBytes = jpeg.toByteArray()
                val message = ByteBuffer.allocate(4 + header.size + jpegBytes.size)
                    .putInt(header.size)                 // big-endian mặc định
                    .put(header)
                    .put(jpegBytes)
                    .array()
                server.broadcast(message)

                sentFrames++
                val ms = SystemClock.elapsedRealtime()
                if (ms - fpsWindowMs >= 1000) {
                    sentFps = sentFrames * 1000.0 / (ms - fpsWindowMs)
                    sentFrames = 0
                    fpsWindowMs = ms
                }
            } catch (e: Exception) {
                android.util.Log.e("ARBridge", "Gửi frame lỗi", e)
            } finally {
                encoding.set(false)
            }
        }
    }

    /** Tia từ giữa màn hình chạm mặt phẳng ngang (sàn/bàn) → toạ độ world để iOS đặt model. */
    private fun hitTestCenter(frame: Frame): FloatArray? {
        if (viewWidth == 0 || viewHeight == 0) return null
        for (hit in frame.hitTest(viewWidth / 2f, viewHeight / 2f)) {
            val plane = hit.trackable as? Plane ?: continue
            if (plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING && plane.isPoseInPolygon(hit.hitPose)) {
                val p = hit.hitPose
                return floatArrayOf(p.tx(), p.ty(), p.tz())
            }
        }
        return null
    }

    /** YUV_420_888 (ảnh CPU của ARCore) → NV21 cho YuvImage; xử lý mọi rowStride/pixelStride. */
    private fun yuvToNv21(image: Image): ByteArray {
        val w = image.width
        val h = image.height
        val out = ByteArray(w * h * 3 / 2)
        var pos = 0

        val yPlane = image.planes[0]
        val yBuf = yPlane.buffer
        for (row in 0 until h) {
            if (yPlane.pixelStride == 1) {
                yBuf.position(row * yPlane.rowStride)
                yBuf.get(out, pos, w)
                pos += w
            } else {
                for (col in 0 until w) out[pos++] = yBuf.get(row * yPlane.rowStride + col * yPlane.pixelStride)
            }
        }

        val u = image.planes[1]
        val v = image.planes[2]
        val uBuf = u.buffer
        val vBuf = v.buffer
        for (row in 0 until h / 2) {
            for (col in 0 until w / 2) {
                out[pos++] = vBuf.get(row * v.rowStride + col * v.pixelStride)
                out[pos++] = uBuf.get(row * u.rowStride + col * u.pixelStride)
            }
        }
        return out
    }

    companion object {
        const val PORT = 8090
        private const val JPEG_QUALITY = 75
        private const val MIN_INTERVAL_NS = 40_000_000L      // tối đa ~25 fps
    }
}
