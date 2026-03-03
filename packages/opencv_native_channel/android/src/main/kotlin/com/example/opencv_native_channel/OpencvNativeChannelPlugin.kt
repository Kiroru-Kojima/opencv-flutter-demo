package com.example.opencv_native_channel

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.opencv.android.OpenCVLoader
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.imgproc.Imgproc

/** OpencvNativeChannelPlugin */
class OpencvNativeChannelPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var openCvReady: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "opencv_native_channel")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "cannyBgrToRgba" -> handleCanny(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun ensureOpenCv(result: Result): Boolean {
        if (openCvReady) return true
        openCvReady = OpenCVLoader.initLocal()
        if (!openCvReady) {
            result.error("OPENCV_INIT", "OpenCVLoader.initLocal() failed", null)
        }
        return openCvReady
    }

    private fun handleCanny(call: MethodCall, result: Result) {
        if (!ensureOpenCv(result)) return

        val bgr = call.argument<ByteArray>("bgr")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val threshold1 = call.argument<Double>("threshold1")
        val threshold2 = call.argument<Double>("threshold2")
        val apertureSize = call.argument<Int>("apertureSize") ?: 3
        val l2gradient = call.argument<Boolean>("l2gradient") ?: false

        if (bgr == null || width == null || height == null || threshold1 == null || threshold2 == null) {
            result.error("BAD_ARGS", "Missing arguments", null)
            return
        }
        val expected = width * height * 3
        if (bgr.size != expected) {
            result.error("BAD_ARGS", "bgr length mismatch (expected=$expected actual=${bgr.size})", null)
            return
        }

        var src: Mat? = null
        var gray: Mat? = null
        var edges: Mat? = null
        var rgba: Mat? = null
        try {
            src = Mat(height, width, CvType.CV_8UC3)
            src.put(0, 0, bgr)

            gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)

            edges = Mat()
            Imgproc.Canny(gray, edges, threshold1, threshold2, apertureSize, l2gradient)

            rgba = Mat()
            Imgproc.cvtColor(edges, rgba, Imgproc.COLOR_GRAY2RGBA)

            val out = ByteArray(width * height * 4)
            rgba.get(0, 0, out)
            result.success(out)
        } catch (e: Throwable) {
            result.error("OPENCV_ERROR", e.message, null)
        } finally {
            src?.release()
            gray?.release()
            edges?.release()
            rgba?.release()
        }
    }
}
