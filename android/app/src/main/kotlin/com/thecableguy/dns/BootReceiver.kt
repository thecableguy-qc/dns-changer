package com.thecableguy.dns

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.i(TAG, "BootReceiver: Received boot intent: ${intent?.action}")

        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent?.action == "android.intent.action.QUICKBOOT_POWERON") {

            Log.i(TAG, "BootReceiver: Boot completed, starting TheCableGuy DNS app")

            try {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }

                context?.startActivity(launchIntent)
                Log.i(TAG, "BootReceiver: Successfully launched app")
            } catch (e: Exception) {
                Log.e(TAG, "BootReceiver: Error launching app", e)
            }
        }
    }
}
