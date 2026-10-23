import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

abstract final class AppSecureStorage {
  static const FlutterSecureStorage instance = appSecureStorage;
}
