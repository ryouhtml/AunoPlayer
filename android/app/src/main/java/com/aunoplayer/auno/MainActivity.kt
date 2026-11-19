package com.aunoplayer.auno

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val musicDir = File(filesDir, "Music")
        musicDir.mkdirs()
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) {
                    PlayerScreen(musicDir)
                }
            }
        }
    }
}

private val SUPPORTED_EXTENSIONS = setOf(
    "flac", "wav", "rf64", "aif", "aiff", "alac", "m4a", "dsf", "dff", "cue",
)

private fun JSONObject.text(key: String, fallback: String = "-"): String =
    if (has(key) && !isNull(key)) getString(key) else fallback

private fun JSONObject.number(key: String): Long =
    if (has(key) && !isNull(key)) getLong(key) else 0L

private fun JSONObject.flag(key: String): Boolean =
    has(key) && !isNull(key) && getBoolean(key)

private fun clock(ms: Long): String {
    val seconds = ms / 1000
    return "%02d:%02d".format(seconds / 60, seconds % 60)
}

private fun displayName(context: Context, uri: Uri): String? {
    val cursor = context.contentResolver.query(
        uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
    )
    return cursor?.use {
        val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && it.moveToFirst()) it.getString(index) else null
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(musicDir: File) {
    val context = LocalContext.current
    var status by remember { mutableStateOf<JSONObject?>(null) }
    var library by remember { mutableStateOf<List<String>>(emptyList()) }
    var note by remember { mutableStateOf("Menyiapkan pustaka…") }
    var bypass by remember { mutableStateOf(true) }
    var volume by remember { mutableIntStateOf(100) }

    fun sync() {
        try {
            status = JSONObject(NativeLib.statusJson())
            val array = JSONArray(NativeLib.libraryJson())
            library = List(array.length()) { array.getString(it) }
        } catch (e: Exception) {
            note = "Gagal membaca status: ${e.message}"
        }
    }

    val importAudio = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris ->
        var added = 0
        var skipped = 0
        for (uri in uris) {
            val raw = displayName(context, uri) ?: "track-$added"
            val name = raw.replace('/', '_').replace('\\', '_')
            if (name.substringAfterLast('.', "").lowercase() !in SUPPORTED_EXTENSIONS) {
                skipped++
                continue
            }
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    File(musicDir, name).outputStream().use { output -> input.copyTo(output) }
                }
                added++
            } catch (e: Exception) {
                note = "Gagal menyalin $name: ${e.message}"
            }
        }
        val refreshed = try {
            NativeLib.refresh()
        } catch (e: Exception) {
            "Refresh gagal: ${e.message}"
        }
        note = "$refreshed · $added ditambahkan" +
            if (skipped > 0) ", $skipped dilewati" else ""
        sync()
    }

    LaunchedEffect(Unit) {
        try {
            if (NativeLib.`init`(context.applicationContext, musicDir.absolutePath)) {
                note = NativeLib.refresh()
                sync()
                while (true) {
                    delay(250)
                    NativeLib.poll()
                    sync()
                }
            } else {
                note = "Inisialisasi gagal"
            }
        } catch (e: Exception) {
            note = "Error: ${e.message}"
        }
    }

    val current = status
    val now = current?.text("now", "—") ?: "—"
    val playing = current?.flag("playing") ?: false
    val codec = current?.text("codec", "-") ?: "-"
    val device = current?.text("device", "-") ?: "-"
    val elapsed = current?.number("elapsed_ms") ?: 0L
    val total = current?.number("total_ms") ?: 0L
    val rate = current?.number("sample_rate") ?: 0L
    val bits = current?.number("bits") ?: 0L
    val channels = current?.number("channels") ?: 0L
    val kbps = current?.number("pcm_kbps") ?: 0L
    val buffered = current?.number("buffered_frames") ?: 0L
    val underruns = current?.number("underruns") ?: 0L
    val progress = if (total > 0) (elapsed.toFloat() / total.toFloat()).coerceIn(0f, 1f) else 0f

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("AUNO PLAYER", style = MaterialTheme.typography.headlineSmall)
        Text(note, style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)

        Card(Modifier.fillMaxWidth()) {
            Column(
                Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(now, style = MaterialTheme.typography.titleMedium,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(
                    "${if (playing) "PLAYING" else "PAUSED"} · $codec",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text("DAC: $device", style = MaterialTheme.typography.bodySmall)
                Text(
                    "$rate Hz · ${bits}-bit · ${channels} ch · PCM ${kbps} kbps",
                    style = MaterialTheme.typography.bodySmall,
                )
                Box(
                    Modifier.fillMaxWidth().height(4.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Box(
                        Modifier.fillMaxWidth(progress).fillMaxHeight()
                            .background(MaterialTheme.colorScheme.primary),
                    )
                }
                Text(
                    "${clock(elapsed)} / ${clock(total)} · buffer $buffered f · underrun $underruns",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { NativeLib.previous(); sync() }, Modifier.weight(1f)) { Text("◀◀") }
            Button(
                onClick = { if (playing) NativeLib.pause() else NativeLib.play(); sync() },
                Modifier.weight(1f),
            ) { Text(if (playing) "PAUSE" else "PLAY") }
            Button(onClick = { NativeLib.next(); sync() }, Modifier.weight(1f)) { Text("▶▶") }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { NativeLib.seek(-10_000); sync() }, Modifier.weight(1f)) {
                Text("−10 detik")
            }
            OutlinedButton(onClick = { NativeLib.seek(10_000); sync() }, Modifier.weight(1f)) {
                Text("+10 detik")
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Bypass volume", Modifier.weight(1f))
            Switch(checked = bypass, onCheckedChange = { bypass = NativeLib.toggleBypass() })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Volume", Modifier.weight(1f))
            Slider(
                value = volume.toFloat(),
                onValueChange = { volume = it.toInt(); NativeLib.setVolume(volume) },
                valueRange = 0f..100f,
                enabled = !bypass,
                modifier = Modifier.weight(2f),
            )
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(
                onClick = { note = NativeLib.refresh(); sync() },
                Modifier.weight(1f),
            ) { Text("Refresh") }
            Button(onClick = { importAudio.launch(arrayOf("*/*")) }, Modifier.weight(1f)) {
                Text("Import audio")
            }
        }

        Text("Pustaka (${library.size})", style = MaterialTheme.typography.titleSmall)
        LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            itemsIndexed(library) { index, label ->
                Row(
                    Modifier.fillMaxWidth()
                        .clickable { NativeLib.select(index); NativeLib.play(); sync() }
                        .padding(12.dp),
                ) {
                    Text(label, style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}
