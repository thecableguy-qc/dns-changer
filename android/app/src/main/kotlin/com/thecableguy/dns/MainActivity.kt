package com.thecableguy.dns

import android.app.Activity
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
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDns1: String = ""
    private var pendingDns2: String = ""

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == VPN_REQUEST_CODE) {
            Log.i(TAG, "VPN permission result: requestCode=$requestCode, resultCode=$resultCode")
            if (resultCode == Activity.RESULT_OK) {
                Log.i(TAG, "VPN permission granted, starting VPN service")
                startVpnService(pendingDns1, pendingDns2, pendingResult)
            } else {
                Log.w(TAG, "VPN permission denied by user")
                pendingResult?.error("VPN_PERMISSION_DENIED", "VPN permission was denied by user", null)
            }
            // Clear pending data
            pendingResult = null
            pendingDns1 = ""
            pendingDns2 = ""
        }
    }

    private fun startVpnService(dns1: String, dns2: String, result: MethodChannel.Result?) {
        try {
            val serviceIntent = Intent(this, DnsVpnService::class.java)
            serviceIntent.putExtra("dns1", dns1)
            serviceIntent.putExtra("dns2", dns2)
            Log.i(TAG, "MainActivity: Created intent for DnsVpnService with DNS parameters - DNS1: $dns1, DNS2: $dns2")
            startService(serviceIntent)
            Log.i(TAG, "MainActivity: Started DnsVpnService successfully")
            result?.success(null)
            Log.i(TAG, "MainActivity: Returned success to Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "MainActivity: Error starting VPN service", e)
            result?.error("START_VPN_ERROR", "Failed to start VPN service: ${e.message}", null)
        }
    }

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
                        Log.i(TAG, "MainActivity: VPN permission required, requesting permission")
                        // Store the parameters and result for later use
                        pendingDns1 = dns1
                        pendingDns2 = dns2
                        pendingResult = result
                        // Launch the permission request
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        Log.i(TAG, "MainActivity: VPN permission already granted")
                        startVpnService(dns1, dns2, result)
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
