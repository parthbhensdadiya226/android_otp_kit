package dev.parth.android_otp_kit

/**
 * Repairs numbers that Phone Number Hint returns with the wrong country code.
 *
 * Many SIMs (e.g. in India) store the number without a leading "+". Play services then
 * reads it using the phone's language region, so on an English (US) phone "919876543210"
 * comes back as "+1919876543210", and on an English (UK) phone as "+44919876543210".
 *
 * A number is only changed when all of these hold:
 * - the phone's region and the SIM's country have different calling codes,
 * - the number starts with the phone region's calling code and is not a valid number there,
 * - after removing that code, the digits form a valid number in the SIM's country.
 *
 * In every other case the number is returned unchanged, so a correct number (including one
 * from a second SIM) is never made worse.
 *
 * @param toE164 returns the number in E.164 form if it is valid, reading national numbers
 *   in the given region, or null otherwise. On Android this is
 *   `PhoneNumberUtils.formatNumberToE164`; tests pass a fake.
 */
internal class PhoneNumberNormalizer(
    private val toE164: (number: String, regionIso: String) -> String?,
) {

    fun normalize(number: String, simCountryIso: String, localeRegionIso: String): String {
        val simRegion = simCountryIso.uppercase()
        val localeRegion = localeRegionIso.uppercase()
        val simCode = CALLING_CODES[simRegion] ?: return number
        val localeCode = CALLING_CODES[localeRegion] ?: return number
        if (simCode == localeCode) return number

        val cleaned = "+" + number.filter { it.isDigit() }
        if (!number.trimStart().startsWith("+") || !cleaned.startsWith("+$localeCode")) return number
        if (toE164(cleaned, localeRegion) != null) return number

        val digits = cleaned.removePrefix("+$localeCode")
        // "919876543210" (country code included) first, then "9876543210" (national number).
        for (candidate in listOf("+$digits", digits)) {
            val e164 = toE164(candidate, simRegion) ?: continue
            if (e164.startsWith("+$simCode")) return e164
        }
        return number
    }

    companion object {
        /** Country calling code for each region, keyed by ISO 3166-1 alpha-2 code. */
        val CALLING_CODES: Map<String, String> = buildMap {
            fun code(code: String, vararg regions: String) = regions.forEach { put(it, code) }

            code(
                "1", "US", "CA", "AG", "AI", "AS", "BB", "BM", "BS", "DM", "DO", "GD", "GU", "JM",
                "KN", "KY", "LC", "MP", "MS", "PR", "SX", "TC", "TT", "VC", "VG", "VI",
            )
            code("7", "RU", "KZ")
            code("20", "EG"); code("27", "ZA"); code("30", "GR"); code("31", "NL")
            code("32", "BE"); code("33", "FR"); code("34", "ES"); code("36", "HU")
            code("39", "IT", "VA"); code("40", "RO"); code("41", "CH"); code("43", "AT")
            code("44", "GB", "GG", "IM", "JE"); code("45", "DK"); code("46", "SE")
            code("47", "NO", "SJ"); code("48", "PL"); code("49", "DE"); code("51", "PE")
            code("52", "MX"); code("53", "CU"); code("54", "AR"); code("55", "BR")
            code("56", "CL"); code("57", "CO"); code("58", "VE"); code("60", "MY")
            code("61", "AU", "CC", "CX"); code("62", "ID"); code("63", "PH"); code("64", "NZ")
            code("65", "SG"); code("66", "TH"); code("81", "JP"); code("82", "KR")
            code("84", "VN"); code("86", "CN"); code("90", "TR"); code("91", "IN")
            code("92", "PK"); code("93", "AF"); code("94", "LK"); code("95", "MM")
            code("98", "IR")

            code("211", "SS"); code("212", "MA", "EH"); code("213", "DZ"); code("216", "TN")
            code("218", "LY"); code("220", "GM"); code("221", "SN"); code("222", "MR")
            code("223", "ML"); code("224", "GN"); code("225", "CI"); code("226", "BF")
            code("227", "NE"); code("228", "TG"); code("229", "BJ"); code("230", "MU")
            code("231", "LR"); code("232", "SL"); code("233", "GH"); code("234", "NG")
            code("235", "TD"); code("236", "CF"); code("237", "CM"); code("238", "CV")
            code("239", "ST"); code("240", "GQ"); code("241", "GA"); code("242", "CG")
            code("243", "CD"); code("244", "AO"); code("245", "GW"); code("246", "IO")
            code("247", "AC"); code("248", "SC"); code("249", "SD"); code("250", "RW")
            code("251", "ET"); code("252", "SO"); code("253", "DJ"); code("254", "KE")
            code("255", "TZ"); code("256", "UG"); code("257", "BI"); code("258", "MZ")
            code("260", "ZM"); code("261", "MG"); code("262", "RE", "YT"); code("263", "ZW")
            code("264", "NA"); code("265", "MW"); code("266", "LS"); code("267", "BW")
            code("268", "SZ"); code("269", "KM"); code("290", "SH", "TA"); code("291", "ER")
            code("297", "AW"); code("298", "FO"); code("299", "GL")

            code("350", "GI"); code("351", "PT"); code("352", "LU"); code("353", "IE")
            code("354", "IS"); code("355", "AL"); code("356", "MT"); code("357", "CY")
            code("358", "FI", "AX"); code("359", "BG"); code("370", "LT"); code("371", "LV")
            code("372", "EE"); code("373", "MD"); code("374", "AM"); code("375", "BY")
            code("376", "AD"); code("377", "MC"); code("378", "SM"); code("380", "UA")
            code("381", "RS"); code("382", "ME"); code("383", "XK"); code("385", "HR")
            code("386", "SI"); code("387", "BA"); code("389", "MK"); code("420", "CZ")
            code("421", "SK"); code("423", "LI")

            code("500", "FK"); code("501", "BZ"); code("502", "GT"); code("503", "SV")
            code("504", "HN"); code("505", "NI"); code("506", "CR"); code("507", "PA")
            code("508", "PM"); code("509", "HT"); code("590", "GP", "BL", "MF"); code("591", "BO")
            code("592", "GY"); code("593", "EC"); code("594", "GF"); code("595", "PY")
            code("596", "MQ"); code("597", "SR"); code("598", "UY"); code("599", "CW", "BQ")

            code("670", "TL"); code("672", "NF"); code("673", "BN"); code("674", "NR")
            code("675", "PG"); code("676", "TO"); code("677", "SB"); code("678", "VU")
            code("679", "FJ"); code("680", "PW"); code("681", "WF"); code("682", "CK")
            code("683", "NU"); code("685", "WS"); code("686", "KI"); code("687", "NC")
            code("688", "TV"); code("689", "PF"); code("690", "TK"); code("691", "FM")
            code("692", "MH")

            code("850", "KP"); code("852", "HK"); code("853", "MO"); code("855", "KH")
            code("856", "LA"); code("880", "BD"); code("886", "TW")

            code("960", "MV"); code("961", "LB"); code("962", "JO"); code("963", "SY")
            code("964", "IQ"); code("965", "KW"); code("966", "SA"); code("967", "YE")
            code("968", "OM"); code("970", "PS"); code("971", "AE"); code("972", "IL")
            code("973", "BH"); code("974", "QA"); code("975", "BT"); code("976", "MN")
            code("977", "NP"); code("992", "TJ"); code("993", "TM"); code("994", "AZ")
            code("995", "GE"); code("996", "KG"); code("998", "UZ")
        }
    }
}
