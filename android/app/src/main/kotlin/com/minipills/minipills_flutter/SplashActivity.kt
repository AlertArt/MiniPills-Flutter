package com.minipills.minipills_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * 全屏启动页：以 cover（centerCrop）方式铺满显示启动图，
 * 停留短暂时间后跳转到 Flutter 主界面。
 */
class SplashActivity : Activity() {

    private val splashDurationMs = 800L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing && !isDestroyed) {
                startActivity(Intent(this, MainActivity::class.java))
                finish()
            }
        }, splashDurationMs)
    }
}
