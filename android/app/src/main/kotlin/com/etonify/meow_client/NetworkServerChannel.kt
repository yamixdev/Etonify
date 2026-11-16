package com.etonify.meow_client

import com.etonify.meow_client.generated.FlutterError
import com.etonify.meow_client.generated.NetworkServerHostApi
import com.etonify.meow_client.generated.NetworkServerKind
import com.etonify.meow_client.generated.NetworkServerSettingsMessage
import com.etonify.meow_client.singbox.MeowBoxService
import com.etonify.meow_client.singbox.MeowDefaultNetworkMonitor
import com.etonify.meow_client.singbox.NetworkServerPolicy
import com.etonify.meow_client.singbox.NetworkServerPreferences
import com.etonify.meow_client.singbox.RuntimeServiceModeResolver
import com.etonify.meow_client.singbox.ServerNetwork
import com.etonify.meow_client.singbox.SingboxController

internal object NetworkServerChannel : NetworkServerHostApi {
    override fun read(profileId: String, callback: (Result<NetworkServerSettingsMessage>) -> Unit) {
        callback(runCatching { NetworkServerPreferences.read(profileId).toMessage() })
    }

    override fun setEnabled(
        profileId: String,
        enabled: Boolean,
        callback: (Result<NetworkServerSettingsMessage>) -> Unit,
    ) {
        MeowBoxService.updateNetworkServerPolicy(
            update = { NetworkServerPreferences.setEnabled(profileId, enabled) },
            callback = policyResult(callback),
        )
    }

    override fun setRemember(
        profileId: String,
        remember: Boolean,
        callback: (Result<NetworkServerSettingsMessage>) -> Unit,
    ) {
        MeowBoxService.updateNetworkServerPolicy(
            update = { NetworkServerPreferences.setRemember(profileId, remember) },
            callback = policyResult(callback),
        )
    }

    override fun setConfigured(
        profileId: String,
        network: NetworkServerKind,
        tag: String?,
        callback: (Result<NetworkServerSettingsMessage>) -> Unit,
    ) {
        if (profileId.isBlank()) {
            callback(Result.failure(FlutterError("invalid_policy", "Missing subscription")))
            return
        }
        val serverNetwork = when (network) {
            NetworkServerKind.WIFI -> ServerNetwork.WIFI
            NetworkServerKind.MOBILE -> ServerNetwork.MOBILE
        }
        MeowBoxService.updateNetworkServerPolicy(
            profileId = profileId,
            onlyNetwork = serverNetwork,
            update = { NetworkServerPreferences.setConfigured(profileId, serverNetwork, tag) },
            callback = policyResult(callback),
        )
    }

    override fun selectManual(profileId: String, tag: String, callback: (Result<Unit>) -> Unit) =
        selectOutbound(profileId, tag, callback)

    override fun reassertAfterStart(tag: String, callback: (Result<Unit>) -> Unit) =
        selectOutbound(null, tag, callback)

    override fun rememberOffline(profileId: String, tag: String, callback: (Result<Unit>) -> Unit) {
        callback(runCatching {
            if (profileId.isNotBlank() && tag.isNotBlank() &&
                NetworkServerPreferences.read(profileId).let { it.enabled && it.remember } &&
                SingboxController.serviceMode != RuntimeServiceModeResolver.VPN &&
                !MeowBoxService.hasActiveRuntimeOwner(RuntimeServiceModeResolver.VPN)
            ) {
                val network = MeowDefaultNetworkMonitor.offlineServerNetworkSnapshot()
                NetworkServerPreferences.remember(profileId, tag, network, network)
            }
        })
    }

    private fun selectOutbound(profileId: String?, tag: String, callback: (Result<Unit>) -> Unit) {
        if (profileId?.isBlank() == true || tag.isBlank()) {
            callback(Result.failure(FlutterError("invalid_selection", "Missing subscription or outbound")))
            return
        }
        val complete: (Result<Unit>) -> Unit = { selection ->
            callback(selection.recoverCatching { throw FlutterError("select_failed", it.message) })
        }
        if (MeowBoxService.selectVpnOutbound(tag, profileId, complete)) return
        if (SingboxController.serviceMode == RuntimeServiceModeResolver.VPN) {
            callback(Result.failure(FlutterError("select_failed", "VPN runtime is changing")))
        } else {
            SingboxController.selectOutbound("select", tag, complete)
        }
    }

    private fun policyResult(
        callback: (Result<NetworkServerSettingsMessage>) -> Unit,
    ): (Result<NetworkServerPolicy>) -> Unit = { result ->
        callback(result.map { it.toMessage() }.recoverCatching { throw FlutterError("update_failed", it.message) })
    }

    private fun NetworkServerPolicy.toMessage() = NetworkServerSettingsMessage(
        enabled = enabled,
        remember = remember,
        configuredWifi = configured[ServerNetwork.WIFI],
        configuredMobile = configured[ServerNetwork.MOBILE],
        rememberedWifi = remembered[ServerNetwork.WIFI],
        rememberedMobile = remembered[ServerNetwork.MOBILE],
    )
}
