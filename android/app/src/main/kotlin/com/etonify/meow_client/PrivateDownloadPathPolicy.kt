package com.etonify.meow_client

import java.io.File

internal object PrivateDownloadPathPolicy {
    fun requireTarget(rawPath: String, privateDataDirectory: File): File {
        require(rawPath.isNotBlank()) { "Download destination is empty." }
        val destination = File(rawPath).canonicalFile
        val privateRoot = privateDataDirectory.canonicalFile
        require(destination.path.startsWith(privateRoot.path + File.separator)) {
            "Download destination must be inside private app storage."
        }
        require(!destination.isDirectory) { "Download destination is a directory." }
        return destination
    }
}
