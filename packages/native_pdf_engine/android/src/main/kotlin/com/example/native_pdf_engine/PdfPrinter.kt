package com.example.native_pdf_engine

import android.os.Build
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient
import android.print.PrintCallbackShim
import java.io.File

class PdfPrinter(private val printAttributes: PrintAttributes) {

    interface Callback {
        fun onSuccess(filePath: String)
        fun onFailure()
    }

    fun print(
        printAdapter: PrintDocumentAdapter,
        path: File,
        fileName: String,
        callback: Callback
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val layoutCallback = object : PrintCallbackShim.LayoutCallback {
                override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) {
                    val writeCallbackProxy = object : PrintCallbackShim.WriteCallback {
                        override fun onWriteFinished(pages: Array<PageRange>) {
                            if (pages.isEmpty()) {
                                callback.onFailure()
                                return
                            }
                            File(path, fileName).let {
                                callback.onSuccess(it.absolutePath)
                            }
                        }

                        override fun onWriteFailed(error: CharSequence?) {
                            callback.onFailure()
                        }

                        override fun onWriteCancelled() {
                            callback.onFailure()
                        }
                    }

                    printAdapter.onWrite(
                        arrayOf(PageRange.ALL_PAGES),
                        getOutputFile(path, fileName),
                        CancellationSignal(),
                        PrintCallbackShim.createWriteResultCallback(writeCallbackProxy)
                    )
                }

                override fun onLayoutFailed(error: CharSequence?) {
                    callback.onFailure()
                }

                override fun onLayoutCancelled() {
                    callback.onFailure()
                }
            }

            printAdapter.onLayout(
                null,
                printAttributes,
                null,
                PrintCallbackShim.createLayoutResultCallback(layoutCallback),
                Bundle()
            )
        } else {
            callback.onFailure()
        }
    }

    fun prepareWebView(
        webView: WebView,
        path: File,
        fileName: String,
        callback: Callback
    ) {
        val uiThreadRunnable = Runnable {
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    super.onPageFinished(view, url)
                    view.postDelayed({
                        val adapter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            webView.createPrintDocumentAdapter(fileName)
                        } else {
                            webView.createPrintDocumentAdapter()
                        }
                        print(adapter, path, fileName, callback)
                    }, 500)
                }
            }
        }

        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            uiThreadRunnable.run()
        } else {
            webView.post(uiThreadRunnable)
        }
    }

    fun printFromWebView(
        webView: WebView,
        path: File,
        fileName: String,
        callback: Callback
    ) {
        // Keeping for backward compatibility but prepareWebView is preferred to set client BEFORE loading
        prepareWebView(webView, path, fileName, callback)
    }

    private fun getOutputFile(path: File, fileName: String): ParcelFileDescriptor {
        if (!path.exists()) {
            path.mkdirs()
        }

        File(path, fileName).let {
            if (it.exists()) {
                it.delete()
            }
            it.createNewFile()
            return ParcelFileDescriptor.open(it, ParcelFileDescriptor.MODE_READ_WRITE)
        }
    }
}
