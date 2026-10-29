package com.fauscrew

import android.os.Debug
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fauscrew.platform.InviteCodeBridge
import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BridgeRoundtripTest {
    @Test fun authWireRunsThroughGeneratedJni() {
        assertEquals(10, FausCrewAndroidBridge.bridgeVersion())
        val body = FausCrewAndroidBridge.loginRequestBody("ada@example.com", "secret")
        assertEquals("ada@example.com", org.json.JSONObject(body).getString("email"))
        assertEquals("secret", org.json.JSONObject(body).getString("password"))
        assertEquals("abc", org.json.JSONObject(FausCrewAndroidBridge.loginResponse(200, """{"token":"abc"}""")).getString("token"))
        assertEquals("Invalid credentials", org.json.JSONObject(FausCrewAndroidBridge.loginResponse(401, """{"message":"Invalid credentials"}""")).getString("message"))
        val profile = """{"success":true,"data":{"birthDay":"1990-01-01","createdOn":"2026-01-01","email":"ada@example.com","firstName":"Ada","houseList":[{"houseId":"h","houseName":"Home","houseProfile":""}],"id":"u","imageUrl":"","isActive":true,"isVerifyEmail":true,"isVerifyPhone":false,"language":"en","lastLogin":"2026-01-02","lastName":"A","phoneNumber":"","updatedOn":"2026-01-03"}}"""
        val result = org.json.JSONObject(FausCrewAndroidBridge.profileResponse(200, profile))
        assertEquals(true, result.getBoolean("ok"))
        assertEquals("dashboard", result.getString("destination"))
        assertEquals("en", result.getString("language"))
        assertEquals("u", result.getString("userId"))
        assertEquals("h", result.getJSONArray("houseList").getJSONObject(0).getString("houseId"))
        val signup = org.json.JSONObject(FausCrewAndroidBridge.signupRequestBody("ada@example.com", "secret", "Ada", "A"))
        assertEquals("Ada", signup.getString("firstName"))
        val verify = org.json.JSONObject(FausCrewAndroidBridge.authActionResponse("verifyEmail", 200, """{"success":false}"""))
        assertEquals(false, verify.getBoolean("ok"))
        assertEquals("The verification code is invalid.", verify.getString("message"))
        val birthday = org.json.JSONObject(FausCrewAndroidBridge.birthdayRequestBody("2000-01-01T00:00:00Z"))
        assertEquals("2000-01-01T00:00:00Z", birthday.getString("birthDay"))
    }

    @Test fun houseWireRunsThroughGeneratedJni() {
        val create = org.json.JSONObject(FausCrewAndroidBridge.houseRequestBody("create", "", "", "Home", "", 2, 5, "", false))
        assertEquals("Home", create.getString("name"))
        val join = org.json.JSONObject(FausCrewAndroidBridge.houseRequestBody("join", "", "", "", "ab-12 cd34", 0, 0, "", false))
        assertEquals("AB12CD34", join.getString("inviteCode"))
        val house = """{"success":true,"data":{"id":"h","name":"Home","inviteCode":null,"maxMemberCount":4,"memberIds":[],"ownerId":"u","profileImage":"","type":1,"createdOn":"2026-01-01","updatedOn":"2026-01-02"}}"""
        assertEquals("h", org.json.JSONObject(FausCrewAndroidBridge.houseResponse("create", 200, house))
            .getJSONObject("data").getString("id"))
        val malformed = """{"success":true,"data":{"id":"h","name":"Home"}}"""
        assertEquals(false, org.json.JSONObject(FausCrewAndroidBridge.houseResponse("details", 200, malformed)).getBoolean("success"))
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
            "FausCrewBridgePerf",
            "calls=${timings.size} p50Ns=${timings[499]} p95Ns=${timings[949]} " +
                "nativeHeapDeltaBytes=${nativeBytesAfter - nativeBytesBefore}"
        )
    }
}
