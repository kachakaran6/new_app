package com.countsend.countsend

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.util.Locale

class FloatingOverlayService : Service() {

    companion object {
        const val TAG = "FloatingOverlayService"
        const val CHANNEL_ID = "countsend_overlay_channel"
        const val NOTIFICATION_ID = 2026
        const val PREFS_NAME = "countsend_native_prefs"
        const val PREF_SEND_X = "custom_send_x"
        const val PREF_SEND_Y = "custom_send_y"

        const val ACTION_START = "com.countsend.action.START"
        const val ACTION_PAUSE = "com.countsend.action.PAUSE"
        const val ACTION_RESUME = "com.countsend.action.RESUME"
        const val ACTION_STOP = "com.countsend.action.STOP"
        const val ACTION_TRIGGER_ONCE = "com.countsend.action.TRIGGER_ONCE"
        const val ACTION_TOGGLE_PIN = "com.countsend.action.TOGGLE_PIN"

        const val EXTRA_TARGET_TIME = "target_time"
        const val EXTRA_TEMPLATE = "template"
        const val EXTRA_FRIEND_NAME = "friend_name"
        const val EXTRA_EVENT_NAME = "event_name"
        const val EXTRA_INTERVAL_SEC = "interval_sec"
        const val EXTRA_AUTO_SEND = "auto_send"
        const val EXTRA_SAFE_MODE = "safe_mode"
        const val EXTRA_COMPLETE_MSG = "complete_msg"
        const val EXTRA_CUSTOM_SEND_X = "custom_send_x"
        const val EXTRA_CUSTOM_SEND_Y = "custom_send_y"

        var isRunning = false
            private set

        var onLogEvent: ((timestamp: Long, text: String, success: Boolean, status: String) -> Unit)? = null
    }

    private var windowManager: WindowManager? = null

    // Main Control Bubble
    private var overlayView: View? = null
    private var params: WindowManager.LayoutParams? = null

    // Draggable Crosshair Target Window
    private var crosshairView: View? = null
    private var crosshairParams: WindowManager.LayoutParams? = null
    private var isCrosshairVisible = false

    private val handler = Handler(Looper.getMainLooper())
    private var tickerRunnable: Runnable? = null

    // Configuration parameters
    private var targetTimeMillis: Long = 0
    private var template: String = "{days}d {hours}h {minutes}m {seconds}s to go!"
    private var friendName: String = "Friend"
    private var eventName: String = "Event"
    private var intervalSec: Int = 5
    private var autoSend: Boolean = true
    private var safeMode: Boolean = false
    private var completeMsg: String = "🎉 Time's up!"

    // User-calibrated Send button coordinates
    private var customSendX: Float = -1f
    private var customSendY: Float = -1f

    private var isPaused: Boolean = false

