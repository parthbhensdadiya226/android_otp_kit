package dev.parth.android_otp_kit

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager
import android.util.Base64
import androidx.core.content.ContextCompat
import androidx.core.os.BundleCompat
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/**
 * Android OTP helpers: Phone Number Hint, SMS Retriever, SMS User Consent
 * and app signature hashes.
 */
class AndroidOtpKitPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.ActivityResultListener {

    private companion object {
        const val REQUEST_PHONE_HINT = 0x4F01
        const val REQUEST_SMS_CONSENT = 0x4F02
        const val GMS_PACKAGE = "com.google.android.gms"

        /**
         * SMS_RETRIEVED broadcasts don't say which request they belong to, so a
         * TIMEOUT from an earlier, abandoned request (e.g. before "Resend OTP")
         * would end a new one. Play services times out after 5 minutes; any
         * TIMEOUT arriving much sooner than that is for an older request.
         */
        const val MIN_TIMEOUT_MS = 4 * 60 * 1000L
    }

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    private var pendingHintResult: MethodChannel.Result? = null
    private var events: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null

    // region FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "android_otp_kit")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "android_otp_kit/sms")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopListening()
    }

    // endregion

    // region ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // endregion

    // region Method calls

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPhoneNumberHint" -> requestPhoneNumberHint(result)
            "getAppSignatures" -> result.success(getAppSignatures())
            else -> result.notImplemented()
        }
    }

    private fun requestPhoneNumberHint(result: MethodChannel.Result) {
        val activity = activity
            ?: return result.error("NO_ACTIVITY", "Plugin is not attached to an activity.", null)
        if (pendingHintResult != null) {
            return result.error("ALREADY_ACTIVE", "A phone number hint request is already in progress.", null)
        }
        pendingHintResult = result
        Identity.getSignInClient(activity)
            .getPhoneNumberHintIntent(GetPhoneNumberHintIntentRequest.builder().build())
            .addOnSuccessListener { pendingIntent ->
                try {
                    activity.startIntentSenderForResult(
                        pendingIntent.intentSender, REQUEST_PHONE_HINT, null, 0, 0, 0
                    )
                } catch (e: Exception) {
                    finishHint { it.error("HINT_FAILED", e.message, null) }
                }
            }
            .addOnFailureListener { e ->
                // Usually means no SIM / no phone numbers are available on the device.
                finishHint { it.error("HINT_UNAVAILABLE", e.message, null) }
            }
    }

    /** Fixes a wrong country code; see [PhoneNumberNormalizer]. */
    private fun normalizeNumber(number: String): String {
        val simIso = (context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)
            ?.simCountryIso.orEmpty()
        val localeRegion = context.resources.configuration.locales[0]?.country.orEmpty()
        return PhoneNumberNormalizer(PhoneNumberUtils::formatNumberToE164)
            .normalize(number, simIso, localeRegion)
    }

    private fun finishHint(block: (MethodChannel.Result) -> Unit) {
        pendingHintResult?.let(block)
        pendingHintResult = null
    }

    /** Hashes the SMS Retriever API expects at the end of the message, one per signing certificate. */
    private fun getAppSignatures(): List<String> {
        val packageName = context.packageName
        val pm = context.packageManager
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val signingInfo = info.signingInfo ?: return emptyList()
            if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners
            else signingInfo.signingCertificateHistory
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        } ?: return emptyList()

        return signatures.map { appHash(packageName, it.toCharsString()) }.distinct()
    }

    private fun appHash(packageName: String, certHex: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$packageName $certHex".toByteArray(StandardCharsets.UTF_8))
            .copyOfRange(0, 9)
        return Base64.encodeToString(digest, Base64.NO_PADDING or Base64.NO_WRAP).substring(0, 11)
    }

    // endregion

    // region SMS stream

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        stopListening()
        events = sink
        val args = arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val consent = args["mode"] == "userConsent"

        val task = if (consent) {
            SmsRetriever.getClient(context).startSmsUserConsent(args["senderPhoneNumber"] as? String)
        } else {
            SmsRetriever.getClient(context).startSmsRetriever()
        }

        val startedAt = SystemClock.elapsedRealtime()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                val status = BundleCompat.getParcelable(extras, SmsRetriever.EXTRA_STATUS, Status::class.java)
                when (status?.statusCode) {
                    CommonStatusCodes.SUCCESS ->
                        if (consent) {
                            launchConsent(
                                BundleCompat.getParcelable(extras, SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
                            )
                        } else emitAndStop(mapOf("type" to "sms", "message" to extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE)))
                    CommonStatusCodes.TIMEOUT ->
                        if (SystemClock.elapsedRealtime() - startedAt >= MIN_TIMEOUT_MS) {
                            emitAndStop(mapOf("type" to "timeout"))
                        } // else: a stale timeout from an earlier request; keep listening
                    else -> {
                        events?.error("SMS_FAILED", "SMS retrieval failed: ${status?.statusCode}", null)
                        stopListening()
                    }
                }
            }
        }

        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
            SmsRetriever.SEND_PERMISSION,
            null,
            ContextCompat.RECEIVER_EXPORTED,
        )
        smsReceiver = receiver

        task.addOnFailureListener { e ->
            events?.error("START_FAILED", e.message, null)
            stopListening()
        }
    }

    override fun onCancel(arguments: Any?) = stopListening()

    private fun launchConsent(consentIntent: Intent?) {
        val activity = activity
        // Guard against intent redirection: only launch the consent screen from Play services.
        val target = consentIntent?.resolveActivity(context.packageManager)
        if (activity == null || consentIntent == null || target?.packageName != GMS_PACKAGE) {
            events?.error("CONSENT_UNAVAILABLE", "Cannot show the SMS consent dialog.", null)
            stopListening()
            return
        }
        val grantFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if (consentIntent.flags and grantFlags != 0) {
            events?.error("CONSENT_UNAVAILABLE", "Consent intent has unexpected URI grant flags.", null)
            stopListening()
            return
        }
        activity.startActivityForResult(consentIntent, REQUEST_SMS_CONSENT)
    }

    private fun emitAndStop(event: Map<String, Any?>) {
        events?.success(event)
        stopListening()
    }

    private fun stopListening() {
        smsReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        smsReceiver = null
        events?.endOfStream()
        events = null
    }

    // endregion

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            REQUEST_PHONE_HINT -> {
                if (resultCode == Activity.RESULT_OK && data != null && activity != null) {
                    try {
                        val number = Identity.getSignInClient(activity!!).getPhoneNumberFromIntent(data)
                        finishHint { it.success(normalizeNumber(number)) }
                    } catch (e: Exception) {
                        finishHint { it.error("HINT_FAILED", e.message, null) }
                    }
                } else {
                    finishHint { it.success(null) } // User dismissed the picker.
                }
                true
            }
            REQUEST_SMS_CONSENT -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    emitAndStop(mapOf("type" to "sms", "message" to data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)))
                } else {
                    emitAndStop(mapOf("type" to "denied"))
                }
                true
            }
            else -> false
        }
    }
}
