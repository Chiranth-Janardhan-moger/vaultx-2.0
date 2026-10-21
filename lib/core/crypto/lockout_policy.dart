import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vaultx/core/storage/app_secure_storage.dart';

/// Status of the lockout policy evaluation.
class LockoutStatus {
  final int failedAttempts;
  final int maxAttempts;
  final bool isWiped;
  final bool isLockedOut;
  final Duration remainingLockout;

  const LockoutStatus({
    required this.failedAttempts,
    required this.maxAttempts,
    required this.isWiped,
    required this.isLockedOut,
    required this.remainingLockout,
  });

  int get remainingAttempts => max(0, maxAttempts - failedAttempts);
}

/// Manages failed unlock attempt counting, progressive time delays, and vault wipe enforcement.
class AuthLockoutPolicy {
  static const String _keyFailedAttempts = 'vaultx_failed_attempts';
  static const String _keyLockoutUntil = 'vaultx_lockout_until';
  static const String _keyLastObservedTime = 'vaultx_last_observed_time';

  final FlutterSecureStorage _storage;
  final int maxAttemptsBeforeWipe;
  final int attemptsBeforeDelay;
  final Future<void> Function()? onWipeVault;

  Stopwatch? _activeLockoutStopwatch;
  Duration? _activeLockoutDuration;

  AuthLockoutPolicy({
    FlutterSecureStorage? storage,
    this.maxAttemptsBeforeWipe = 10,
    this.attemptsBeforeDelay = 3,
    this.onWipeVault,
  }) : _storage = storage ?? AppSecureStorage.instance;

  /// Calculates progressive delay based on consecutive failed attempts.
  Duration calculateLockoutDuration(int failedCount) {
    if (failedCount < attemptsBeforeDelay) {
      return Duration.zero;
    }
    switch (failedCount) {
      case 3:
        return const Duration(seconds: 30);
      case 4:
        return const Duration(minutes: 1);
      case 5:
        return const Duration(minutes: 5);
      case 6:
        return const Duration(minutes: 15);
      case 7:
        return const Duration(minutes: 30);
      case 8:
        return const Duration(hours: 1);
      case 9:
        return const Duration(hours: 2);
      default:
        return const Duration(hours: 24);
    }
  }

  /// Queries the current lockout state.
  Future<LockoutStatus> getStatus() async {
    final attemptsStr = await _storage.read(key: _keyFailedAttempts);
    final failedAttempts = int.tryParse(attemptsStr ?? '0') ?? 0;

    final untilStr = await _storage.read(key: _keyLockoutUntil);
    final lockoutUntil = untilStr != null ? DateTime.tryParse(untilStr) : null;

    final lastObservedStr = await _storage.read(key: _keyLastObservedTime);
    final lastObserved = lastObservedStr != null ? DateTime.tryParse(lastObservedStr) : null;

    final now = DateTime.now();
    bool isLockedOut = false;
    Duration remaining = Duration.zero;

    // Check in-memory monotonic stopwatch (cannot be bypassed by modifying device wall-clock)
    if (_activeLockoutStopwatch != null && _activeLockoutDuration != null) {
      final elapsed = _activeLockoutStopwatch!.elapsed;
      if (elapsed < _activeLockoutDuration!) {
        isLockedOut = true;
        remaining = _activeLockoutDuration! - elapsed;
      } else {
        _activeLockoutStopwatch = null;
        _activeLockoutDuration = null;
      }
    }

    if (!isLockedOut && lockoutUntil != null) {
      if (lastObserved != null && now.isBefore(lastObserved)) {
        // Clock rollback detected: maintain lockout against last observed forward time
        isLockedOut = true;
        remaining = lockoutUntil.difference(lastObserved);
        if (remaining.isNegative) remaining = const Duration(seconds: 30);
      } else if (lockoutUntil.isAfter(now)) {
        isLockedOut = true;
        remaining = lockoutUntil.difference(now);
      }
    }

    if (lockoutUntil != null && isLockedOut) {
      await _storage.write(key: _keyLastObservedTime, value: now.toIso8601String());
    }

    final isWiped = failedAttempts >= maxAttemptsBeforeWipe;

    return LockoutStatus(
      failedAttempts: failedAttempts,
      maxAttempts: maxAttemptsBeforeWipe,
      isWiped: isWiped,
      isLockedOut: isLockedOut,
      remainingLockout: remaining,
    );
  }

  /// Records a failed authentication attempt.
  ///
  /// Increments failure counter, applies progressive delay, and triggers [onWipeVault]
  /// if [maxAttemptsBeforeWipe] is reached.
  Future<LockoutStatus> recordFailedAttempt() async {
    final currentStatus = await getStatus();
    final newCount = currentStatus.failedAttempts + 1;

    await _storage.write(key: _keyFailedAttempts, value: newCount.toString());

    if (newCount >= maxAttemptsBeforeWipe) {
      // Threshold reached -> trigger wipe
      if (onWipeVault != null) {
        await onWipeVault!();
      }
      return LockoutStatus(
        failedAttempts: newCount,
        maxAttempts: maxAttemptsBeforeWipe,
        isWiped: true,
        isLockedOut: true,
        remainingLockout: Duration.zero,
      );
    }

    // Compute lockout delay
    final delay = calculateLockoutDuration(newCount);
    if (delay > Duration.zero) {
      final now = DateTime.now();
      final lockoutUntil = now.add(delay);
      await _storage.write(key: _keyLockoutUntil, value: lockoutUntil.toIso8601String());
      await _storage.write(key: _keyLastObservedTime, value: now.toIso8601String());
      _activeLockoutDuration = delay;
      _activeLockoutStopwatch = Stopwatch()..start();
      return LockoutStatus(
        failedAttempts: newCount,
        maxAttempts: maxAttemptsBeforeWipe,
        isWiped: false,
        isLockedOut: true,
        remainingLockout: delay,
      );
    }

    return LockoutStatus(
      failedAttempts: newCount,
      maxAttempts: maxAttemptsBeforeWipe,
      isWiped: false,
      isLockedOut: false,
      remainingLockout: Duration.zero,
    );
  }

  /// Clears failed attempt counters upon successful authentication.
  Future<void> recordSuccessfulAuth() async {
    _activeLockoutStopwatch = null;
    _activeLockoutDuration = null;
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockoutUntil);
    await _storage.delete(key: _keyLastObservedTime);
  }

  /// Manually resets policy state.
  Future<void> reset() async {
    await recordSuccessfulAuth();
  }
}
