package com.turbo.vpn

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

class VpnConnectionService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private val TAG = "VpnConnectionService"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = intent?.getStringExtra("config")
        
        try {
            val builder = Builder()
            builder.addAddress("10.0.0.2", 24)
            builder.addRoute("0.0.0.0", 0)
            builder.setSession("TurboVPN")

            vpnInterface = builder.establish()
            Log.d(TAG, "VPN Interface established successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN interface: ${e.message}")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            vpnInterface?.close()
            vpnInterface = null
            Log.d(TAG, "VPN Interface closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface: ${e.message}")
        }
    }
}
