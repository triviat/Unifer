package com.unifer.android.sync

/**
 * Serializable client configuration; secrets should live in EncryptedSharedPreferences in production.
 */
data class UniferSyncConfig(
    val relayBaseUrl: String,
    val vaultId: String? = null,
    val deviceId: String? = null
)
