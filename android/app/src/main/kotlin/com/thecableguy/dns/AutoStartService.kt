package com.thecableguy.dns

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Context
import androidx.core.app.NotificationCompat
import android.widget.Toast

class AutoStartService : Service() {
    private val TAG = "AutoStartService"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "auto_start_channel"

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "AutoStartService: Service started for auto-launch")

        // Create notification channel first
        createNotificationChannel()

        // Start as foreground service immediately to ensure visibility
        try {
            val foregroundNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🔒 DNS VPN Starting...")
                .setContentText("Preparing VPN auto-start...")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOngoing(true)
                .build()

            startForeground(NOTIFICATION_ID, foregroundNotification)
            Log.i(TAG, "AutoStartService: Started as foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "AutoStartService: Error starting foreground service", e)
        }

        // Try direct launch first (will likely be blocked)
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            try {
                Log.i(TAG, "AutoStartService: Attempting direct launch first")

                if (attemptDirectLaunch()) {
                    Log.i(TAG, "AutoStartService: Direct launch succeeded, stopping service")
                    stopSelf()
                } else {
                    Log.i(TAG, "AutoStartService: Direct launch blocked, showing persistent notification and trying alternative approaches")
                    showPersistentNotification()

                    // For TV devices, also try alternative visibility methods
                    tryAlternativeVisibilityMethods()
                    // Keep service running to maintain notification
                }

            } catch (e: Exception) {
                Log.e(TAG, "AutoStartService: Error in launch attempt", e)
                showPersistentNotification()
                tryAlternativeVisibilityMethods()
            }
        }, 1000L) // Short delay for system to settle

        return START_STICKY // Keep service alive to maintain notification
    }

    private fun attemptDirectLaunch(): Boolean {
        return try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("auto_start_boot", true)
                putExtra("launched_via_notification", false)
            }
            startActivity(launchIntent)
            Log.i(TAG, "AutoStartService: Direct activity launch attempted")

            // Always return false because we know BAL will likely block it
            // We'll let the notification approach handle the launch
            false
        } catch (e: Exception) {
            Log.e(TAG, "AutoStartService: Direct launch failed", e)
            false
        }
    }

    private fun showPersistentNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Create intent for when user taps notification
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("auto_start_boot", true)
                putExtra("launched_via_notification", true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Create action for dismissing notification
            val dismissIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                action = "DISMISS_NOTIFICATION"
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                this,
                1,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // For TV devices, try a full-screen intent approach for better visibility
            val fullScreenIntent = PendingIntent.getActivity(
                this,
                2,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🔒 DNS VPN Auto-Start Ready")
                .setContentText("Tap to activate VPN protection now!")
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_MAX) // Changed to MAX for visibility
                .setCategory(NotificationCompat.CATEGORY_SYSTEM)
                .setAutoCancel(false) // Don't auto-dismiss
                .setOngoing(true) // Make it persistent
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())
                .setUsesChronometer(false)
                .setFullScreenIntent(fullScreenIntent, true) // Full screen for TV visibility
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("🔒 Your DNS VPN is ready to start! Tap this notification to activate automatic VPN protection with your saved DNS settings. This will secure your internet connection."))
                .addAction(android.R.drawable.ic_delete, "Dismiss", dismissPendingIntent)
                .addAction(android.R.drawable.ic_media_play, "Start VPN", pendingIntent)
                .build()

            // Try to make it heads-up notification for better visibility
            notification.flags = notification.flags or android.app.Notification.FLAG_INSISTENT

            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.i(TAG, "AutoStartService: Persistent auto-start notification created with MAX priority and full-screen intent")

            // Also try to create a simplified notification for TV compatibility
            try {
                val tvNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("VPN Ready - Tap to Start")
                    .setContentText("DNS VPN Auto-Start Available")
                    .setContentIntent(pendingIntent)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setDefaults(NotificationCompat.DEFAULT_ALL)
                    .setAutoCancel(true)
                    .setTimeoutAfter(30000) // Show for 30 seconds
                    .setFullScreenIntent(fullScreenIntent, false)
                    .build()

                notificationManager.notify(NOTIFICATION_ID + 1, tvNotification)
                Log.i(TAG, "AutoStartService: Additional TV-compatible notification created")

                // Try to trigger a heads-up display manually after a short delay
                val headsUpHandler = Handler(Looper.getMainLooper())
                headsUpHandler.postDelayed({
                    try {
                        val headsUpNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                            .setSmallIcon(android.R.drawable.ic_dialog_email)
                            .setContentTitle("🔔 VPN Auto-Start")
                            .setContentText("Ready to connect - tap here")
                            .setContentIntent(pendingIntent)
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE)
                            .setAutoCancel(true)
                            .setTimeoutAfter(15000)
                            .build()

                        notificationManager.notify(NOTIFICATION_ID + 2, headsUpNotification)
                        Log.i(TAG, "AutoStartService: Delayed heads-up notification sent")
                    } catch (e: Exception) {
                        Log.e(TAG, "AutoStartService: Error creating delayed heads-up notification", e)
                    }
                }, 2000L)

            } catch (e: Exception) {
                Log.e(TAG, "AutoStartService: Error creating TV-compatible notification", e)
            }

            // Set timeout to automatically dismiss notification after 2 minutes if not used
            val timeoutHandler = Handler(Looper.getMainLooper())
            timeoutHandler.postDelayed({
                try {
                    notificationManager.cancel(NOTIFICATION_ID)
                    notificationManager.cancel(NOTIFICATION_ID + 1)
                    notificationManager.cancel(NOTIFICATION_ID + 2)
                    Log.i(TAG, "AutoStartService: Auto-dismissed all notifications after timeout")
                    stopSelf()
                } catch (e: Exception) {
                    Log.e(TAG, "AutoStartService: Error dismissing notifications", e)
                }
            }, 120000L) // 2 minutes timeout

        } catch (e: Exception) {
            Log.e(TAG, "AutoStartService: Error creating persistent notification", e)
            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "DNS VPN Auto-Start",
            NotificationManager.IMPORTANCE_MAX  // Changed to MAX for better visibility
        ).apply {
            description = "Notifications for VPN auto-start functionality"
            enableLights(true)
            enableVibration(true)
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
        Log.i(TAG, "AutoStartService: Created notification channel with MAX importance")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "AutoStartService: Service destroyed")
    }

    private fun tryAlternativeVisibilityMethods() {
        try {
            Log.i(TAG, "AutoStartService: Trying alternative visibility methods for TV")

            // Method 1: Show system toast messages that are more visible on TV
            val toastHandler = Handler(Looper.getMainLooper())
            toastHandler.postDelayed({
                try {
                    Toast.makeText(
                        this,
                        "🔒 DNS VPN Auto-Start Ready - Open DNS VPN app to connect",
                        Toast.LENGTH_LONG
                    ).show()
                    Log.i(TAG, "AutoStartService: Toast notification shown")
                } catch (e: Exception) {
                    Log.e(TAG, "AutoStartService: Error showing toast", e)
                }
            }, 2000L)

            // Method 2: Try creating an activity overlay that's visible on TV
            val overlayHandler = Handler(Looper.getMainLooper())
            overlayHandler.postDelayed({
                try {
                    // Instead of notification, launch a minimal activity that shows the message
                    val overlayIntent = Intent(this, AutoStartOverlayActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                        putExtra("message", "DNS VPN Auto-Start is ready!")
                        putExtra("auto_start_boot", true)
                    }
                    startActivity(overlayIntent)
                    Log.i(TAG, "AutoStartService: Overlay activity launched")
                } catch (e: Exception) {
                    Log.e(TAG, "AutoStartService: Error launching overlay activity", e)
                    // Fallback: Show more prominent toasts
                    showFallbackToasts()
                }
            }, 5000L)

        } catch (e: Exception) {
            Log.e(TAG, "AutoStartService: Error in alternative visibility methods", e)
            showFallbackToasts()
        }
    }

    private fun showFallbackToasts() {
        try {
            val toastHandler = Handler(Looper.getMainLooper())

            // Show a series of informative toasts that guide the user on TV
            val toastMessages = listOf(
                "🔒 DNS VPN Auto-Start Ready!",
                "📱 Go to Apps → DNS VPN → Open",
                "⚡ VPN will start automatically when opened",
                "💡 Check notification panel or open DNS VPN app"
            )

            toastMessages.forEachIndexed { index, message ->
                toastHandler.postDelayed({
                    try {
                        val toast = Toast.makeText(this, message, Toast.LENGTH_LONG)
                        toast.show()
                        Log.i(TAG, "AutoStartService: Enhanced toast $index shown: $message")
                    } catch (e: Exception) {
                        Log.e(TAG, "AutoStartService: Error showing enhanced toast $index", e)
                    }
                }, (index * 4000L) + 1000L) // Stagger toasts every 4 seconds for readability
            }

            // Show a final summary toast after all individual toasts
            toastHandler.postDelayed({
                try {
                    val summaryToast = Toast.makeText(
                        this,
                        "🔒 DNS VPN: Ready for auto-start! Open the app when convenient.",
                        Toast.LENGTH_LONG
                    )
                    summaryToast.show()
                    Log.i(TAG, "AutoStartService: Final summary toast shown")
                } catch (e: Exception) {
                    Log.e(TAG, "AutoStartService: Error showing summary toast", e)
                }
            }, 18000L) // Show after all other toasts

        } catch (e: Exception) {
            Log.e(TAG, "AutoStartService: Error showing fallback toasts", e)
        }
    }
}
