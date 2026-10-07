package com.example.anything_hub

import android.content.Context
import android.content.Intent

/**
 * Integra con Termux RUN_COMMAND (si Termux está instalado).
 */
object TermuxHelper {

    fun runCommand(
        context: Context,
        command: String,
        workdir: String,
        background: Boolean,
    ): Boolean {
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
