package com.follow.clash.service.modules

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.runBlocking

interface ModuleLoaderScope {
    fun <T : Module> install(module: T): T
}

interface ModuleLoader {
    fun load()

    fun cancel()
}

private val mutex = Mutex()
fun CoroutineScope.moduleLoader(block: suspend ModuleLoaderScope.() -> Unit): ModuleLoader {
    val modules = mutableListOf<Module>()
    var isLoaded = false

    return object : ModuleLoader {
        override fun load() {
            runBlocking {
                mutex.withLock {
                    if (isLoaded) {
                        return@withLock
                    }
                    val scope = object : ModuleLoaderScope {
                        override fun <T : Module> install(module: T): T {
                            modules.add(module)
                            module.install()
                            return module
                        }
                    }
                    scope.block()
                    isLoaded = true
                }
            }
        }

        override fun cancel() {
            runBlocking {
                mutex.withLock {
                    if (!isLoaded && modules.isEmpty()) {
                        return@withLock
                    }
                    modules.asReversed().forEach { it.uninstall() }
                    modules.clear()
                    isLoaded = false
                }
            }
        }
    }
}
