package com.eventer.hardware_barcode_scanner

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class HardwareBarcodeScannerPluginTest {
    @Test
    fun fallbackStringExtra_ignoresFormatAndCommandMetadata() {
        val extras = linkedMapOf(
            "barcodeType" to "CODE_128",
            "COMMAND" to "START_DECODE",
            "device_source" to "scanner",
            "vendor_payload" to "ABC-123",
        )

        assertEquals(
            "ABC-123",
            fallbackStringExtra(extras, setOf("barcodeType")),
        )
    }

    @Test
    fun fallbackStringExtra_doesNotTreatSymbologyAsBarcodeData() {
        val extras = linkedMapOf("symbology" to "QR_CODE")

        assertNull(fallbackStringExtra(extras, emptySet()))
    }
}
