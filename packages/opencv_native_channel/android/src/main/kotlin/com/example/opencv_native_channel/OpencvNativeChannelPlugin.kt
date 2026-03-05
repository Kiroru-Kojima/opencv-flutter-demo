package com.example.opencv_native_channel

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture

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
    private var fgBg32f: Mat? = null
    private var fgKernel: Mat? = null

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
            "cannyBgrToRgbaProfile" -> handleCannyProfile(call, result)
            "fgExtractReset" -> handleFgExtractReset(result)
            "fgExtractBgrProfile" -> handleFgExtractProfile(call, result)
            "benchmarkMp4FgExtractProfile" -> handleBenchmarkMp4FgExtractProfile(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        fgBg32f?.release()
        fgBg32f = null
        fgKernel?.release()
        fgKernel = null
    }

    private fun ensureOpenCv(result: Result): Boolean {
        if (openCvReady) return true
        openCvReady = OpenCVLoader.initLocal()
        if (!openCvReady) {
            result.error("OPENCV_INIT", "OpenCVLoader.initLocal() failed", null)
        }
        return openCvReady
    }

    private fun ensureFgKernel(): Mat {
        fgKernel?.let { return it }
        val k = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
        fgKernel = k
        return k
    }

    private fun handleFgExtractReset(result: Result) {
        fgBg32f?.release()
        fgBg32f = null
        result.success(null)
    }

    private fun handleFgExtractProfile(call: MethodCall, result: Result) {
        if (!ensureOpenCv(result)) return

        val bgr = call.argument<ByteArray>("bgr")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val alpha = call.argument<Double>("alpha") ?: 0.05
        val threshold = call.argument<Double>("threshold") ?: 25.0
        val morphIterations = call.argument<Int>("morphIterations") ?: 1

        if (bgr == null || width == null || height == null) {
            result.error("BAD_ARGS", "Missing arguments", null)
            return
        }
        val expected = width * height * 3
        if (bgr.size != expected) {
            result.error("BAD_ARGS", "bgr length mismatch (expected=$expected actual=${bgr.size})", null)
            return
        }

        fun us(deltaNs: Long): Int = (deltaNs / 1000L).toInt()

        var src: Mat? = null
        var gray: Mat? = null
        var gray32f: Mat? = null
        var bg8u: Mat? = null
        var diff: Mat? = null
        var mask: Mat? = null
        try {
            val kernel = ensureFgKernel()

            val t0 = System.nanoTime()
            src = Mat(height, width, CvType.CV_8UC3)
            val t1 = System.nanoTime()
            src.put(0, 0, bgr)
            val t2 = System.nanoTime()

            gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)
            val t3 = System.nanoTime()

            gray32f = Mat()
            gray!!.convertTo(gray32f, CvType.CV_32FC1)

            val bg = fgBg32f
            if (bg == null || bg.rows() != height || bg.cols() != width) {
                bg?.release()
                fgBg32f = gray32f!!.clone()
            } else {
                Imgproc.accumulateWeighted(gray32f!!, bg, alpha)
            }
            val t4 = System.nanoTime()

            bg8u = Mat()
            Core.convertScaleAbs(fgBg32f!!, bg8u)
            diff = Mat()
            Core.absdiff(gray!!, bg8u, diff)
            mask = Mat()
            Imgproc.threshold(diff, mask, threshold, 255.0, Imgproc.THRESH_BINARY)
            val t5 = System.nanoTime()

            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_OPEN, kernel, Point(-1.0, -1.0), morphIterations)
            val t6 = System.nanoTime()

            val fgCount = Core.countNonZero(mask)
            val t7 = System.nanoTime()

            val stages: HashMap<String, Int> =
                hashMapOf(
                    "matAllocUs" to us(t1 - t0),
                    "matPutUs" to us(t2 - t1),
                    "cvtColorGrayUs" to us(t3 - t2),
                    "bgUpdateUs" to us(t4 - t3),
                    "diffThresholdUs" to us(t5 - t4),
                    "morphUs" to us(t6 - t5),
                    "countUs" to us(t7 - t6),
                )
            val payload: HashMap<String, Any> =
                hashMapOf(
                    "fgCount" to fgCount,
                    "nativeTotalUs" to us(t7 - t0),
                    "stagesUs" to stages,
                )
            result.success(payload)
        } catch (e: Throwable) {
            result.error("OPENCV_ERROR", e.message, null)
        } finally {
            src?.release()
            gray?.release()
            gray32f?.release()
            bg8u?.release()
            diff?.release()
            mask?.release()
        }
    }

    private fun handleBenchmarkMp4FgExtractProfile(call: MethodCall, result: Result) {
        if (!ensureOpenCv(result)) return

        val path = call.argument<String>("path")
        val warmup = call.argument<Int>("warmup") ?: 10
        val iterations = call.argument<Int>("iterations") ?: 100
        val alpha = call.argument<Double>("alpha") ?: 0.05
        val threshold = call.argument<Double>("threshold") ?: 25.0
        val morphIterations = call.argument<Int>("morphIterations") ?: 1

        if (path.isNullOrBlank()) {
            result.error("BAD_ARGS", "Missing path", null)
            return
        }

        fun us(deltaNs: Long): Int = (deltaNs / 1000L).toInt()

        var cap = VideoCapture()
        if (!cap.open(path)) {
            cap.release()
            result.error("VIDEOIO_OPEN", "VideoCapture.open failed: $path", null)
            return
        }

        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
        var bg32f: Mat? = null

        val frame = Mat()
        val gray = Mat()
        val gray32f = Mat()
        val bg8u = Mat()
        val diff = Mat()
        val mask = Mat()

        fun restartCapture(): Boolean {
            cap.release()
            cap = VideoCapture()
            return cap.open(path)
        }

        fun processOne(): Int {
            Imgproc.cvtColor(frame, gray, Imgproc.COLOR_BGR2GRAY)
            gray.convertTo(gray32f, CvType.CV_32FC1)

            val bg = bg32f
            if (bg == null || bg.rows() != gray.rows() || bg.cols() != gray.cols()) {
                bg?.release()
                bg32f = gray32f.clone()
            } else {
                Imgproc.accumulateWeighted(gray32f, bg, alpha)
            }

            Core.convertScaleAbs(bg32f!!, bg8u)
            Core.absdiff(gray, bg8u, diff)
            Imgproc.threshold(diff, mask, threshold, 255.0, Imgproc.THRESH_BINARY)
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_OPEN, kernel, Point(-1.0, -1.0), morphIterations)
            return Core.countNonZero(mask)
        }

        try {
            for (i in 0 until warmup) {
                val ok = cap.read(frame) || (restartCapture() && cap.read(frame))
                if (!ok) continue
                processOne()
            }

            val totalUs = ArrayList<Int>(iterations)
            val decodeUs = ArrayList<Int>(iterations)
            val processUs = ArrayList<Int>(iterations)
            var lastFgCount: Int? = null

            for (i in 0 until iterations) {
                val t0 = System.nanoTime()

                val tDecode0 = System.nanoTime()
                var ok = cap.read(frame)
                if (!ok) {
                    ok = restartCapture() && cap.read(frame)
                }
                val tDecode1 = System.nanoTime()
                if (!ok) {
                    result.error("VIDEOIO_READ", "VideoCapture.read failed after restart", null)
                    return
                }

                val t2 = System.nanoTime()
                lastFgCount = processOne()
                val t3 = System.nanoTime()

                totalUs.add(us(t3 - t0))
                decodeUs.add(us(tDecode1 - tDecode0))
                processUs.add(us(t3 - t2))
            }

            result.success(
                hashMapOf(
                    "totalUs" to totalUs,
                    "decodeUs" to decodeUs,
                    "processUs" to processUs,
                    "lastFgCount" to lastFgCount,
                ),
            )
        } catch (e: Throwable) {
            result.error("OPENCV_ERROR", e.message, null)
        } finally {
            bg32f?.release()
            kernel.release()
            frame.release()
            gray.release()
            gray32f.release()
            bg8u.release()
            diff.release()
            mask.release()
            cap.release()
        }
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

    private fun handleCannyProfile(call: MethodCall, result: Result) {
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

        fun us(deltaNs: Long): Int = (deltaNs / 1000L).toInt()

        var src: Mat? = null
        var gray: Mat? = null
        var edges: Mat? = null
        var rgba: Mat? = null
        try {
            val t0 = System.nanoTime()
            src = Mat(height, width, CvType.CV_8UC3)
            val t1 = System.nanoTime()
            src.put(0, 0, bgr)
            val t2 = System.nanoTime()

            gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)
            val t3 = System.nanoTime()

            edges = Mat()
            Imgproc.Canny(gray, edges, threshold1, threshold2, apertureSize, l2gradient)
            val t4 = System.nanoTime()

            rgba = Mat()
            Imgproc.cvtColor(edges, rgba, Imgproc.COLOR_GRAY2RGBA)
            val t5 = System.nanoTime()

            val out = ByteArray(width * height * 4)
            rgba.get(0, 0, out)
            val t6 = System.nanoTime()

            val stages: HashMap<String, Int> =
                hashMapOf(
                    "matAllocUs" to us(t1 - t0),
                    "matPutUs" to us(t2 - t1),
                    "cvtColorGrayUs" to us(t3 - t2),
                    "cannyUs" to us(t4 - t3),
                    "cvtColorRgbaUs" to us(t5 - t4),
                    "matGetUs" to us(t6 - t5),
                )

            val nativeTotalUs = us(t6 - t0)
            val payload: HashMap<String, Any> =
                hashMapOf(
                    "rgba" to out,
                    "nativeTotalUs" to nativeTotalUs,
                    "stagesUs" to stages,
                )
            result.success(payload)
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
