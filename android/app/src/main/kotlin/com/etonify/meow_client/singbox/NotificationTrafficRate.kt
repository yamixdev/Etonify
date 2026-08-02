package com.etonify.meow_client.singbox

/**
 * The core status stream reports transfer deltas over its one-second interval.
 * Keep the foreground notification on the newest sample instead of applying a
 * second moving average on the Android side.
 */
internal fun currentTrafficRate(
    incomingBytesPerSecond: Long,
    available: Boolean,
): Long = if (available) incomingBytesPerSecond.coerceAtLeast(0L) else 0L
