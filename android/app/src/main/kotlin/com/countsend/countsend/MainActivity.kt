package com.countsend.countsend

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.countsend/bridge"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityGranted" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "isOverlayGranted" -> {
                    result.success(isOverlayPermissionGranted())
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "isNotificationGranted" -> {
                    result.success(isNotificationPermissionGranted())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "isOverlayRunning" -> {
                    result.success(FloatingOverlayService.isRunning)
                }
                "startOverlay" -> {
                    val targetTime = (call.argument<Number>("targetTime"))?.toLong() ?: (System.currentTimeMillis() + 60000)
                    val template = call.argument<String>("template") ?: "{days}d {hours}h {minutes}m {seconds}s"
                    val friendName = call.argument<String>("friendName") ?: "Friend"
                    val eventName = call.argument<String>("eventName") ?: "Event"
                    val intervalSec = call.argument<Int>("intervalSec") ?: 5
                    val autoSend = call.argument<Boolean>("autoSend") ?: true
                    val safeMode = call.argument<Boolean>("safeMode") ?: false
                    val completeMsg = call.argument<String>("completeMsg") ?: "🎉 Time's up!"

                    startFloatingService(
                        targetTime,
                        template,
                        friendName,
                        eventName,
                        intervalSec,
                        autoSend,
                        safeMode,
                        completeMsg
                    )
                    result.success(true)
                }
                "stopOverlay" -> {
                    stopFloatingService()
                    result.success(true)
                }
                "sendTestMessage" -> {
                    val text = call.argument<String>("text") ?: "Test countdown 10s"
                    val autoSend = call.argument<Boolean>("autoSend") ?: false

                    val prefs = getSharedPreferences(FloatingOverlayService.PREFS_NAME, Context.MODE_PRIVATE)
                    val customX = prefs.getFloat(FloatingOverlayService.PREF_SEND_X, -1f)
                    val customY = prefs.getFloat(FloatingOverlayService.PREF_SEND_Y, -1f)

                    val service = CountdownAccessibilityService.instance
                    if (service == null) {
                        result.error("UNAVAILABLE", "Accessibility Service is not enabled", null)
                    } else {
                        val tapX = if (customX > 0) customX else null
                        val tapY = if (customY > 0) customY else null
                        service.typeAndSend(text, autoSend, tapX, tapY) { success, statusText ->
                            runOnUiThread {
                                result.success(mapOf("success" to success, "message" to statusText))
                            }
                        }
                    }
                }
                "getSavedSendTarget" -> {
                    val prefs = getSharedPreferences(FloatingOverlayService.PREFS_NAME, Context.MODE_PRIVATE)
                    val x = prefs.getFloat(FloatingOverlayService.PREF_SEND_X, -1f)
                    val y = prefs.getFloat(FloatingOverlayService.PREF_SEND_Y, -1f)
                    result.success(mapOf("x" to x.toDouble(), "y" to y.toDouble()))
                }
                "setSavedSendTarget" -> {
                    val x = (call.argument<Number>("x"))?.toFloat() ?: -1f
                    val y = (call.argument<Number>("y"))?.toFloat() ?: -1f
                    val prefs = getSharedPreferences(FloatingOverlayService.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putFloat(FloatingOverlayService.PREF_SEND_X, x)
                        .putFloat(FloatingOverlayService.PREF_SEND_Y, y)
                        .apply()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Attach listener for real-time logs from FloatingOverlayService back to Flutter
        FloatingOverlayService.onLogEvent = { timestamp, text, success, status ->
            runOnUiThread {
                methodChannel?.invokeMethod(
                    "onLogEvent",
                    mapOf(
                        "timestamp" to timestamp,
                        "text" to text,
                        "success" to success,
                        "status" to status
                    )
                )
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        if (CountdownAccessibilityService.isRunning()) return true

        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return false
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val expectedServiceName = "${packageName}/${CountdownAccessibilityService::class.java.canonicalName}"
        return enabledServices.contains(packageName) || enabledServices.contains(expectedServiceName)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                101
            )
        }
    }

    private fun startFloatingService(
        targetTime: Long,
        template: String,
        friendName: String,
        eventName: String,
        intervalSec: Int,
        autoSend: Boolean,
        safeMode: Boolean,
        completeMsg: String
    ) {
        val intent = Intent(this, FloatingOverlayService::class.java).apply {
            action = FloatingOverlayService.ACTION_START
            putExtra(FloatingOverlayService.EXTRA_TARGET_TIME, targetTime)
            putExtra(FloatingOverlayService.EXTRA_TEMPLATE, template)
            putExtra(FloatingOverlayService.EXTRA_FRIEND_NAME, friendName)
            putExtra(FloatingOverlayService.EXTRA_EVENT_NAME, eventName)
            putExtra(FloatingOverlayService.EXTRA_INTERVAL_SEC, intervalSec)
            putExtra(FloatingOverlayService.EXTRA_AUTO_SEND, autoSend)
            putExtra(FloatingOverlayService.EXTRA_SAFE_MODE, safeMode)
            putExtra(FloatingOverlayService.EXTRA_COMPLETE_MSG, completeMsg)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopFloatingService() {
        val intent = Intent(this, FloatingOverlayService::class.java).apply {
            action = FloatingOverlayService.ACTION_STOP
        }
        startService(intent)
    }
}
