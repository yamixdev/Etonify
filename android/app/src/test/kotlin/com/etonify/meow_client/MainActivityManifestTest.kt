package com.etonify.meow_client

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.w3c.dom.Element

class MainActivityManifestTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    @Test
    fun `main activity uses the default app task for external launches`() {
        assertFalse(
            "An explicit empty affinity makes notification and tile launches create another recent task",
            mainActivity().hasAttributeNS(androidNamespace, "taskAffinity"),
        )
    }

    @Test
    fun `main activity leaves import links to the native bridge`() {
        val metadata = mainActivity().getElementsByTagName("meta-data")
        val flags = (0 until metadata.length)
            .map { metadata.item(it) as Element }
            .filter { it.getAttributeNS(androidNamespace, "name") == "flutter_deeplinking_enabled" }
            .map { it.getAttributeNS(androidNamespace, "value") }

        assertEquals(listOf("false"), flags)
    }

    private fun mainActivity(): Element {
        val manifest = File("src/main/AndroidManifest.xml")
        val document = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }.newDocumentBuilder().parse(manifest)
        val activities = document.getElementsByTagName("activity")
        return (0 until activities.length)
            .map { activities.item(it) as Element }
            .single { it.getAttributeNS(androidNamespace, "name") == ".MainActivity" }
    }
}