    // Overlay UI Views
    private var tvCountdownBadge: TextView? = null
    private var tvStatusBadge: TextView? = null
    private var expandedControlsLayout: LinearLayout? = null
    private var btnPlayPause: Button? = null
    private var btnPinTarget: Button? = null
    private var isExpanded: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        loadSavedSendCoordinates()
    }

    private fun loadSavedSendCoordinates() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        customSendX = prefs.getFloat(PREF_SEND_X, -1f)
        customSendY = prefs.getFloat(PREF_SEND_Y, -1f)
        if (customSendX > 0 && customSendY > 0) {
            Log.i(TAG, "Loaded saved send button coordinates: ($customSendX, $customSendY)")
        }
    }

    private fun saveSendCoordinates(x: Float, y: Float) {
        customSendX = x
        customSendY = y
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putFloat(PREF_SEND_X, x).putFloat(PREF_SEND_Y, y).apply()
        Log.i(TAG, "Saved custom send coordinates: ($x, $y)")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_START -> {
                targetTimeMillis = intent?.getLongExtra(EXTRA_TARGET_TIME, System.currentTimeMillis() + 60000)
                    ?: (System.currentTimeMillis() + 60000)
                template = intent?.getStringExtra(EXTRA_TEMPLATE) ?: template
                friendName = intent?.getStringExtra(EXTRA_FRIEND_NAME) ?: friendName
                eventName = intent?.getStringExtra(EXTRA_EVENT_NAME) ?: eventName
                intervalSec = intent?.getIntExtra(EXTRA_INTERVAL_SEC, 5) ?: 5
                autoSend = intent?.getBooleanExtra(EXTRA_AUTO_SEND, true) ?: true
                safeMode = intent?.getBooleanExtra(EXTRA_SAFE_MODE, false) ?: false
                completeMsg = intent?.getStringExtra(EXTRA_COMPLETE_MSG) ?: completeMsg

                val passedX = intent?.getFloatExtra(EXTRA_CUSTOM_SEND_X, -1f) ?: -1f
                val passedY = intent?.getFloatExtra(EXTRA_CUSTOM_SEND_Y, -1f) ?: -1f
                if (passedX > 0 && passedY > 0) {
                    saveSendCoordinates(passedX, passedY)
                }

                isRunning = true
                isPaused = false

                startForeground(NOTIFICATION_ID, buildNotification("Countdown initialized..."))
                setupOverlayView()
                startTicker()
            }
            ACTION_PAUSE -> {
                pauseTicker()
            }
            ACTION_RESUME -> {
                resumeTicker()
            }
            ACTION_STOP -> {
                stopSelf()
            }
            ACTION_TRIGGER_ONCE -> {
                performTick(manual = true)
            }
            ACTION_TOGGLE_PIN -> {
                toggleCrosshairTarget()
            }
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CountSend Active Countdown",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live ticker and controls for CountSend"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(contentText: String): Notification {
        val stopIntent = Intent(this, FloatingOverlayService::class.java).apply { action = ACTION_STOP }
        val stopPending = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val pauseResumeIntent = Intent(this, FloatingOverlayService::class.java).apply {
            action = if (isPaused) ACTION_RESUME else ACTION_PAUSE
        }
        val pauseResumePending = PendingIntent.getService(
            this, 2, pauseResumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPending = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CountSend Running ($eventName)")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentIntent(openAppPending)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause,
                if (isPaused) "Resume" else "Pause",
                pauseResumePending
            )
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPending)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(contentText))
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupOverlayView() {
        if (overlayView != null) return

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 200
        }

        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(12, 12, 12, 12)
        }

        // --- Collapsed Pill / Bubble ---
        // --- Collapsed Pill / Bubble ---
        val bubbleLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(20, 12, 20, 12)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24f
                setColor(Color.parseColor("#1A1A1A"))
                setStroke(2, Color.parseColor("#1A5F4C"))
            }
        }

        tvStatusBadge = TextView(this).apply {
            text = "● "
            setTextColor(Color.parseColor("#34D399"))
            textSize = 10f
        }
        bubbleLayout.addView(tvStatusBadge)

        tvCountdownBadge = TextView(this).apply {
            text = "Loading..."
            setTextColor(Color.parseColor("#EDEDED"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        bubbleLayout.addView(tvCountdownBadge)

        val btnToggleExpand = TextView(this).apply {
            text = "  •••"
            setTextColor(Color.parseColor("#9A9A9A"))
            textSize = 13f
            setOnClickListener {
                toggleExpand()
            }
        }
        bubbleLayout.addView(btnToggleExpand)

        rootLayout.addView(bubbleLayout)

        // --- Expanded Controls Card (Flat, 8px corners) ---
        expandedControlsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            setPadding(20, 16, 20, 16)
            val marginParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 12
            }
            layoutParams = marginParams
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 16f
                setColor(Color.parseColor("#181818"))
                setStroke(2, Color.parseColor("#2A2A2A"))
            }
        }

        val tvCardTitle = TextView(this).apply {
            text = "Tickr ($eventName)"
            setTextColor(Color.parseColor("#9A9A9A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        expandedControlsLayout?.addView(tvCardTitle)

        // First Action Row (Pause, Type Now, Pin Send)
        val actionsRow1 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val rowParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 12
            }
            layoutParams = rowParams
        }

        btnPlayPause = Button(this).apply {
            text = "Pause"
            textSize = 11f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                cornerRadius = 12f
                setColor(Color.parseColor("#1A5F4C"))
            }
            setOnClickListener {
                if (isPaused) resumeTicker() else pauseTicker()
            }
        }
        actionsRow1.addView(btnPlayPause)

        val btnTypeOnce = Button(this).apply {
            text = "Type"
            textSize = 11f
            setTextColor(Color.parseColor("#EDEDED"))
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                leftMargin = 8
            }
            layoutParams = btnParams
            background = GradientDrawable().apply {
                cornerRadius = 12f
                setColor(Color.parseColor("#262626"))
                setStroke(1, Color.parseColor("#383838"))
            }
            setOnClickListener {
                performTick(manual = true)
            }
        }
        actionsRow1.addView(btnTypeOnce)

        btnPinTarget = Button(this).apply {
            text = if (isCrosshairVisible) "Lock Pin" else "Pin Send"
            textSize = 11f
            setTextColor(Color.parseColor("#EDEDED"))
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                leftMargin = 8
            }
            layoutParams = btnParams
            background = GradientDrawable().apply {
                cornerRadius = 12f
                setColor(Color.parseColor("#262626"))
                setStroke(1, Color.parseColor("#383838"))
            }
            setOnClickListener {
                toggleCrosshairTarget()
            }
        }
        actionsRow1.addView(btnPinTarget)

        expandedControlsLayout?.addView(actionsRow1)

        // Second Action Row (Stop button)
        val actionsRow2 = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val rowParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 8
            }
            layoutParams = rowParams
        }

        val btnClose = Button(this).apply {
            text = "Stop"
            textSize = 11f
            setTextColor(Color.parseColor("#F87171"))
            background = GradientDrawable().apply {
                cornerRadius = 12f
                setColor(Color.parseColor("#262626"))
                setStroke(1, Color.parseColor("#383838"))
            }
            setOnClickListener {
                stopSelf()
            }
        }
        actionsRow2.addView(btnClose)

        expandedControlsLayout?.addView(actionsRow2)
        rootLayout.addView(expandedControlsLayout)

        // --- Dragging Interaction for Main Bubble ---
        bubbleLayout.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isClick = true

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                if (event == null || params == null) return false
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params!!.x
                        initialY = params!!.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isClick = true
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                            isClick = false
                        }
                        params!!.x = initialX + dx
                        params!!.y = initialY + dy
                        windowManager?.updateViewLayout(overlayView, params)
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (isClick) {
                            toggleExpand()
                        }
                        return true
                    }
                }
                return false
            }
        })

        overlayView = rootLayout
        windowManager?.addView(overlayView, params)
    }

    /**
     * Toggles the draggable Crosshair Bullseye Target.
     * The user can position this bullseye directly over the Send button on their screen.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun toggleCrosshairTarget() {
        val density = resources.displayMetrics.density
        val reticlePx = (84 * density).toInt()

        if (isCrosshairVisible) {
            // Hide and save
            if (crosshairView != null && crosshairParams != null) {
                val finalX = crosshairParams!!.x + (reticlePx / 2f)
                val finalY = crosshairParams!!.y + (reticlePx / 2f)
                saveSendCoordinates(finalX, finalY)
                try {
                    windowManager?.removeView(crosshairView)
                } catch (_: Exception) {}
                crosshairView = null
                isCrosshairVisible = false
                btnPinTarget?.text = "🎯 Pin Send"
                Toast.makeText(this, "Send Button Pin locked at (${finalX.toInt()}, ${finalY.toInt()})", Toast.LENGTH_SHORT).show()
            }
            return
        }

        // Show Draggable Crosshair Target
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val initialX = if (customSendX > 0) (customSendX - reticlePx / 2f).toInt() else (resources.displayMetrics.widthPixels - reticlePx - 20)
        val initialY = if (customSendY > 0) (customSendY - reticlePx / 2f).toInt() else (resources.displayMetrics.heightPixels - reticlePx - 100)

        crosshairParams = WindowManager.LayoutParams(
            reticlePx,
            reticlePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX
            y = initialY
        }

        val reticleView = object : View(this) {
            private val paintRing = Paint().apply {
                color = Color.parseColor("#10B981")
                style = Paint.Style.STROKE
                strokeWidth = 2.5f * density
                isAntiAlias = true
            }
            private val paintCross = Paint().apply {
                color = Color.parseColor("#34D399")
                strokeWidth = 1.5f * density
                isAntiAlias = true
            }
            private val paintCenterOuter = Paint().apply {
                color = Color.parseColor("#10B981")
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            private val paintCenterInner = Paint().apply {
                color = Color.WHITE
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            private val paintTextBg = Paint().apply {
                color = Color.parseColor("#DD1A1A1A")
                style = Paint.Style.FILL
                isAntiAlias = true
            }
            private val paintText = Paint().apply {
                color = Color.parseColor("#EDEDED")
                textSize = 9f * density
                isAntiAlias = true
                textAlign = Paint.Align.CENTER
                typeface = android.graphics.Typeface.MONOSPACE
            }

            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                val cx = width / 2f
                val cy = height / 2f
                val r = (width / 2f) - (8f * density)

                // 1. Outer target ring
                canvas.drawCircle(cx, cy, r, paintRing)

                // 2. Cardinal tick marks
                val tickLen = 5f * density
                canvas.drawLine(cx, cy - r - tickLen, cx, cy - r, paintRing)
                canvas.drawLine(cx, cy + r, cx, cy + r + tickLen, paintRing)
                canvas.drawLine(cx - r - tickLen, cy, cx - r, cy, paintRing)
                canvas.drawLine(cx + r, cy, cx + r + tickLen, cy, paintRing)

                // 3. Crosshairs with center gap
                val gap = 7f * density
                canvas.drawLine(cx - r + (4f * density), cy, cx - gap, cy, paintCross)
                canvas.drawLine(cx + gap, cy, cx + r - (4f * density), cy, paintCross)
                canvas.drawLine(cx, cy - r + (4f * density), cx, cy - gap, paintCross)
                canvas.drawLine(cx, cy + gap, cx, cy + r - (4f * density), paintCross)

                // 4. Center bullseye dot
                canvas.drawCircle(cx, cy, 4.5f * density, paintCenterOuter)
                canvas.drawCircle(cx, cy, 1.8f * density, paintCenterInner)

                // 5. Live coordinate badge inside top of ring
                val liveX = ((crosshairParams?.x ?: 0) + cx).toInt()
                val liveY = ((crosshairParams?.y ?: 0) + cy).toInt()
                val coordStr = "$liveX,$liveY"
                val textWidth = paintText.measureText(coordStr)
                val badgeRect = android.graphics.RectF(
                    cx - (textWidth / 2f) - (4f * density),
                    cy - (18f * density),
                    cx + (textWidth / 2f) + (4f * density),
                    cy - (7f * density)
                )
                canvas.drawRoundRect(badgeRect, 4f * density, 4f * density, paintTextBg)
                canvas.drawText(coordStr, cx, cy - (9f * density), paintText)
            }
        }

        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f

        reticleView.setOnTouchListener { _, event ->
            if (event == null || crosshairParams == null) return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = crosshairParams!!.x
                    startY = crosshairParams!!.y
                    touchX = event.rawX
                    touchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    crosshairParams!!.x = startX + dx
                    crosshairParams!!.y = startY + dy
                    windowManager?.updateViewLayout(crosshairView, crosshairParams)

                    val curX = crosshairParams!!.x + (reticlePx / 2f)
                    val curY = crosshairParams!!.y + (reticlePx / 2f)
                    saveSendCoordinates(curX, curY)
                    reticleView.invalidate()
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val finalX = crosshairParams!!.x + (reticlePx / 2f)
                    val finalY = crosshairParams!!.y + (reticlePx / 2f)
                    saveSendCoordinates(finalX, finalY)
                    vibrate()
                    Toast.makeText(this, "🎯 Pin centered at (${finalX.toInt()}, ${finalY.toInt()})", Toast.LENGTH_SHORT).show()
                    true
                }
                else -> false
            }
        }

        crosshairView = reticleView
        windowManager?.addView(crosshairView, crosshairParams)
        isCrosshairVisible = true
        btnPinTarget?.text = "✓ Lock Pin"
        Toast.makeText(this, "Drag the 🎯 target directly on top of your chat's Send button!", Toast.LENGTH_LONG).show()
    }

    private fun toggleExpand() {
        isExpanded = !isExpanded
        expandedControlsLayout?.visibility = if (isExpanded) View.VISIBLE else View.GONE
    }

    private fun startTicker() {
        tickerRunnable = object : Runnable {
            override fun run() {
                if (isRunning && !isPaused) {
                    performTick(manual = false)
                }
                if (isRunning) {
                    handler.postDelayed(this, (intervalSec * 1000L).coerceAtLeast(1000L))
                }
            }
        }
        handler.post(tickerRunnable!!)
    }

    private fun pauseTicker() {
        isPaused = true
        btnPlayPause?.text = "▶ Resume"
        tvStatusBadge?.text = "⏸ "
        updateNotification("Paused ($intervalSec s interval)")
    }

    private fun resumeTicker() {
        isPaused = false
        btnPlayPause?.text = "⏸ Pause"
        tvStatusBadge?.text = "⏳ "
        updateNotification("Resumed...")
    }

    private fun performTick(manual: Boolean) {
        if (isCrosshairVisible) {
            toggleCrosshairTarget()
        }

        val now = System.currentTimeMillis()
        val diffMillis = targetTimeMillis - now

        if (diffMillis <= 0) {
            handleCountdownComplete()
            return
        }

        val totalSeconds = diffMillis / 1000
        val days = totalSeconds / 86400
        val hours = (totalSeconds % 86400) / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60

        val formattedMessage = template
            .replace("{days}", days.toString())
            .replace("{hours}", String.format(Locale.getDefault(), "%02d", hours))
            .replace("{minutes}", String.format(Locale.getDefault(), "%02d", minutes))
            .replace("{seconds}", String.format(Locale.getDefault(), "%02d", seconds))
            .replace("{friend_name}", friendName)
            .replace("{event_name}", eventName)

        val compactCountdown = String.format(
            Locale.getDefault(),
            "%dd %02dh %02dm %02ds",
            days, hours, minutes, seconds
        )

        tvCountdownBadge?.text = compactCountdown
        updateNotification(formattedMessage)

        if (safeMode) {
            copyToClipboard(formattedMessage)
            val logMsg = "Copied to clipboard: $formattedMessage"
            Log.d(TAG, logMsg)
            onLogEvent?.invoke(now, formattedMessage, true, "Safe Mode (Copied)")
        } else {
            val service = CountdownAccessibilityService.instance
            if (service == null) {
                val errorMsg = "Accessibility service disabled"
                Log.w(TAG, errorMsg)
                onLogEvent?.invoke(now, formattedMessage, false, errorMsg)
                if (manual) {
                    Toast.makeText(this, "Enable CountSend in Accessibility Settings", Toast.LENGTH_SHORT).show()
                }
            } else {
                val tapX = if (customSendX > 0) customSendX else null
                val tapY = if (customSendY > 0) customSendY else null

                service.typeAndSend(formattedMessage, autoSend, tapX, tapY) { success, statusText ->
                    onLogEvent?.invoke(now, formattedMessage, success, statusText)
                }
            }
        }
    }

    private fun handleCountdownComplete() {
        Log.i(TAG, "Countdown completed! Sending complete message: $completeMsg")
        tvCountdownBadge?.text = "🎉 00:00:00 (Complete)"
        tvStatusBadge?.text = "🏆 "
        updateNotification("Countdown Complete: $completeMsg")

        vibrate()

        if (safeMode) {
            copyToClipboard(completeMsg)
            onLogEvent?.invoke(System.currentTimeMillis(), completeMsg, true, "Complete (Copied)")
        } else {
            val service = CountdownAccessibilityService.instance
            val tapX = if (customSendX > 0) customSendX else null
            val tapY = if (customSendY > 0) customSendY else null
            service?.typeAndSend(completeMsg, autoSend, tapX, tapY) { success, statusText ->
                onLogEvent?.invoke(System.currentTimeMillis(), completeMsg, success, "Complete: $statusText")
            }
        }

        isRunning = false
        tickerRunnable?.let { handler.removeCallbacks(it) }
    }

    private fun copyToClipboard(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("CountSend", text)
        clipboard.setPrimaryClip(clip)
    }

    private fun vibrate() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 300, 200, 500), -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 300, 200, 500), -1)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vibration failed", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        tickerRunnable?.let { handler.removeCallbacks(it) }

        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {}
            overlayView = null
        }

        if (crosshairView != null) {
            try {
                windowManager?.removeView(crosshairView)
            } catch (_: Exception) {}
            crosshairView = null
        }

        Log.i(TAG, "FloatingOverlayService destroyed")
    }
}
