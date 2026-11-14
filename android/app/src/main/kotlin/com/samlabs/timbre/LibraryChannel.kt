package com.samlabs.timbre

import android.content.ContentUris
import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Reads the device audio library from MediaStore and pulls embedded cover art.
 *
 * All disk work happens off the main thread so a large library never stalls the
 * first frame.
 */
class LibraryChannel(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "timbre/library")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "query" -> runAsync(result) { queryLibrary() }
            "trackArt" -> {
                val uri = call.argument<String>("uri")
                val size = call.argument<Int>("size") ?: 640
                if (uri.isNullOrBlank()) {
                    result.success(null)
                } else {
                    runAsync(result) { embeddedArt(uri, size) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (t: Throwable) {
                main.post { result.error("timbre_error", t.message ?: t.javaClass.simpleName, null) }
            }
        }
    }

    private fun queryLibrary(): Map<String, Any> {
        val tracks = ArrayList<Map<String, Any?>>(1024)
        val folderCounts = HashMap<String, Int>()

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = ArrayList<String>(20).apply {
            add(MediaStore.Audio.Media._ID)
            add(MediaStore.Audio.Media.TITLE)
            add(MediaStore.Audio.Media.ARTIST)
            add(MediaStore.Audio.Media.ALBUM)
            add(MediaStore.Audio.Media.ALBUM_ID)
            add(MediaStore.Audio.Media.TRACK)
            add(MediaStore.Audio.Media.YEAR)
            add(MediaStore.Audio.Media.DURATION)
            add(MediaStore.Audio.Media.DATA)
            add(MediaStore.Audio.Media.DISPLAY_NAME)
            add(MediaStore.Audio.Media.SIZE)
            add(MediaStore.Audio.Media.DATE_ADDED)
            add(MediaStore.Audio.Media.DATE_MODIFIED)
            add(MediaStore.Audio.Media.GENRE)
            add(MediaStore.Audio.Media.MIME_TYPE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Audio.Media.RELATIVE_PATH)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(MediaStore.Audio.Media.ALBUM_ARTIST)
                add(MediaStore.Audio.Media.BITRATE)
            }
        }.toTypedArray()

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val order = "${MediaStore.Audio.Media.DATE_ADDED} DESC"

        appContext.contentResolver.query(
            collection,
            projection,
            selection,
            null,
            order,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val trackCol = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
            val yearCol = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
            val durationCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val nameCol = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val addedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val modifiedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
            val genreCol = cursor.getColumnIndex(MediaStore.Audio.Media.GENRE)
            val mimeCol = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
            val relCol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
            } else {
                -1
            }
            val albumArtistCol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ARTIST)
            } else {
                -1
            }
            val bitrateCol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                cursor.getColumnIndex(MediaStore.Audio.Media.BITRATE)
            } else {
                -1
            }

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val uri = ContentUris.withAppendedId(collection, id).toString()
                val displayName = nameCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                val dataPath = dataCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                val relative = relCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                val folder = folderOf(relative, dataPath)
                val title = titleCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: displayName?.substringBeforeLast('.')
                    ?: "Untitled"
                val artist = artistCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                    ?.takeIf { it != "<unknown>" }
                    ?: ""
                val albumArtist = albumArtistCol.takeIf { it >= 0 }
                    ?.let { cursor.getString(it) }
                    ?.takeIf { it != "<unknown>" }
                    ?: ""
                val album = albumCol.takeIf { it >= 0 }?.let { cursor.getString(it) }
                    ?.trim()
                    ?: ""
                val albumId = albumIdCol.takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: -1L
                val added = addedCol.takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: 0L
                val modified = modifiedCol.takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: 0L

                folderCounts[folder] = (folderCounts[folder] ?: 0) + 1

                tracks.add(
                    mapOf(
                        "id" to uri,
                        "uri" to uri,
                        "path" to (dataPath ?: relative ?: ""),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "albumArtist" to albumArtist,
                        "genre" to (genreCol.takeIf { it >= 0 }?.let { cursor.getString(it) } ?: ""),
                        "trackNo" to ((trackCol.takeIf { it >= 0 }?.let { cursor.getInt(it) } ?: 0) % 1000),
                        "discNo" to ((trackCol.takeIf { it >= 0 }?.let { cursor.getInt(it) } ?: 0) / 1000),
                        "year" to (yearCol.takeIf { it >= 0 }?.let { cursor.getInt(it) } ?: 0),
                        "durationMs" to (durationCol.takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: 0L),
                        "sizeBytes" to (sizeCol.takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: 0L),
                        "addedAt" to added * 1000L,
                        "modifiedAt" to modified * 1000L,
                        "folder" to folder,
                        "artKey" to if (albumId > 0) albumId.toString() else null,
                        "bitrate" to (bitrateCol.takeIf { it >= 0 }?.let { cursor.getInt(it) } ?: 0),
                        "mimeType" to (mimeCol.takeIf { it >= 0 }?.let { cursor.getString(it) } ?: ""),
                    ),
                )
            }
        }

        val folders = folderCounts.entries
            .filter { it.key.isNotEmpty() }
            .sortedBy { it.key.lowercase() }
            .map { mapOf("path" to it.key, "count" to it.value) }

        return mapOf(
            "tracks" to tracks,
            "folders" to folders,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    /** Turns a MediaStore relative path into "Music/Rock" style labels. */
    private fun folderOf(relativePath: String?, dataPath: String?): String {
        val raw = when {
            !relativePath.isNullOrBlank() -> relativePath
            !dataPath.isNullOrBlank() -> {
                val parent = File(dataPath).parent ?: ""
                parent
                    .replace("/storage/emulated/0/", "")
                    .replace("/storage/emulated/", "")
                    .replace("/sdcard/", "")
            }
            else -> return ""
        }
        return raw
            .trim()
            .trim('/')
            .replace(Regex("/+"), "/")
    }

    private fun embeddedArt(uriString: String, requestedSize: Int): ByteArray? {
        val target = requestedSize.coerceIn(128, 1024)
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(appContext, Uri.parse(uriString))
            val raw = retriever.embeddedPicture ?: return null

            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
            var sample = 1
            var width = bounds.outWidth
            while (width > target * 2 && sample < 8) {
                sample *= 2
                width /= 2
            }

            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = BitmapFactory.decodeByteArray(raw, 0, raw.size, options)
                ?: return raw
            val out = ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out)
            bitmap.recycle()
            out.toByteArray()
        } catch (t: Throwable) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
                // Nothing useful to do if the retriever is already gone.
            }
        }
    }
}
