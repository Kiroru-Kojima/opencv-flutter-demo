import 'package:flutter/foundation.dart';

enum OpenCvBackendKind {
  ffi,
  platformChannel,
}

extension OpenCvBackendKindLabel on OpenCvBackendKind {
  String get label => switch (this) {
        OpenCvBackendKind.ffi => 'FFI (opencv_core)',
        OpenCvBackendKind.platformChannel => 'Platform Channel (native OpenCV)',
      };
}

List<OpenCvBackendKind> availableBackends() {
  if (kIsWeb) return const [OpenCvBackendKind.ffi];
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const [OpenCvBackendKind.ffi];
  }
  return OpenCvBackendKind.values;
}
