package cn.shiguang.shiguang_radio

import com.ryanheise.audioservice.AudioServiceActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 使用插件提供的共享 FlutterEngine，让后台媒体服务与前台页面共用播放状态。
class MainActivity : AudioServiceActivity() {
    private fun themeFor(skin: String) = when (skin) {
        "midnight" -> R.style.LaunchBlue
        "forest" -> R.style.LaunchGreen
        else -> R.style.LaunchCoral
    }

    private fun backgroundFor(skin: String) = when (skin) {
        "midnight" -> R.color.radio_launch_blue
        "forest" -> R.color.radio_launch_green
        else -> R.color.radio_launch_background
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val preferences = getSharedPreferences("radio_launch", MODE_PRIVATE)
        val skin = preferences.getString("skin", null)
            ?: getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .getString("flutter.skin", "walnut") ?: "walnut"
        setTheme(themeFor(skin))
        super.onCreate(savedInstanceState)
        applyStartupSkin(skin)
    }

    private fun applyStartupSkin(skin: String) {
        // 与 Flutter 插件的缓存分开保存，避免不同 SharedPreferences 实例相互覆盖。
        getSharedPreferences("radio_launch", MODE_PRIVATE).edit().putString("skin", skin).commit()
        window.setBackgroundDrawableResource(backgroundFor(skin))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // 系统持久化稳定的主题名，下一次冷启动甚至在 Activity 创建前就能用上。
            splashScreen.setSplashScreenTheme(themeFor(skin))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.shiguang.radio/appearance")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSkin") {
                    result.notImplemented()
                } else if (call.arguments !in listOf("walnut", "midnight", "forest")) {
                    result.error("invalid_skin", "Unknown skin", null)
                } else {
                    applyStartupSkin(call.arguments as String)
                    result.success(null)
                }
            }
    }

    // 使用 Android 原生 Insets API；新 Android 的 Flutter edge-to-edge 默认行为
    // 不等同于隐藏系统栏。边缘滑动仍可临时呼出系统导航。
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.post {
            WindowCompat.getInsetsController(window, window.decorView).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
        }
    }
}
