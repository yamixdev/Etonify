package com.etonify.meow_client

import java.net.SocketException
import java.net.SocketTimeoutException
import org.junit.Assert.*
import org.junit.Test

class ResponseStartDeadlineTest {
    @Test fun localCancellationIsReportedAsTimeoutWithOriginalCause() {
        val deadline = ResponseStartDeadline(15000)
        var disconnected = false
        deadline.expire { disconnected = true }
        val original = SocketException("Socket closed")
        val failure = deadline.failure(original)
        assertTrue(disconnected)
        assertTrue(failure is SocketTimeoutException)
        assertSame(original, failure.cause)
        assertTrue(failure.message!!.contains("15000"))
    }
    @Test fun peerClosureWithoutLocalDeadlineStaysSocketError() {
        val original = SocketException("Socket closed")
        assertSame(original, ResponseStartDeadline(15000).failure(original))
    }
}
