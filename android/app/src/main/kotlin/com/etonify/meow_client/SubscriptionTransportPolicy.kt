package com.etonify.meow_client

import java.net.URL

/**
 * Transport policy for remotely fetched subscription content.
 *
 * Plain HTTP is accepted only for a literal local development server. A name
 * that merely resolves to loopback is deliberately not enough: DNS can change.
 */
internal object SubscriptionTransportPolicy {
    fun validate(url: URL) {
        val scheme = url.protocol.trim().lowercase()
        require(scheme == "http" || scheme == "https") {
            "Only HTTP and HTTPS URLs are supported."
        }
        if (scheme == "https") {
            return
        }
        require(isLiteralLoopbackHost(url.host)) {
            "Subscription URLs must use HTTPS. Plain HTTP is allowed only for " +
                "localhost, 127.0.0.1, or [::1]."
        }
    }

    internal fun isLiteralLoopbackHost(host: String): Boolean {
        val normalized = host.trim()
            .removePrefix("[")
            .removeSuffix("]")
            .lowercase()
        return normalized == "localhost" ||
            normalized == "127.0.0.1" ||
            normalized == "::1"
    }
}
