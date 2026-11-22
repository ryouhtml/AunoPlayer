package com.aunoplayer.auno

/** Android's Visualizer callback rate uses milliHertz, not frames per second. */
internal fun visualizerCaptureRateMilliHz(maxCaptureRateMilliHz: Int): Int =
    minOf(30_000, maxCaptureRateMilliHz)
