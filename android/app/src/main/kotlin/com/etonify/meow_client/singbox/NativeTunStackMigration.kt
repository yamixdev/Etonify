package com.etonify.meow_client.singbox

import org.json.JSONObject

/** Also covers cached configs launched by the tile without opening Flutter. */
internal fun migrateNativeTunStack(inbound: JSONObject): Boolean {
    if (inbound.optString("type") != "tun" || !inbound.has("stack")) return false
    inbound.remove("stack")
    return true
}
