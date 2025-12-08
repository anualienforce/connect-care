package com.connectcare.connect_care_app

import android.content.Context
import android.webkit.WebChromeClient
import android.webkit.ValueCallback
import android.webkit.WebView
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.contract.ActivityResultContracts

class FileChooserWebChromeClient(
    private val context: Context,
    private val onFileSelected: (Uri?) -> Unit
) : WebChromeClient() {

    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    override fun onShowFileChooser(
        webView: WebView?,
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: FileChooserParams?
    ): Boolean {
        this.filePathCallback = filePathCallback

        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*", "application/pdf"))
        }

        try {
            (context as? android.app.Activity)?.startActivityForResult(
                Intent.createChooser(intent, "Select File"),
                FILE_CHOOSER_RESULT_CODE
            )
            return true
        } catch (e: Exception) {
            filePathCallback?.onReceiveValue(null)
            return false
        }
    }

    fun onActivityResult(resultCode: Int, data: Intent?) {
        if (resultCode == android.app.Activity.RESULT_OK && data != null) {
            val uri = data.data
            filePathCallback?.onReceiveValue(if (uri != null) arrayOf(uri) else null)
        } else {
            filePathCallback?.onReceiveValue(null)
        }
        filePathCallback = null
    }

    companion object {
        const val FILE_CHOOSER_RESULT_CODE = 1001
    }
}
