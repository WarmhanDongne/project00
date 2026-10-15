package com.warmhandongne.msg

import android.content.pm.ActivityInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Flutter가 첫 프레임을 그린 뒤 방향을 바꾸면 시작 화면이 잠깐 세로로
        // 보입니다. 태블릿 qualifier는 Flutter와 같은 600dp 기준입니다.
        if (resources.getBoolean(R.bool.is_tablet_device)) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
        super.onCreate(savedInstanceState)
    }
}
