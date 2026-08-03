package com.eventer.hardware_barcode_scanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HardwareBarcodeScannerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private companion object {
        const val TAG = "HardwareBarcodeScanner"
    }

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var presets: List<BroadcastPreset> = emptyList()
    private var chainwayController: ChainwayBroadcastController? = null
    private var showLogs = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "hardware_barcode_scanner/methods")
        eventChannel = EventChannel(binding.binaryMessenger, "hardware_barcode_scanner/events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBroadcasts" -> {
                closeChainwayBroadcastOutput()
                presets = parsePresets(call.argument<List<Map<String, Any?>>>("presets"))
                showLogs = call.argument<Boolean>("showLogs") ?: false
                startReceiver()
                val shouldConfigureChainway =
                    call.argument<Boolean>("configureChainwayBroadcastOutput") ?: true
                if (shouldConfigureChainway) {
                    configureChainwayBroadcastOutput()
                }
                logDebug("Started broadcast receiver with ${presets.sumOf { it.actions.size }} actions")
                result.success(null)
            }
            "stopBroadcasts" -> {
                closeChainwayBroadcastOutput()
                stopReceiver()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        closeChainwayBroadcastOutput()
        stopReceiver()
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
    }

    private fun logDebug(message: String) {
        if (showLogs) {
            Log.d(TAG, message)
        }
    }

    private fun logWarning(message: String, error: Throwable? = null) {
        if (showLogs) {
            if (error == null) {
                Log.w(TAG, message)
            } else {
                Log.w(TAG, message, error)
            }
        }
    }

    private fun startReceiver() {
        stopReceiver()
        if (presets.isEmpty()) return

        val filter = IntentFilter()
        presets.flatMap { it.actions }.distinct().forEach { action ->
            filter.addAction(action)
        }
        filter.addCategory(Intent.CATEGORY_DEFAULT)

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                handleIntent(intent)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
    }

    private fun stopReceiver() {
        val activeReceiver = receiver ?: return
        try {
            context.unregisterReceiver(activeReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was already unregistered by the platform.
        }
        receiver = null
    }

    private fun configureChainwayBroadcastOutput() {
        val chainwayPreset = presets.firstOrNull { it.name == "chainway" } ?: return
        val action = chainwayPreset.actions.firstOrNull() ?: "com.scanner.broadcast"
        val dataKey = chainwayPreset.dataKeys.firstOrNull() ?: "data"

        try {
            val controller = chainwayController ?: ChainwayBroadcastController(context).also {
                chainwayController = it
            }
            controller.open(action, dataKey)
            logDebug("Configured Chainway broadcast output action=$action dataKey=$dataKey")
        } catch (error: ClassNotFoundException) {
            logDebug(
                "Chainway BarcodeUtility SDK is not available; install/include cw-deviceapi if Chainway C66 is not already configured for broadcast output",
            )
        } catch (error: Throwable) {
            logWarning("Unable to configure Chainway broadcast output: ${error.message}", error)
        }
    }

    private fun closeChainwayBroadcastOutput() {
        try {
            chainwayController?.close()
        } catch (error: Throwable) {
            logWarning("Unable to close Chainway scanner output: ${error.message}", error)
        }
        chainwayController = null
    }

    private fun handleIntent(intent: Intent) {
        val action = intent.action ?: return
        logDebug("Received scanner broadcast action=$action")
        val matchingPresets = presets.filter { it.actions.contains(action) }
        if (matchingPresets.isEmpty()) {
            logDebug("Ignoring unmatched scanner broadcast action=$action")
            return
        }

        val dataKeys = matchingPresets.flatMap { it.dataKeys }.distinct()
        val formatKeys = matchingPresets.flatMap { it.formatKeys }.distinct()
        val extras = stringExtras(intent)
        val value =
            firstStringExtra(intent, dataKeys)
                ?: fallbackStringExtra(extras, formatKeys.toSet())
                ?: dataFromUri(intent)
        val format = firstStringExtra(intent, formatKeys)

        val payload = hashMapOf<String, Any?>(
            "value" to value,
            "format" to format,
            "action" to action,
            "preset" to matchingPresets.first().name,
            "extras" to extras,
        )
        logDebug("Forwarding scanner broadcast action=$action value=$value format=$format extras=$extras")
        eventSink?.success(payload)
    }

    private fun firstStringExtra(intent: Intent, keys: List<String>): String? {
        for (key in keys) {
            val value = stringExtra(intent, key)
            if (!value.isNullOrBlank() && !isCommandValue(value)) {
                return value
            }
        }
        return null
    }

    private fun stringExtra(intent: Intent, key: String): String? {
        return try {
            val extras = intent.extras ?: return null
            extras.getString(key)
                ?: extras.getByteArray(key)?.toString(Charsets.UTF_8)
                ?: extras.getCharSequence(key)?.toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun stringExtras(intent: Intent): Map<String, String> {
        val extras = intent.extras ?: return emptyMap()
        val values = linkedMapOf<String, String>()
        for (key in extras.keySet()) {
            stringExtra(intent, key)?.let { value ->
                if (value.isNotBlank()) {
                    values[key] = value
                }
            }
        }
        return values
    }

    private fun dataFromUri(intent: Intent): String? {
        val data = intent.dataString ?: return null
        if (data.contains("://") || isCommandValue(data)) return null
        return data.takeIf { it.isNotBlank() }
    }

    private fun isCommandValue(value: String): Boolean {
        val normalized = value.trim().uppercase()
        return normalized == "START_DECODE" ||
            normalized == "STOP_DECODE" ||
            normalized == "ENABLE" ||
            normalized == "DISABLE" ||
            normalized == "START" ||
            normalized == "STOP"
    }

    private fun parsePresets(rawPresets: List<Map<String, Any?>>?): List<BroadcastPreset> {
        return rawPresets.orEmpty().mapNotNull { raw ->
            val name = raw["name"] as? String ?: return@mapNotNull null
            val actions = stringList(raw["actions"])
            if (actions.isEmpty()) return@mapNotNull null
            BroadcastPreset(
                name = name,
                actions = actions.toSet(),
                dataKeys = stringList(raw["dataKeys"]),
                formatKeys = stringList(raw["formatKeys"]),
            )
        }
    }

    private fun stringList(value: Any?): List<String> {
        return (value as? List<*>)?.mapNotNull { it as? String }.orEmpty()
    }

    private data class BroadcastPreset(
        val name: String,
        val actions: Set<String>,
        val dataKeys: List<String>,
        val formatKeys: List<String>,
    )

    private class ChainwayBroadcastController(private val context: Context) {
        private val utilityClass = Class.forName("com.barcode.BarcodeUtility")
        private val moduleTypeClass = Class.forName("com.barcode.BarcodeUtility\$ModuleType")
        private val utility = utilityClass.getMethod("getInstance").invoke(null)
        private val module2d = requireNotNull(moduleTypeClass.enumConstants).first { constant ->
            (constant as Enum<*>).name == "BARCODE_2D"
        }

        fun open(action: String, dataKey: String) {
            call("setOutputMode", arrayOf(Context::class.java, Int::class.javaPrimitiveType), context, 2)
            call(
                "setScanResultBroadcast",
                arrayOf(Context::class.java, String::class.java, String::class.java),
                context,
                action,
                dataKey,
            )
            call("open", arrayOf(Context::class.java, moduleTypeClass), context, module2d)
            call(
                "setReleaseScan",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
            // Failure broadcasts are deliberately OFF.
            //
            // Chainway sends them on the same action and the same data key as a
            // successful scan, with a marker value such as "cancel", so nothing
            // downstream can tell a failed trigger pull from a barcode that
            // happens to read that way. Asking for them produced a phantom scan
            // every time a trigger pull did not decode — observed on a C66,
            // 2026-08-03. The package has no way to interpret them, so it does
            // not request them.
            call(
                "setScanFailureBroadcast",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
            call(
                "enableContinuousScan",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
            call(
                "enablePlayFailureSound",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
            call(
                "enablePlaySuccessSound",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
            call(
                "enableEnter",
                arrayOf(Context::class.java, Boolean::class.javaPrimitiveType),
                context,
                false,
            )
        }

        fun close() {
            call("stopScan", arrayOf(Context::class.java, moduleTypeClass), context, module2d)
            call("close", arrayOf(Context::class.java, moduleTypeClass), context, module2d)
        }

        private fun call(name: String, parameterTypes: Array<Class<*>?>, vararg args: Any?) {
            utilityClass.getMethod(name, *parameterTypes).invoke(utility, *args)
        }
    }
}

internal fun fallbackStringExtra(
    extras: Map<String, String>,
    excludedKeys: Set<String>,
): String? {
    return extras.entries.firstOrNull { entry ->
        entry.key !in excludedKeys &&
            !entry.key.contains("ACTION", ignoreCase = true) &&
            !entry.key.contains("COMMAND", ignoreCase = true) &&
            !entry.key.contains("ENABLE", ignoreCase = true) &&
            !entry.key.contains("FORMAT", ignoreCase = true) &&
            !entry.key.contains("TYPE", ignoreCase = true) &&
            !entry.key.contains("SYMBOLOGY", ignoreCase = true) &&
            !entry.key.contains("SOURCE", ignoreCase = true) &&
            !isScannerCommandValue(entry.value)
    }?.value
}

private fun isScannerCommandValue(value: String): Boolean {
    val normalized = value.trim().uppercase()
    return normalized == "START_DECODE" ||
        normalized == "STOP_DECODE" ||
        normalized == "ENABLE" ||
        normalized == "DISABLE" ||
        normalized == "START" ||
        normalized == "STOP"
}
