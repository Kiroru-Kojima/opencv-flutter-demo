# OpenCV Demo (Flutter / iOS / Android)

このリポジトリは「OpenCVをモバイルにどう組み込むのが良いか」を調べるためのデモです。

- Flutterアプリ: `opencv_demo`
  - `FFI (opencv_core)` と `Platform Channel (native OpenCV)` を切り替えて同一処理を実行できます
- Platform Channelプラグイン: `packages/opencv_channel`
  - Android: Maven CentralのOpenCV（Java API）を使用
  - iOS: CocoaPodsの `OpenCV-Dynamic-Framework` を使用（Objective-C++）

## 動かし方（最短）

```bash
cd opencv_demo
flutter pub get
flutter run
```

補足:
- 初回ビルドは、OpenCVの取得/ビルド（`opencv_core`）やPod/Gradle依存の取得により時間がかかる場合があります
- iOSはCocoaPodsが必要です（`OpenCV-Dynamic-Framework` をPodで取得します）
- AndroidはGradleで `org.opencv:opencv` を取得します

アプリ起動後:
- `Demo` タブ: 合成画像（チェッカーボード）→ Canny エッジ
- `Bench` タブ: 同一入力に対する処理時間分布（avg/p50/p90/p99）
- `backend` で `FFI` / `Platform Channel` を切り替え

## 調査メモ

詳細は `docs/INVESTIGATION.md` を参照してください。
