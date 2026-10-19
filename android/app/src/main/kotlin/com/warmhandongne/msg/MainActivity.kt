package com.warmhandongne.msg

import android.content.pm.ActivityInfo
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var motionChannel: EventChannel? = null
    private var motionListener: SensorEventListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Flutter가 첫 프레임을 그린 뒤 방향을 바꾸면 시작 화면이 잠깐 세로로
        // 보입니다. 태블릿 qualifier는 Flutter와 같은 600dp 기준입니다.
        if (resources.getBoolean(R.bool.is_tablet_device)) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        motionChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mosigame/yut_motion/events",
        ).also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (accelerometer == null || events == null) {
                        events?.error("motion_unavailable", "Accelerometer unavailable", null)
                        return
                    }
                    val listener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            events.success(listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble()))
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                    }
                    motionListener?.let(sensorManager::unregisterListener)
                    motionListener = listener
                    sensorManager.registerListener(listener, accelerometer, SensorManager.SENSOR_DELAY_GAME)
                }

                override fun onCancel(arguments: Any?) {
                    motionListener?.let(sensorManager::unregisterListener)
                    motionListener = null
                }
            })
        }
    }

    override fun onDestroy() {
        motionListener?.let { listener ->
            (getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(listener)
        }
        motionListener = null
        motionChannel?.setStreamHandler(null)
        motionChannel = null
        super.onDestroy()
    }
}
