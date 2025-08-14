package com.thecableguy.dns

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.util.Log

class NotificationActionReceiver : BroadcastReceiver() {
    private val TAG = "NotificationActionReceiver"
    private val NOTIFICATION_ID = 1001

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.i(TAG, "NotificationActionReceiver: Received action: ${intent?.action}")

        when (intent?.action) {
            "DISMISS_NOTIFICATION" -> {
                try {
                    val notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    notificationManager?.cancel(NOTIFICATION_ID)
                    Log.i(TAG, "NotificationActionReceiver: Dismissed auto-start notification")

                    // Stop the AutoStartService as well
                    val serviceIntent = Intent(context, AutoStartService::class.java)
                    context?.stopService(serviceIntent)

                } catch (e: Exception) {
                    Log.e(TAG, "NotificationActionReceiver: Error dismissing notification", e)
                }
            }
        }
    }
}
