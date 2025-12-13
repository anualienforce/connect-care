package com.connectcare.connect_care_app

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.net.Uri
import android.webkit.WebView
import android.webkit.GeolocationPermissions
import android.os.Build

class MainActivity : FlutterActivity() {
    
    companion object {
        init {
            // Enable geolocation database path
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                val dbPath = "/data/data/com.connectcare.connect_care_app/databases"
                GeolocationPermissions.getInstance().clear(dbPath)
            }
        }
    }
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Disable WebView debugging in release mode
        WebView.setWebContentsDebuggingEnabled(false)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == 1001) { // FILE_CHOOSER_RESULT_CODE
            // Handle file chooser result
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}

