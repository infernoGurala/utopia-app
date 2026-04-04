package com.example.utopia_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "utopia_app/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallApk" -> {
                    result.success(canInstallApks())
                }

                "openInstallPermissionSettings" -> {
                    openUnknownAppsSettings()
                    result.success(null)
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("invalid_path", "APK path is missing.", null)
                        return@setMethodCallHandler
                    }
                    result.success(installApk(filePath))
                }

                "restartApp" -> {
                    restartApp()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun restartApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(intent)
        finish()
    }

    private fun canInstallApks(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun installApk(filePath: String): String {
        val apkFile = File(filePath)
        if (!apkFile.exists()) {
            return "file_missing"
        }

        if (!canInstallApks()) {
            openUnknownAppsSettings()
            return "permission_required"
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.updater.fileprovider",
            apkFile,
        )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        return try {
            startActivity(installIntent)
            "launched"
        } catch (_: ActivityNotFoundException) {
            "no_installer"
        } catch (_: Exception) {
            "failed"
        }
    }

    private fun openUnknownAppsSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
