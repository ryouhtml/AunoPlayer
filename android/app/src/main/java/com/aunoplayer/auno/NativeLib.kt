package com.aunoplayer.auno

import android.content.Context

/**
 * JNI wrapper around the shared Rust core. The native symbols are defined in
 * `src/android.rs` and are all static, hence the JClass second parameter.
 */
object NativeLib {
    init {
        System.loadLibrary("auno_player")
    }

    @JvmStatic
    external fun `init`(context: Context, root: String): Boolean

    @JvmStatic
    external fun poll()

    @JvmStatic
    external fun refresh(): String

    @JvmStatic
    external fun play()

    @JvmStatic
    external fun pause()

    @JvmStatic
    external fun next()

    @JvmStatic
    external fun previous()

    @JvmStatic
    external fun select(index: Int)

    @JvmStatic
    external fun seek(deltaMs: Int)

    @JvmStatic
    external fun setVolume(volume: Int)

    @JvmStatic
    external fun toggleBypass(): Boolean

    @JvmStatic
    external fun statusJson(): String

    @JvmStatic
    external fun libraryJson(): String
}
