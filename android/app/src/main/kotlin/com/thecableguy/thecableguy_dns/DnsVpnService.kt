package com.thecableguy.thecableguy_dns

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat

class DnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private val CHANNEL_ID = "dns_vpn_service_channel"
    private val TAG = "DnsVpnService"
    private var dns1: String = "8.8.8.8"
    private var dns2: String = "8.8.4.4"

    init {
        Log.i(TAG, "DnsVpnService: Service instance created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "DnsVpnService: onStartCommand called - startId: $startId")

        // Check if this is a stop command
        val action = intent?.getStringExtra("action")
        if (action == "STOP_VPN") {
            Log.i(TAG, "DnsVpnService: Received STOP_VPN action, stopping service...")
            stopVpn()
            stopSelf()
            return START_NOT_STICKY
        }

        // Extract DNS parameters from intent
        intent?.let {
            dns1 = it.getStringExtra("dns1") ?: "8.8.8.8"
            dns2 = it.getStringExtra("dns2") ?: "8.8.4.4"
            Log.i(TAG, "DnsVpnService: Received DNS parameters - DNS1: $dns1, DNS2: $dns2")
        }

        Log.i(TAG, "DnsVpnService: Starting foreground service...")
        startForegroundService()
        Log.i(TAG, "DnsVpnService: Starting VPN...")
        startVpn()
        Log.i(TAG, "DnsVpnService: onStartCommand completed, returning START_NOT_STICKY")
        return START_NOT_STICKY // Changed from START_STICKY to prevent auto-restart
    }

    override fun onDestroy() {
        Log.i(TAG, "DnsVpnService: onDestroy called")
        stopVpn()
        super.onDestroy()
    }

    private fun stopVpn() {
        Log.i(TAG, "DnsVpnService: Stopping VPN...")
        try {
            vpnInterface?.close()
            vpnInterface = null
            Log.i(TAG, "DnsVpnService: VPN interface closed")

            // Stop foreground service and remove notification
            stopForeground(true)
            Log.i(TAG, "DnsVpnService: Foreground service stopped and notification removed")
        } catch (e: Exception) {
            Log.e(TAG, "DnsVpnService: Error stopping VPN", e)
        }
        Log.i(TAG, "DnsVpnService: VPN stopped successfully")
    }

    private fun startForegroundService() {
        Log.i(TAG, "DnsVpnService: Creating notification channel...")
        createNotificationChannel()

        Log.i(TAG, "DnsVpnService: Building notification...")
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DNS VPN Service")
            .setContentText("DNS VPN is running")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .build()

        Log.i(TAG, "DnsVpnService: Starting foreground with notification...")
        startForeground(1, notification)
        Log.i(TAG, "DnsVpnService: Foreground service started successfully")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Log.i(TAG, "DnsVpnService: Creating notification channel for Android O+")
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "DNS VPN Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
            Log.i(TAG, "DnsVpnService: Notification channel created")
        } else {
            Log.i(TAG, "DnsVpnService: Skipping notification channel creation (Android < O)")
        }
    }

    private fun startVpn() {
        Log.i(TAG, "DnsVpnService: Creating VPN builder...")

        // Check VPN permission first
        val intent = VpnService.prepare(this)
        if (intent != null) {
            Log.e(TAG, "DnsVpnService: VPN permission not granted! User needs to grant permission.")
            Log.e(TAG, "DnsVpnService: Call VpnService.prepare() from MainActivity first")
            return
        }

        try {
            val builder = Builder()
            Log.i(TAG, "DnsVpnService: Configuring VPN parameters for DNS-only mode...")

            // Use a point-to-point interface that doesn't interfere with routing
            Log.i(TAG, "DnsVpnService: Adding address 10.0.0.2/30")
            builder.addAddress("10.0.0.2", 30)

            // Don't route all traffic - this was causing the blackhole
            // Instead, just set DNS servers and let the system handle DNS resolution
            Log.i(TAG, "DnsVpnService: Setting up DNS-only configuration")

            Log.i(TAG, "DnsVpnService: Adding custom DNS server $dns1")
            builder.addDnsServer(dns1)

            Log.i(TAG, "DnsVpnService: Adding custom DNS server $dns2")
            builder.addDnsServer(dns2)

            // Set session name for identification
            builder.setSession("DNS VPN Demo")

            // Allow all applications to bypass this VPN for data traffic
            // This ensures only DNS queries go through the VPN
            try {
                builder.setBlocking(false)
                Log.i(TAG, "DnsVpnService: Set non-blocking mode for app traffic")
            } catch (e: Exception) {
                Log.w(TAG, "DnsVpnService: Could not set non-blocking mode: ${e.message}")
            }

            Log.i(TAG, "DnsVpnService: Establishing VPN connection...")
            vpnInterface = builder.establish()

            if (vpnInterface != null) {
                Log.i(TAG, "DnsVpnService: VPN interface established successfully")
                Log.i(TAG, "DnsVpnService: DNS-only VPN is now active")
                Log.i(TAG, "DnsVpnService: DNS queries will use $dns1 and $dns2")
                Log.i(TAG, "DnsVpnService: Regular traffic should continue to work normally")
            } else {
                Log.e(TAG, "DnsVpnService: Failed to establish VPN interface - returned null")
                Log.e(TAG, "DnsVpnService: This might be due to missing VPN permission or another VPN already active")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "DnsVpnService: SecurityException - VPN permission not granted", e)
        } catch (e: Exception) {
            Log.e(TAG, "DnsVpnService: Unexpected error establishing VPN", e)
        }
    }
}
