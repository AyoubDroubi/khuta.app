package io.github.ayoubdroubi.khuta

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.Executors

object AppUsageBridge {

    const val CHANNEL = "khuta/app_usage"

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(context: Context, channel: MethodChannel) {
        val appContext = context.applicationContext
        channel.setMethodCallHandler { call, result ->
            handle(appContext, call, result)
        }
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess(context))
            "openUsageAccessSettings" -> result.success(openUsageAccessSettings(context))
            "readToday" -> readToday(context, result)
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings(context: Context): Boolean = try {
        context.startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (_: Exception) {
        false
    }

    private fun readToday(context: Context, result: MethodChannel.Result) {
        if (!hasUsageAccess(context)) {
            result.error("usage_access_denied", "Usage Access is not enabled", null)
            return
        }

        executor.execute {
            try {
                val summary = queryToday(context)
                mainHandler.post { result.success(summary) }
            } catch (_: SecurityException) {
                mainHandler.post {
                    result.error("usage_access_denied", "Usage Access is not enabled", null)
                }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("usage_query_failed", "Could not read app usage", null)
                }
            }
        }
    }

    private fun queryToday(context: Context): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val localMidnight = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val launcherApps = launcherPackages(context.packageManager)
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as UsageStatsManager
        val durations = mutableMapOf<String, Long>()
        var totalForeground = 0L

        usageManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            localMidnight,
            now,
        ).orEmpty().forEach { usage ->
            val packageName = usage.packageName
            val duration = usage.totalTimeInForeground
            if (packageName != context.packageName && duration > 0L) {
                totalForeground += duration
                if (packageName in launcherApps) {
                    durations[packageName] = (durations[packageName] ?: 0L) + duration
                }
            }
        }

        val apps = durations.entries
            .sortedByDescending { it.value }
            .take(5)
            .mapNotNull { (packageName, duration) ->
                val launchable = launcherApps[packageName] ?: return@mapNotNull null
                val applicationInfo = launchable.activityInfo?.applicationInfo
                    ?: return@mapNotNull null
                val packageManager = context.packageManager
                val label = try {
                    packageManager.getApplicationLabel(applicationInfo).toString()
                } catch (_: Exception) {
                    packageName
                }
                val icon = try {
                    applicationIconPng(packageManager.getApplicationIcon(applicationInfo))
                } catch (_: Exception) {
                    null
                }
                mapOf<String, Any?>(
                    "packageName" to packageName,
                    "name" to label,
                    "durationMs" to duration,
                    "icon" to icon,
                )
            }

        return mapOf(
            "totalDurationMs" to totalForeground,
            "apps" to apps,
        )
    }

    private fun launcherPackages(
        packageManager: PackageManager,
    ): Map<String, android.content.pm.ResolveInfo> {
        val launcherIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0L),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        return resolved.mapNotNull { info ->
            val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
            packageName to info
        }.distinctBy { it.first }.toMap()
    }

    private fun applicationIconPng(drawable: Drawable): ByteArray? = try {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val originalBounds = Rect(drawable.bounds)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        drawable.setBounds(originalBounds)

        ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            bitmap.recycle()
            output.toByteArray()
        }
    } catch (_: Exception) {
        null
    }
}
