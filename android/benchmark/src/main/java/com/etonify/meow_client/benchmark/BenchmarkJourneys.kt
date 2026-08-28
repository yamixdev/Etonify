package com.etonify.meow_client.benchmark

import android.os.SystemClock
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until

internal const val TARGET_PACKAGE = "com.etonify.meow_client"
private const val UI_TIMEOUT_MS = 10_000L

internal fun vpnConnectionBenchmarkEnabled(): Boolean =
    InstrumentationRegistry.getArguments()
        .getString("etonifyBenchmarkConnectVpn")
        ?.toBooleanStrictOrNull() == true

internal fun MacrobenchmarkScope.launchEtonify() {
    pressHome()
    startActivityAndWait()
    device.wait(Until.hasObject(By.pkg(TARGET_PACKAGE).depth(0)), UI_TIMEOUT_MS)
    device.waitForIdle()
}

internal fun MacrobenchmarkScope.prepareMainScreen() {
    launchEtonify()
    device.clickFirst(
        By.textContains("Continue"),
        By.textContains("Продолжить"),
        By.descContains("Continue"),
    )
    device.clickFirst(
        By.textContains("Accept"),
        By.textContains("Принять"),
        By.descContains("Accept"),
    )
    device.waitForIdle()
}

internal fun MacrobenchmarkScope.openSettingsAndReturn() {
    val settings = device.findFirst(
        By.descContains("Settings"),
        By.descContains("Настройки"),
        By.text("Settings"),
        By.text("Настройки"),
    ) ?: return
    settings.click()
    device.waitForIdle()
    device.pressBack()
    device.waitForIdle()
}

internal fun MacrobenchmarkScope.tryConnectVpn() {
    val connect = device.findFirst(
        By.textContains("Tap to connect"),
        By.textContains("Нажмите для подключения"),
        By.descContains("Tap to connect"),
        By.descContains("Нажмите для подключения"),
    ) ?: return
    connect.click()
    SystemClock.sleep(750)
    device.pressBackIfPermissionDialogIsVisible()
    device.waitForIdle()
}

internal fun MacrobenchmarkScope.openAndScrollProxyList() {
    val width = device.displayWidth
    val height = device.displayHeight
    device.swipe(width / 2, height - 24, width / 2, height / 3, 12)
    device.waitForIdle()
    repeat(4) {
        device.swipe(width / 2, height * 4 / 5, width / 2, height / 3, 10)
    }
    device.waitForIdle()
}

internal fun MacrobenchmarkScope.exerciseProxyPanel(repetitions: Int = 20) {
    val width = device.displayWidth
    val height = device.displayHeight
    repeat(repetitions) {
        device.swipe(width / 2, height - 24, width / 2, height / 3, 12)
        device.waitForIdle()
        repeat(3) {
            device.swipe(width / 2, height * 4 / 5, width / 2, height / 3, 10)
        }
        device.pressBack()
        device.waitForIdle()
    }
}

private fun UiDevice.clickFirst(vararg selectors: androidx.test.uiautomator.BySelector) {
    findFirst(*selectors)?.click()
    waitForIdle()
}

private fun UiDevice.findFirst(
    vararg selectors: androidx.test.uiautomator.BySelector,
): UiObject2? {
    for (selector in selectors) {
        val result = wait(Until.findObject(selector), 500)
        if (result != null) {
            return result
        }
    }
    return null
}

private fun UiDevice.pressBackIfPermissionDialogIsVisible() {
    val permissionDialog = findFirst(
        By.res("android", "button2"),
        By.textContains("Cancel"),
        By.textContains("Отмена"),
    )
    if (permissionDialog != null) {
        pressBack()
    }
}
