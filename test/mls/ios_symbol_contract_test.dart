import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'OpenMLS symbols belong only to the independent TataChatSDK library',
    () {
      final chatSdkScript = File('scripts/build-native.sh').readAsStringSync();
      final chatSdkHeader = File('scripts/tatachat_sdk.h').readAsStringSync();
      final chatSdkPodspec = File('ios/tatachat_sdk.podspec')
          .readAsStringSync();
      final privacyManifest = File('ios/PrivacyInfo.xcprivacy')
          .readAsStringSync();
      final platformPlugin = File('ios/TataChatSdkPlugin.swift')
          .readAsStringSync();
      final package = File('pubspec.yaml').readAsStringSync();
      final loader = File('lib/mls/mls_native.dart').readAsStringSync();

      expect(
        chatSdkScript,
        contains('tatachat_sdk_mls_create_key_package_json'),
      );
      expect(
        chatSdkScript,
        contains('tatachat_sdk_mls_group_create_message_json'),
      );
      expect(chatSdkScript, contains('tatachat_sdk_mls_group_process_json'));
      expect(chatSdkScript, contains('TataChatSDK.xcframework'));
      expect(chatSdkScript, contains('libtatachat_sdk.dylib'));
      expect(chatSdkScript, contains('-C strip=none'));
      expect(chatSdkScript, contains(r'file -b "$library"'));
      expect(chatSdkScript, contains('nm_args=(-D --defined-only)'));
      expect(chatSdkScript, contains('string_offset % 8'));
      expect(chatSdkScript, contains('TATACHATSDK_NATIVE_IOS_DIR'));
      expect(chatSdkScript, isNot(contains('install_name_tool')));
      expect(chatSdkScript, isNot(contains(r'$ROOT/ios/libtatachat_sdk.a')));
      expect(
        chatSdkHeader,
        contains('tatachat_sdk_mls_create_key_package_json'),
      );
      expect(chatSdkHeader, contains('tatachat_sdk_mls_identity_json'));
      expect(chatSdkHeader, contains('tatachat_sdk_mls_store_json'));
      expect(
        chatSdkHeader,
        isNot(contains('tatachat_sdk_mls_rekey_state_json')),
      );
      expect(
        chatSdkHeader,
        isNot(contains('tatachat_sdk_mls_two_party_smoke_json')),
      );
      expect(chatSdkScript, contains('tatachat_sdk_mls_identity_json'));
      expect(chatSdkScript, contains('tatachat_sdk_mls_store_json'));
      expect(chatSdkScript, contains('mls_rekey_state|mls_two_party_smoke'));
      expect(platformPlugin, contains('prepareMlsStorage'));
      expect(chatSdkHeader, contains('tatachat_sdk_mls_group_create_json'));
      expect(
        chatSdkHeader,
        contains('tatachat_sdk_mls_group_add_members_json'),
      );
      expect(
        chatSdkHeader,
        contains('tatachat_sdk_mls_group_remove_members_json'),
      );
      expect(
        chatSdkHeader,
        contains('tatachat_sdk_mls_group_create_message_json'),
      );
      expect(chatSdkHeader, contains('tatachat_sdk_mls_group_process_json'));
      expect(chatSdkHeader, contains('tatachat_sdk_mls_group_state_json'));
      expect(
        chatSdkHeader,
        isNot(contains('tatachat_sdk_device_identity_json')),
      );
      expect(chatSdkHeader, isNot(contains('tatachat_sdk_mls_encrypt_json')));
      expect(chatSdkHeader, isNot(contains('tatachat_sdk_mls_decrypt_json')));
      expect(chatSdkPodspec, contains("spec.name = 'tatachat_sdk'"));
      expect(
        chatSdkPodspec,
        contains('spec.vendored_frameworks = framework_path'),
      );
      expect(
        chatSdkPodspec,
        contains("framework_path = 'TataChatSDK.xcframework'"),
      );
      expect(
        chatSdkPodspec,
        isNot(contains('TATACHATSDK_APPLE_FRAMEWORK_DIR')),
      );
      expect(chatSdkPodspec, isNot(contains('relative_path_from')));
      expect(chatSdkPodspec, isNot(contains('vendored_libraries')));
      expect(
        chatSdkPodspec,
        contains("spec.source_files = 'TataChatSdkPlugin.swift'"),
      );
      expect(chatSdkPodspec, contains("spec.dependency 'Flutter'"));
      expect(
        chatSdkPodspec,
        contains("spec.frameworks = 'AVFoundation', 'UIKit'"),
      );
      expect(chatSdkPodspec, isNot(contains('framework_pattern')));
      expect(chatSdkPodspec, contains("'tatachat_sdk_privacy'"));
      expect(chatSdkPodspec, contains("['PrivacyInfo.xcprivacy']"));
      expect(platformPlugin, contains('AVAssetImageGenerator'));
      expect(platformPlugin, contains('maximumSize = CGSize(width: 64'));
      expect(platformPlugin, contains('chat.tata.sdk/attachment'));
      expect(platformPlugin, contains('UIDocumentPickerViewController'));
      expect(
        platformPlugin,
        contains('maximumSelectedBytes: Int64 = 512 * 1024 * 1024'),
      );
      // 生成的宿主registrant不属于SDK；iOS只保留唯一平台插件、框架合同和真实隐私清单。
      expect(Directory('ios/Runner').existsSync(), isFalse);
      expect(Directory('ios/Flutter').existsSync(), isFalse);
      expect(privacyManifest, contains('<key>NSPrivacyTracking</key>'));
      expect(privacyManifest, contains('<false/>'));
      expect(
        privacyManifest,
        contains('<key>NSPrivacyCollectedDataTypes</key>'),
      );
      expect(privacyManifest, contains('<key>NSPrivacyAccessedAPITypes</key>'));
      expect(privacyManifest, isNot(contains('<true/>')));
      expect(privacyManifest, isNot(contains('<string>')));
      expect(package, contains('ffiPlugin: true'));
      expect(loader, contains('TataChatSDK 自己的 CocoaPods 目标'));
      expect(File('ios/tatachat_sdk_ffi.podspec').existsSync(), isFalse);
      expect(File('ios/placeholder.m').existsSync(), isFalse);
    },
  );
}
