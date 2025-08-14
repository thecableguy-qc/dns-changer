package com.thecableguy.dns

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Color

class AutoStartOverlayActivity : Activity() {
    private val TAG = "AutoStartOverlayActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "AutoStartOverlayActivity: Created")

        try {
            // Create a simple, visible UI for TV
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.argb(220, 0, 0, 0)) // Semi-transparent black
                setPadding(100, 100, 100, 100)
                gravity = android.view.Gravity.CENTER
            }

            val titleText = TextView(this).apply {
                text = "🔒 DNS VPN Auto-Start Ready"
                textSize = 28f
                setTextColor(Color.WHITE)
                gravity = android.view.Gravity.CENTER
                setPadding(20, 20, 20, 20)
            }

            val messageText = TextView(this).apply {
                text = "Your DNS VPN is ready to start automatically.\nTap the button below to activate VPN protection."
                textSize = 18f
                setTextColor(Color.LTGRAY)
                gravity = android.view.Gravity.CENTER
                setPadding(20, 20, 20, 40)
            }

            val startButton = Button(this).apply {
                text = "▶ Start VPN Now"
                textSize = 20f
                setPadding(40, 20, 40, 20)
                setBackgroundColor(Color.argb(255, 0, 150, 0)) // Green background
                setTextColor(Color.WHITE)
                setOnClickListener {
                    Log.i(TAG, "AutoStartOverlayActivity: Start VPN button clicked")
                    launchMainApp()
                }
            }

            val dismissButton = Button(this).apply {
                text = "✕ Dismiss"
                textSize = 16f
                setPadding(30, 15, 30, 15)
                setBackgroundColor(Color.argb(255, 150, 0, 0)) // Red background
                setTextColor(Color.WHITE)
                setOnClickListener {
                    Log.i(TAG, "AutoStartOverlayActivity: Dismiss button clicked")
                    finish()
                }
            }

            // Add views to layout
            layout.addView(titleText)
            layout.addView(messageText)
            layout.addView(startButton)
            layout.addView(dismissButton)

            setContentView(layout)

            // Auto-dismiss after 30 seconds
            Handler(Looper.getMainLooper()).postDelayed({
                if (!isFinishing) {
                    Log.i(TAG, "AutoStartOverlayActivity: Auto-dismissing after timeout")
                    finish()
                }
            }, 30000L)

        } catch (e: Exception) {
            Log.e(TAG, "AutoStartOverlayActivity: Error creating UI", e)
            finish()
        }
    }

    private fun launchMainApp() {
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("auto_start_boot", true)
                putExtra("launched_via_overlay", true)
            }

            startActivity(launchIntent)
            Log.i(TAG, "AutoStartOverlayActivity: Launched main app")
            finish() // Close overlay

        } catch (e: Exception) {
            Log.e(TAG, "AutoStartOverlayActivity: Error launching main app", e)
        }
    }

    override fun onBackPressed() {
        super.onBackPressed()
        Log.i(TAG, "AutoStartOverlayActivity: Back button pressed")
    }
}
