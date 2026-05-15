package com.unifer.android

import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.unifer.android.sync.UniferSyncClient
import com.unifer.android.sync.UniferSyncConfig
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    UniferHomeScreen()
                }
            }
        }
    }
}

@Composable
private fun UniferHomeScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val sync = rememberUniferSyncClient()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Unifer (Android preview)", style = MaterialTheme.typography.headlineSmall)
        Text(
            "Clipboard access on Android 10+ is restricted while the app is in the background. " +
                "Use explicit actions while the app is open.",
            style = MaterialTheme.typography.bodyMedium
        )
        Button(onClick = {
            scope.launch {
                val clip = readClipboardPlaintext(context)
                sync.enqueueLocalClip(clip)
            }
        }) {
            Text("Read clipboard & enqueue sync stub")
        }
        Button(onClick = {
            scope.launch { sync.flushPending(reason = "manual") }
        }) {
            Text("Flush pending (stub)")
        }
    }
}

@Composable
private fun rememberUniferSyncClient(): UniferSyncClient {
    val context = LocalContext.current.applicationContext
    return androidx.compose.runtime.remember {
        UniferSyncClient(
            appContext = context,
            config = UniferSyncConfig(relayBaseUrl = "https://relay.example.invalid")
        )
    }
}

private fun readClipboardPlaintext(context: Context): String? {
    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = cm.primaryClip ?: return null
    if (clip.itemCount == 0) return null
    return clip.getItemAt(0).coerceToText(context)?.toString()
}
