part of flutter_secure_storage;

/// Specific options for iOS platform.
class IOSOptions extends AppleOptions {
  const IOSOptions({
    String? groupId,
    String? accountName,
    KeychainAccessibility accessibility = KeychainAccessibility.unlocked,
    bool? synchronizable,
  }) : super(
          groupId: groupId,
          accountName: accountName,
          accessibility: accessibility,
          synchronizable: synchronizable,
        );

  static const IOSOptions defaultOptions = IOSOptions();

  IOSOptions copyWith({
    String? groupId,
    String? accountName,
    KeychainAccessibility? accessibility,
    bool? synchronizable,
  }) =>
      IOSOptions(
        groupId: groupId ?? _groupId,
        accountName: accountName ?? _accountName,
        accessibility: accessibility ?? _accessibility,
        synchronizable: synchronizable,
      );
}
