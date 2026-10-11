package com.houseflow

import android.os.Debug
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.InviteCodeBridge
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BridgeRoundtripTest {
    @Test fun authWireRunsThroughGeneratedJni() {
        assertEquals(2, HouseFlowAndroidBridge.bridgeVersion())
        val body = HouseFlowAndroidBridge.loginRequestBody("ada@example.com", "secret")
        assertEquals("ada@example.com", org.json.JSONObject(body).getString("email"))
        assertEquals("secret", org.json.JSONObject(body).getString("password"))
        assertEquals("abc", org.json.JSONObject(HouseFlowAndroidBridge.loginResponse(200, """{"token":"abc"}""")).getString("token"))
        assertEquals("Invalid credentials", org.json.JSONObject(HouseFlowAndroidBridge.loginResponse(401, """{"message":"Invalid credentials"}""")).getString("message"))
        val profile = """{"success":true,"data":{"birthDay":"1990-01-01","createdOn":"2026-01-01","email":"ada@example.com","firstName":"Ada","houseList":[{"houseId":"h","houseName":"Home","houseProfile":""}],"id":"u","imageUrl":"","isActive":true,"isVerifyEmail":true,"isVerifyPhone":false,"language":"en","lastLogin":"2026-01-02","lastName":"A","phoneNumber":"","updatedOn":"2026-01-03"}}"""
        val result = org.json.JSONObject(HouseFlowAndroidBridge.profileResponse(200, profile))
        assertEquals(true, result.getBoolean("ok"))
        assertEquals("dashboard", result.getString("destination"))
        assertEquals("en", result.getString("language"))
    }

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
