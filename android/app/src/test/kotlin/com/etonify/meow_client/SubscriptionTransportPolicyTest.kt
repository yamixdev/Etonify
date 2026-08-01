package com.etonify.meow_client

import java.net.URL
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SubscriptionTransportPolicyTest {
    @Test
    fun allowsHttpsAndLiteralLoopbackHttp() {
        SubscriptionTransportPolicy.validate(URL("https://example.com/sub"))
        SubscriptionTransportPolicy.validate(URL("http://localhost/sub"))
        SubscriptionTransportPolicy.validate(URL("http://127.0.0.1/sub"))
        SubscriptionTransportPolicy.validate(URL("http://[::1]/sub"))
    }

    @Test
    fun rejectsRemoteHttpAndNonLiteralLoopbackNames() {
        for (url in listOf("http://example.com/sub", "http://localhost./sub")) {
            try {
                SubscriptionTransportPolicy.validate(URL(url))
                fail("Expected insecure subscription URL to be rejected: $url")
            } catch (error: IllegalArgumentException) {
                assertTrue(error.message.orEmpty().contains("must use HTTPS"))
            }
        }
    }
}
