package com.houseflow

import android.os.Debug
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.InviteCodeBridge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BridgeRoundtripTest {
    @Test fun coreRuleRunsThroughGeneratedJni() {
        assertEquals("AB12CD34", InviteCodeBridge.normalize("ab-12 cd34xyz"))
        assertEquals("", InviteCodeBridge.normalize(""))
        assertEquals("12345678", InviteCodeBridge.normalize("１２３４５６７８ 12345678"))
    }

    @Test fun invalidInputStopsAtKotlinBoundary() {
        assertTrue(runCatching { InviteCodeBridge.normalize(null) }.exceptionOrNull() is IllegalArgumentException)
        assertTrue(runCatching { InviteCodeBridge.normalize("x".repeat(65)) }.exceptionOrNull() is IllegalArgumentException)
    }

    @Test fun logNativeBoundaryBaseline() {
        val input = "ab-12 cd34xyz"
        repeat(100) { InviteCodeBridge.normalize(input) }
        val nativeBytesBefore = Debug.getNativeHeapAllocatedSize()
        val timings = LongArray(1_000)
        repeat(timings.size) { index ->
            val start = System.nanoTime()
            InviteCodeBridge.normalize(input)
            timings[index] = System.nanoTime() - start
        }
        timings.sort()
        val nativeBytesAfter = Debug.getNativeHeapAllocatedSize()
        Log.i(
            "HouseFlowBridgePerf",
            "calls=${timings.size} p50Ns=${timings[499]} p95Ns=${timings[949]} " +
                "nativeHeapDeltaBytes=${nativeBytesAfter - nativeBytesBefore}"
        )
    }
}
