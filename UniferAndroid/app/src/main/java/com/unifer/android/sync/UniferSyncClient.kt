package com.unifer.android.sync

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.util.ArrayDeque

/**
 * Minimal queue + stub network layer; see repository `docs/SYNC_PROTOCOL.md`.
 * Replace enqueue/flush with encrypted WebSocket transport.
 */
class UniferSyncClient(
    @Suppress("unused") private val appContext: Context,
    private val config: UniferSyncConfig
) {
    private val mutex = Mutex()
    private val pending = ArrayDeque<String>()

    suspend fun enqueueLocalClip(plain: String?) = mutex.withLock {
        if (plain.isNullOrBlank()) return@withLock
        pending.addLast(plain)
    }

    suspend fun flushPending(reason: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val snapshot = pending.toList()
            pending.clear()
            // Stub: integrate OkHttp/WebSocket + XChaCha20 here; never send plaintext in production.
            snapshot.forEach { _ ->
                // Would POST/WSS to config.relayBaseUrl with envelope { v:1, vault_id, ... }
            }
            android.util.Log.i("UniferSync", "flush ($reason) dropped ${snapshot.size} pending; relay=${config.relayBaseUrl}")
        }
    }
}
