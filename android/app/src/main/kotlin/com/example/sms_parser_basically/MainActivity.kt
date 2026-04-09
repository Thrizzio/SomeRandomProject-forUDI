package com.example.sms_parser_basically

import android.Manifest
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var liveSmsReceiver: BroadcastReceiver? = null
    private var liveSmsSink: EventChannel.EventSink? = null

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 1107
        private const val DEVICE_SETTINGS_CHANNEL = "sms_parser_basically/device_settings"
        private const val LIVE_SMS_CHANNEL = "sms_parser_basically/live_sms"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_SETTINGS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMiuiDevice" -> result.success(isMiuiDevice())
                "openBackgroundSettings" -> result.success(openBackgroundSettings())
                "requestSmsPermissions" -> requestSmsPermissions(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIVE_SMS_CHANNEL
        ).setStreamHandler(this)
    }

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS
        )

        val missingPermissions = permissions.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isEmpty()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "PERMISSION_IN_PROGRESS",
                "An SMS permission request is already in progress.",
                null
            )
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            missingPermissions.toTypedArray(),
            SMS_PERMISSION_REQUEST_CODE
        )
    }

    private fun isMiuiDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        return manufacturer.contains("xiaomi") ||
            brand.contains("xiaomi") ||
            brand.contains("redmi") ||
            brand.contains("poco")
    }

    private fun openBackgroundSettings(): Boolean {
        val intents = mutableListOf<Intent>()

        if (isMiuiDevice()) {
            intents += Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            }
            intents += Intent("miui.intent.action.OP_AUTO_START").apply {
                setPackage("com.miui.securitycenter")
            }
        }

        intents += Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        intents += Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }

        intents.forEach { intent ->
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }

        return false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        liveSmsSink = events
        registerLiveSmsReceiver()
    }

    override fun onCancel(arguments: Any?) {
        liveSmsSink = null
        unregisterLiveSmsReceiver()
    }

    private fun registerLiveSmsReceiver() {
        if (liveSmsReceiver != null) {
            return
        }

        liveSmsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    return
                }

                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    liveSmsSink?.success(
                        mapOf(
                            "id" to 0,
                            "address" to (sms.originatingAddress ?: ""),
                            "body" to (sms.messageBody ?: ""),
                            "date" to sms.timestampMillis,
                            "type" to "inbox"
                        )
                    )
                }
            }
        }

        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(liveSmsReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(liveSmsReceiver, filter)
        }
    }

    private fun unregisterLiveSmsReceiver() {
        val receiver = liveSmsReceiver ?: return

        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }

        liveSmsReceiver = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != SMS_PERMISSION_REQUEST_CODE) {
            return
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    override fun onDestroy() {
        unregisterLiveSmsReceiver()
        super.onDestroy()
    }
}
