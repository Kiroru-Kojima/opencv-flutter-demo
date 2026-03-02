# OpenCV 導入・比較メモ（iOS / Android / Flutter）

## 1. iOSでの導入（CocoaPods / SPM）

### CocoaPods
- **手軽**: `OpenCV-Dynamic-Framework`（xcframework配布）をPod依存にするのが簡単です  
  - 例: このリポジトリの `packages/opencv_channel/ios/opencv_channel.podspec`
- **注意**: CocoaPods上の `OpenCV` というPodもありますが、バージョンが古い場合があります（採用前に要確認）

参考:
- [OpenCV-Dynamic-Framework (CocoaPods)](https://cocoapods.org/pods/OpenCV-Dynamic-Framework)
- [OpenCV (CocoaPods)](https://cocoapods.org/pods/OpenCV)

### SPM（Swift Package Manager）
- **OpenCV公式としてSPM対応が整備されている状況ではない**ため、現実的には以下のどれかになります
  - サードパーティのSPMラッパーを採用（更新頻度・iOS対応・xcframework内容を要確認）
  - 自前でOpenCVをビルドして `opencv2.xcframework` を生成し、SPMのバイナリターゲットで配布

参考:
- [yeatse/opencv-spm](https://github.com/yeatse/opencv-spm)

## 2. Androidでの導入（Gradle / NDK）

### Gradle（Java/Kotlin API）
- **最短ルート**: Maven CentralのOpenCVを依存追加して、`org.opencv.*` APIを使う  
  - 例: このリポジトリの `packages/opencv_channel/android/build.gradle`
- 画像が `ByteArray` で渡せる範囲なら、NDK無しでもデモは作れます

参考:
- [OpenCV公式: Android Studio / Maven Central](https://docs.opencv.org/4.x/d5/df8/tutorial_dev_with_OCV_on_Android.html)

### NDK（C++ API）
- **パフォーマンス優先**ならNDK（C++）で処理し、必要最小限だけJava/Dartへ渡すのが有利になりがちです  
  - CameraXの `ImageAnalysis` → NDK処理 → 結果（矩形・点群などの小データ）だけ返す、など
- ただし、ビルド・ABI対応・バイナリサイズ・デバッグが重くなります

## 3. Flutterでの導入（既存プラグイン / 自作）

### 既存（FFI系）
- Flutter 3.38未満向け: `opencv_core`（※discontinuedだが動作用途としては利用可能）  
  - このリポジトリのFlutterアプリが使用
- Flutter 3.38以降向け: `opencv_dart` / `dartcv4`（Native Assets / hooks前提）

参考:
- [opencv_core (pub.dev)](https://pub.dev/packages/opencv_core)
- [opencv_dart (pub.dev)](https://pub.dev/packages/opencv_dart)
- [dartcv4 (pub.dev)](https://pub.dev/packages/dartcv4)

### 自作案A: Platform Channels 経由でネイティブ呼び出し
- **長所**: 既存のiOS/AndroidのOpenCV導入パターン（Pods/Gradle/NDK）をそのまま使いやすい
- **短所**: 画像バッファの受け渡しでコピー・シリアライズが発生しやすく、フレーム単位の呼び出し回数が増えるほど不利
- このリポジトリでは `packages/opencv_channel` が最小実装例です

### 自作案B: Dart FFI で直接呼び出し
- **長所**: 呼び出しオーバーヘッドが小さく、設計次第でコピー回数も抑えやすい（頻繁なフレーム処理に向く）
- **短所**: ネイティブライブラリ配布（iOS/Androidのビルド/署名/ABI）と、API設計（Cラッパ層）が必要

## 4. OpenCVで「何ができるか」（ざっくり対応表）

### 画像処理（imgproc）
- フィルタ: blur/gaussian/median/bilateral
- 色空間: BGR↔GRAY/HSV/YUV など
- 幾何変換: resize/warpAffine/warpPerspective
- エッジ/輪郭: Canny, Sobel, findContours
- 二値化: threshold/adaptiveThreshold
- モルフォロジー: erode/dilate/open/close

### 特徴点・追跡
- 特徴点: ORB/AKAZE/（SIFT等はビルド構成に依存）
- マッチング: BFMatcher/Flann（用途次第）
- オプティカルフロー: Lucas-Kanade（calcOpticalFlowPyrLK）など

### キャリブレーション・姿勢推定
- カメラキャリブレーション: calibrateCamera, undistort
- 姿勢推定: solvePnP（ARマーカー等と相性が良い）

### ステッチング / 3D
- ステッチング: stitchingモジュール
- 3Dは「全部入り」ではなく、Stereo/Calibなど中心（本格的3Dは別ライブラリ併用が現実的）

### 物体検出/分類（dnn）
- OpenCVのDNNモジュールで各種フォーマットを読み込んで推論可能（ただし**モバイル最適**は別途検討が必要）  
  - 端末最適化が強い: TensorFlow Lite / Core ML / NNAPI などを直接使う方が良いケースが多い

### 実用機能
- QR: `QRCodeDetector`
- テンプレートマッチング: matchTemplate
- 顔検出（古典）: Haar Cascade など（精度要件によっては要再検討）

## 5. ライセンス（商用利用可否と注意点）

- OpenCV本体は Apache 2.0 系のライセンス（商用利用可、ただし表示・NOTICE等の条件あり）
- ただし「contrib」「同梱サードパーティ（例: 画像codec等）」は別ライセンス要素が混ざり得るため、最終的には**ビルド構成と同梱物**をもとに棚卸しが必要です

参考:
- [OpenCV License（公式）](https://opencv.org/license/)
- [opencv/opencv LICENSE (GitHub)](https://github.com/opencv/opencv/blob/4.x/LICENSE)

## 6. 「ネイティブかFlutterか」最も速い組み込み方（結論の方向性）

### 原則
- **フレームごとに重い処理を回す**なら「処理本体はネイティブ側に寄せて、Flutter側はUI」に寄せるのが有利になりやすい
- FlutterでOpenCVを使う場合でも、**FFIで頻繁に呼ぶ**か、**ネイティブでまとめて処理して小さな結果だけ返す**のが基本戦略

### Platform Channels vs FFI（ざっくり）
- 画像（数MB）を毎フレーム渡す設計だと、Platform Channelsはコピーが増えがち
- FFIは設計次第でコピー回数を抑えやすいが、配布・ビルドの難易度が上がる

## 7. 計測項目（最低限）と条件固定

### 最低限の指標
- FPS / 1フレーム処理時間（avg/p50/p90/p99）
- レイテンシ（撮影→処理→表示まで）
- メモリ（常駐＋ピーク）
- 発熱/電力（サーマルスロットリング含む）
- アプリサイズ（APK/IPA、OpenCV同梱で増えやすい）
- 起動時間（初回起動/2回目、初期化コスト）

### 条件固定（重要）
- 同一端末 / 同一OSバージョン / 同一解像度 / 同一処理内容
- Debugではなく **Release**（`--release`）で計測
- ウォームアップを入れる（JIT/キャッシュ/サーマル状態の影響を抑える）

### このリポジトリでの位置づけ
- `opencv_demo` の `Bench` は「処理関数単体の時間」をまず出すための簡易ベンチです  
  - 実運用のカメラパイプライン（YUV→RGB変換、描画、スレッド同期）込みの計測は別途追加が必要
