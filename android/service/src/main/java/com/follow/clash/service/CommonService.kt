package com.follow.clash.service

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import com.follow.clash.core.Core
import com.follow.clash.service.modules.NetworkObserveModule
import com.follow.clash.service.modules.NotificationModule
import com.follow.clash.service.modules.SuspendModule
import com.follow.clash.service.modules.moduleLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.util.concurrent.atomic.AtomicBoolean

class CommonService : Service(), IBaseService,
    CoroutineScope by CoroutineScope(Dispatchers.Default) {

    private val self: CommonService
        get() = this

    private val loader = moduleLoader {
        install(NetworkObserveModule(self))
        install(NotificationModule(self))
        install(SuspendModule(self))
    }
    private val isStarted = AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()
        handleCreate()
    }

    override fun onDestroy() {
        stopInternal(force = true, stopSelfService = false)
        handleDestroy()
        super.onDestroy()
    }

    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): CommonService = this@CommonService
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun start() {
        if (!isStarted.compareAndSet(false, true)) {
            return
        }
        try {
            loader.load()
        } catch (e: Exception) {
            stopInternal(force = true)
            throw e
        }
    }

    override fun stop() {
        stopInternal()
    }

    private fun stopInternal(
        force: Boolean = false,
        stopSelfService: Boolean = true,
    ) {
        if (!force && !isStarted.compareAndSet(true, false)) {
            return
        }
        if (force) {
            isStarted.set(false)
        }
        loader.cancel()
        if (stopSelfService) {
            stopSelf()
        }
    }
}
