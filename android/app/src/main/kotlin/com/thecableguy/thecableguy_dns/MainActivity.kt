package com.thecableguy.thecableguy_dns

import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "vpn_channel"
    private val TAG = "MainActivity"
    private val VPN_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "MainActivity: Configuring Flutter engine and setting up VPN method channel")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.i(TAG, "MainActivity: Received method channel call: ${call.method}")

            when (call.method) {
                "startVpn" -> {
                    Log.i(TAG, "MainActivity: Processing startVpn request")

                    // Get DNS parameters from Flutter
                    val dns1 = call.argument<String>("dns1") ?: "8.8.8.8"
                    val dns2 = call.argument<String>("dns2") ?: "8.8.4.4"
                    Log.i(TAG, "MainActivity: Received DNS servers - DNS1: $dns1, DNS2: $dns2")

                    // Check VPN permission first
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        Log.w(TAG, "MainActivity: VPN permission not granted, requesting permission")
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                        result.error("VPN_PERMISSION_REQUIRED", "VPN permission required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val serviceIntent = Intent(this, DnsVpnService::class.java)
                        serviceIntent.putExtra("dns1", dns1)
                        serviceIntent.putExtra("dns2", dns2)
                        Log.i(TAG, "MainActivity: Created intent for DnsVpnService with DNS parameters")
                        startService(serviceIntent)
                        Log.i(TAG, "MainActivity: Started DnsVpnService successfully")
                        result.success(null)
                        Log.i(TAG, "MainActivity: Returned success to Flutter")
                    } catch (e: Exception) {
                        Log.e(TAG, "MainActivity: Error starting VPN service", e)
                        result.error("START_VPN_ERROR", "Failed to start VPN service: ${e.message}", null)
                    }
                }
                "stopVpn" -> {
                    Log.i(TAG, "MainActivity: Processing stopVpn request")
                    try {
                        val serviceIntent = Intent(this, DnsVpnService::class.java)
                        serviceIntent.putExtra("action", "STOP_VPN")
                        Log.i(TAG, "MainActivity: Created stop intent for DnsVpnService")
                        startService(serviceIntent) // Send stop action to service
                        Log.i(TAG, "MainActivity: Sent stop action to DnsVpnService")
                        result.success(null)
                        Log.i(TAG, "MainActivity: Returned success to Flutter")
                    } catch (e: Exception) {
                        Log.e(TAG, "MainActivity: Error stopping VPN service", e)
                        result.error("STOP_VPN_ERROR", "Failed to stop VPN service: ${e.message}", null)
                    }
                }
                else -> {
                    Log.w(TAG, "MainActivity: Unknown method called: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
}
