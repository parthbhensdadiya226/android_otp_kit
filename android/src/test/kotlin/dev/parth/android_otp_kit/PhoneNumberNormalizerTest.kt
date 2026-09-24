package dev.parth.android_otp_kit

import kotlin.test.Test
import kotlin.test.assertEquals

class PhoneNumberNormalizerTest {

    /** Stands in for PhoneNumberUtils: only the numbers in [valid] exist. */
    private fun normalizer(vararg valid: String) = PhoneNumberNormalizer { number, region ->
        val e164 = if (number.startsWith("+")) number
        else "+" + PhoneNumberNormalizer.CALLING_CODES.getValue(region) + number
        e164.takeIf { it in valid }
    }

    private val indian = normalizer("+919876543210")

    @Test
    fun `fixes a US-locale prefix on an Indian SIM`() {
        assertEquals("+919876543210", indian.normalize("+1919876543210", "in", "US"))
    }

    @Test
    fun `fixes a UK-locale prefix on an Indian SIM`() {
        assertEquals("+919876543210", indian.normalize("+44919876543210", "in", "GB"))
    }

    @Test
    fun `fixes an Australian-locale prefix on an Indian SIM`() {
        assertEquals("+919876543210", indian.normalize("+61919876543210", "in", "AU"))
    }

    @Test
    fun `fixes a number the SIM stores in national format`() {
        assertEquals("+919876543210", indian.normalize("+19876543210", "in", "US"))
    }

    @Test
    fun `ignores spaces and dashes in the returned number`() {
        assertEquals("+919876543210", indian.normalize("+1 919-876-543210", "in", "US"))
    }

    @Test
    fun `keeps a correct number`() {
        assertEquals("+919876543210", indian.normalize("+919876543210", "in", "US"))
    }

    @Test
    fun `keeps the number when the locale matches the SIM`() {
        assertEquals("+1919876543210", indian.normalize("+1919876543210", "in", "IN"))
    }

    @Test
    fun `keeps the number when the SIM shares the locale's calling code`() {
        // A Canadian SIM on a US-locale phone: both use +1.
        val n = normalizer("+16135550123")
        assertEquals("+16135550123", n.normalize("+16135550123", "ca", "US"))
    }

    @Test
    fun `keeps a valid number from a second SIM`() {
        // Dual SIM: default SIM is Indian, the user picks their US number. The digits
        // after +1 also look like a valid Indian landline, but a valid number is never changed.
        val n = normalizer("+12025550123", "+912025550123")
        assertEquals("+12025550123", n.normalize("+12025550123", "in", "US"))
    }

    @Test
    fun `keeps a number from another country`() {
        val n = normalizer("+971501234567")
        assertEquals("+971501234567", n.normalize("+971501234567", "in", "US"))
    }

    @Test
    fun `rejects a repair that lands outside the SIM's country`() {
        // "+1" + a UK number: stripping +1 gives a valid UK number, not an Indian one.
        val n = normalizer("+447911123456")
        assertEquals("+1447911123456", n.normalize("+1447911123456", "in", "US"))
    }

    @Test
    fun `keeps the number when no repair is valid`() {
        assertEquals("+1123", indian.normalize("+1123", "in", "US"))
    }

    @Test
    fun `keeps the number when the SIM or locale country is unknown`() {
        assertEquals("+1919876543210", indian.normalize("+1919876543210", "", "US"))
        assertEquals("+1919876543210", indian.normalize("+1919876543210", "in", ""))
        assertEquals("+1919876543210", indian.normalize("+1919876543210", "zz", "US"))
    }

    @Test
    fun `keeps a number without a leading plus`() {
        assertEquals("1919876543210", indian.normalize("1919876543210", "in", "US"))
    }

    @Test
    fun `calling code table is complete for common regions`() {
        val table = PhoneNumberNormalizer.CALLING_CODES
        assertEquals("1", table["US"])
        assertEquals("44", table["GB"])
        assertEquals("91", table["IN"])
        assertEquals("971", table["AE"])
        assertEquals("880", table["BD"])
        assertEquals("55", table["BR"])
        assert(table.size > 230) { "only ${table.size} regions" }
    }
}
