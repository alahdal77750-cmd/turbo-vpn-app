package com.turbo.vpn

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.turbo.vpn/native"
    private val TAG = "VPN_Native"

    // متغير لتخزين الإعدادات المطلوبة بعد الموافقة على صلاحية الـ VPN
    private var pendingVpnConfig: String? = null
    private var pendingServerId: String? = null

    // طلب صلاحية الـ VPN من المستخدم
    private val vpnPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            Log.d(TAG, "VPN Permission Granted")
            // إذا وافق المستخدم، نقوم بتشغيل الـ VPN بالإعدادات المخزنة
            pendingVpnConfig?.let { config ->
                startVpnService(config, pendingServerId)
            }
        } else {
            Log.d(TAG, "VPN Permission Denied")
            // إرسال رسالة لـ Flutter بأن المستخدم رفض الصلاحية
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL)
                .invokeMethod("vpnPermissionResult", false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    // تحضير Intent لطلب الصلاحية
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        // المستخدم لم يوافق بعد، نعرض له النافذة
                        vpnPermissionLauncher.launch(intent)
                    } else {
                        // المستخدم وافق مسبقاً
                        Log.d(TAG, "VPN Permission Already Granted")
                        result.success(true)
                    }
                }
                "startVpn" -> {
                    val config = call.argument<String>("config")
                    val serverId = call.argument<String>("serverId")
                    
                    if (config != null && serverId != null) {
                        // التحقق من الصلاحية مرة أخرى قبل البدء
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            // نحتاج للطلب مرة أخرى، نخزن الإعدادات مؤقتاً
                            pendingVpnConfig = config
                            pendingServerId = serverId
                            vpnPermissionLauncher.launch(intent)
                        } else {
                            // لدينا الصلاحية، ابدأ الخدمة
                            startVpnService(config, serverId)
                            result.success(true)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Config or ServerId is missing", null)
                    }
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVpnService(config: String, serverId: String?) {
        val intent = Intent(this, VpnConnectionService::class.java)
        intent.putExtra("config", config)
        intent.putExtra("serverId", serverId)
        
        // في أندرويد 8+ يجب استخدام startForegroundService للخدمات التي تعمل في الخلفية
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "VPN Service Started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN Service: ${e.message}")
        }
    }

    private fun stopVpnService() {
        val intent = Intent(this, VpnConnectionService::class.java)
        stopService(intent)
        Log.d(TAG, "VPN Service Stopped")
    }
}
