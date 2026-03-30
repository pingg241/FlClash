package com.follow.clash.service.modules

abstract class Module {

    private var isInstall: Boolean = false

    protected abstract fun onInstall()
    protected abstract fun onUninstall()

    fun install() {
        if (isInstall) {
            return
        }
        onInstall()
        isInstall = true
    }

    fun uninstall() {
        if (!isInstall) {
            return
        }
        onUninstall()
        isInstall = false
    }
}
