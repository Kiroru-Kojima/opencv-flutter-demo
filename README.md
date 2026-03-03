# OpenCV Demo (Flutter / iOS / Android)

このリポジトリは「OpenCVをモバイルにどう組み込むのが良いか」を調べるためのデモです。

- Flutterアプリ（opencv_dart方式）: `opencv_demo`
  - `FFI (opencv_dart)` を使って同一処理を実行
- Flutterアプリ（ネイティブOpenCV方式）: `opencv_native_demo`
  - `Platform Channel (native OpenCV)` のみ（`packages/opencv_native_channel`）

- Platform Channelプラグイン（iOS/Android）: `packages/opencv_native_channel`
  - iOS: CocoaPodsの `OpenCV-Dynamic-Framework`（Objective-C++）
  - Android: Maven CentralのOpenCV（Java API）

## 動かし方（最短）

```bash
cd opencv_demo
flutter pub get
flutter run
```

ネイティブOpenCV方式:
```bash
cd opencv_native_demo
flutter pub get
flutter run
```

補足:
- 初回ビルドは、Pod/Gradle依存の取得により時間がかかる場合があります
- `opencv_native_demo`（iOS）はCocoaPodsで `OpenCV-Dynamic-Framework` を取得します
- AndroidはGradleで `org.opencv:opencv` を取得します

アプリ起動後（両アプリ共通）:
- `Demo` タブ: 合成画像（チェッカーボード）→ Canny エッジ
- `Bench` タブ: 同一入力に対する処理時間分布（avg/p50/p90/p99）

比較する場合:
- 同一端末で `opencv_demo` と `opencv_native_demo` の `Bench` を実行し、数値を比較します

## 調査メモ

詳細は `docs/INVESTIGATION.md` を参照してください。
