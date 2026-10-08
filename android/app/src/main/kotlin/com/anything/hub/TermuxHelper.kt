package com.anything.hub

import android.content.Context
import android.content.Intent

/**
 * Integra con Termux RUN_COMMAND (si Termux está instalado).
 */
object TermuxHelper {

    /** Límite duro de longitud de comando (mitiga abuse / DoS vía channel). */
    private const val MAX_COMMAND_CHARS = 8_192
    private const val MAX_WORKDIR_CHARS = 1_024

    fun runCommand(
        context: Context,
        command: String,
        workdir: String,
        background: Boolean,
    ): Boolean {
        if (command.isBlank()) return false
        if (command.length > MAX_COMMAND_CHARS) return false
        if (command.contains('\u0000')) return false
        if (workdir.length > MAX_WORKDIR_CHARS) return false
        if (workdir.contains('\u0000')) return false

        return try {
            val intent = Intent().apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                action = "com.termux.RUN_COMMAND"
                putExtra(
                    "com.termux.RUN_COMMAND_PATH",
                    "/data/data/com.termux/files/usr/bin/bash"
                )
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", command))
                if (workdir.isNotEmpty()) {
                    putExtra("com.termux.RUN_COMMAND_WORKDIR", workdir)
                }
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", background)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            context.startService(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
