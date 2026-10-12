package com.anything.hub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Choreographer
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/** HUD flotante: FPS (Choreographer), Hz panel, RAM libre. */
class GameHudService : Service(), Choreographer.FrameCallback {
    private var wm: WindowManager? = null
    private var root: LinearLayout? = null
    private var tv: TextView? = null
    private val main = Handler(Looper.getMainLooper())
    private var frameCount = 0
    private var lastFpsTs = 0L
    private var fps = 0.0
    private var peakFps = 0.0
    private var fpsSum = 0.0
    private var fpsSamples = 0
    private var minRamMb = Int.MAX_VALUE
    private var title = "Game"
    private var targetFps = 0
    private var panelHz = 60.0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        title = intent?.getStringExtra(EXTRA_TITLE) ?: "Game"
        targetFps = intent?.getIntExtra(EXTRA_TARGET, 0) ?: 0
        startForeground(NOTIF_ID, buildNotif())
        showOverlay()
        Choreographer.getInstance().postFrameCallback(this)
        isActive = true
        main.post(metricsPublisher)
        return START_STICKY
    }

    private val metricsPublisher = object : Runnable {
        override fun run() {
            lastFps = fps
            lastPeak = peakFps
            lastAvg = if (fpsSamples > 0) fpsSum / fpsSamples else 0.0
            lastMinRam = if (minRamMb == Int.MAX_VALUE) 0 else minRamMb
            if (isActive) main.postDelayed(this, 400)
        }
    }

    override fun doFrame(frameTimeNanos: Long) {
        frameCount++
        val now = System.currentTimeMillis()
        if (lastFpsTs == 0L) lastFpsTs = now
        val dt = now - lastFpsTs
        if (dt >= 500) {
            fps = frameCount * 1000.0 / dt
            if (fps > peakFps) peakFps = fps
            fpsSum += fps
            fpsSamples++
            frameCount = 0
            lastFpsTs = now
            updateText()
        }
        if (isActive) Choreographer.getInstance().postFrameCallback(this)
    }

    private fun updateText() {
        val ram = freeRamMb()
        if (ram in 1 until minRamMb) minRamMb = ram
        val target = if (targetFps > 0) targetFps else panelHz.toInt()
        val line =
            "$title\n${fps.toInt()} FPS · panel ${panelHz.toInt()}Hz · obj $target\nRAM libre ${ram}MB"
        main.post { tv?.text = line }
    }

    private fun freeRamMb(): Int {
        return try {
            val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            (mi.availMem / (1024 * 1024)).toInt()
        } catch (_: Exception) {
            0
        }
    }

    private fun showOverlay() {
        if (root != null) return
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        panelHz = try {
            if (Build.VERSION.SDK_INT >= 30) {
                wm?.defaultDisplay?.mode?.refreshRate?.toDouble() ?: 60.0
            } else {
                @Suppress("DEPRECATION")
                wm?.defaultDisplay?.refreshRate?.toDouble() ?: 60.0
            }
        } catch (_: Exception) {
            60.0
        }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xCC1A1A1A.toInt())
            setPadding(22, 16, 22, 16)
            elevation = 12f
        }
        tv = TextView(this).apply {
            setTextColor(0xFFFF6B35.toInt())
            textSize = 12f
            typeface = Typeface.MONOSPACE
            text = "HUD…"
        }
        layout.addView(tv)
        val type = if (Build.VERSION.SDK_INT >= 26)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 24
        params.y = 120
        var dragX = 0f
        var dragY = 0f
        layout.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    dragX = e.rawX - params.x
                    dragY = e.rawY - params.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = (e.rawX - dragX).toInt()
                    params.y = (e.rawY - dragY).toInt()
                    wm?.updateViewLayout(v, params)
                    true
                }
                else -> false
            }
        }
        root = layout
        try {
            wm?.addView(layout, params)
        } catch (_: Exception) {
            stopSelf()
        }
    }

    private fun buildNotif(): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CH_ID, "Game HUD", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val stop = PendingIntent.getService(
            this, 0,
            Intent(this, GameHudService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CH_ID)
            .setContentTitle("Modo Juegos activo")
            .setContentText("HUD sobre $title")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(stop)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        isActive = false
        Choreographer.getInstance().removeFrameCallback(this)
        try {
            root?.let { wm?.removeView(it) }
        } catch (_: Exception) {
        }
        root = null
        tv = null
        super.onDestroy()
    }

    companion object {
        private const val CH_ID = "hub_game_hud"
        private const val NOTIF_ID = 7711
        const val ACTION_STOP = "com.anything.hub.STOP_HUD"
        const val EXTRA_TITLE = "title"
        const val EXTRA_PKG = "pkg"
        const val EXTRA_TARGET = "targetFps"

        @Volatile var isActive: Boolean = false
        @Volatile private var lastPeak = 0.0
        @Volatile private var lastAvg = 0.0
        @Volatile private var lastMinRam = 0
        @Volatile private var lastFps = 0.0

        fun start(ctx: Context, pkg: String, title: String, targetFps: Int): Boolean {
            return try {
                val i = Intent(ctx, GameHudService::class.java)
                    .putExtra(EXTRA_PKG, pkg)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TARGET, targetFps)
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i)
                else ctx.startService(i)
                true
            } catch (_: Exception) {
                false
            }
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, GameHudService::class.java))
        }

        fun snapshot(): Map<String, Any?> = mapOf(
            "fps" to lastFps,
            "peakFps" to lastPeak,
            "avgFps" to lastAvg,
            "minRamMb" to lastMinRam,
            "active" to isActive,
        )
    }
}
