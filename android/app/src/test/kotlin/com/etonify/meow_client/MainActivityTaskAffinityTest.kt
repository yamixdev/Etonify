package com.etonify.meow_client

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.w3c.dom.Element

class MainActivityTaskAffinityTest {
    @Test
    fun `main activity uses the default app task for external launches`() {
        val manifest = File("src/main/AndroidManifest.xml")
        val document = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }.newDocumentBuilder().parse(manifest)
        val androidNamespace = "http://schemas.android.com/apk/res/android"
        val activities = document.getElementsByTagName("activity")
        val mainActivity = (0 until activities.length)
            .map { activities.item(it) as Element }
            .firstOrNull { it.getAttributeNS(androidNamespace, "name") == ".MainActivity" }

        assertNotNull("MainActivity must be declared in the manifest", mainActivity)
        assertFalse(
            "An explicit empty affinity makes notification and tile launches create another recent task",
            mainActivity!!.hasAttributeNS(androidNamespace, "taskAffinity"),
        )
    }
}
