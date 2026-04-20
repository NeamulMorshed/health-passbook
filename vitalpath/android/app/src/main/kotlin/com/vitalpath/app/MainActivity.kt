package com.vitalpath.app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * VitalPath MainActivity.
 *
 * Extends FlutterFragmentActivity (not FlutterActivity) to support:
 * - Biometric authentication fragments (local_auth package)
 * - Bottom sheet fragments (modal_bottom_sheet)
 *
 * The actual app logic runs entirely in Flutter/Dart.
 */
class MainActivity : FlutterFragmentActivity()
