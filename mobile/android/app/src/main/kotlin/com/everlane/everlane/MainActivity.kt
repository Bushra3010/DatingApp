package com.everlane.everlane

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/// Everlane shows people's photos, chats and personal details, so the whole
/// app is a secure window (FLAG_SECURE): Android blocks screenshots, screen
/// recording, screen sharing and casting of it (they show black), and the
/// recent-apps preview is blank. Flutter draws every screen in this one
/// activity, so navigating can't get around it.
///
/// For Play Store listing screenshots only, build with
/// `-Peverlane.allowScreenshots=true` (see play-store/PLAY_STORE.md).
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (!BuildConfig.ALLOW_SCREENSHOTS) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        super.onCreate(savedInstanceState)
        // Android 13+: also hide the app's content in the recents screen.
        if (!BuildConfig.ALLOW_SCREENSHOTS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
