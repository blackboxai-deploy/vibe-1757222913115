import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/device_info.dart';
import '../models/user.dart';

class BluetoothService extends StateNotifier<BluetoothState> {
  BluetoothService() : super(const BluetoothState()) {
    _initialize();
  }

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  
  static const String serviceUuid = '12345678-1234-5678-9abc-123456789abc';
  static const String characteristicUuid = '87654321-4321-8765-cbab-987654321abc';
  
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _advertisingTimer;
  Timer? _scanTimeoutTimer;
  
  final Map<String, BleDevice> _discoveredDevices = {};
  final Map<String, DateTime> _deviceLastSeen = {};

  void _initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        _logger.e('Bluetooth not supported by this device');
        state = state.copyWith(
          isSupported: false,
          error: 'Bluetooth not supported on this device',
        );
        return;
      }

      // Listen to adapter state changes
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((adapterState) {
        _logger.i('Bluetooth adapter state: $adapterState');
        state = state.copyWith(
          adapterState: adapterState,
          isEnabled: adapterState == BluetoothAdapterState.on,
        );
      });

      // Get initial state
      final initialState = await FlutterBluePlus.adapterState.first;
      state = state.copyWith(
        isSupported: true,
        adapterState: initialState,
        isEnabled: initialState == BluetoothAdapterState.on,
      );

    } catch (e) {
      _logger.e('Error initializing Bluetooth: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  // Student App: Start advertising BLE signal
  Future<void> startAdvertising(User user) async {
    try {
      if (!state.isEnabled) {
        throw Exception('Bluetooth is not enabled');
      }

      if (Platform.isAndroid) {
        await _startAndroidAdvertising(user);
      } else if (Platform.isIOS) {
        await _startIOSAdvertising(user);
      }

      state = state.copyWith(
        isAdvertising: true,
        advertisingUserId: user.id,
      );

      _logger.i('Started advertising for user: ${user.id}');

    } catch (e) {
      _logger.e('Error starting advertising: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _startAndroidAdvertising(User user) async {
    // Android BLE advertising implementation
    final advertisementData = {
      'userId': user.id,
      'bleUuid': user.bleUuid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'deviceId': user.boundDeviceId,
    };

    // In a real implementation, you would use platform channels
    // or a more advanced BLE plugin that supports advertising
    _logger.i('Android advertising data: $advertisementData');
    
    // Simulate advertising by periodically updating state
    _advertisingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Update advertising timestamp
      state = state.copyWith(lastAdvertisingUpdate: DateTime.now());
    });
  }

  Future<void> _startIOSAdvertising(User user) async {
    // iOS BLE advertising implementation
    final advertisementData = {
      'userId': user.id,
      'bleUuid': user.bleUuid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _logger.i('iOS advertising data: $advertisementData');
    
    // iOS has more restrictions on BLE advertising
    _advertisingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      state = state.copyWith(lastAdvertisingUpdate: DateTime.now());
    });
  }

  // Instructor App: Start scanning for student devices
  Future<void> startScanning({Duration? timeout}) async {
    try {
      if (!state.isEnabled) {
        throw Exception('Bluetooth is not enabled');
      }

      if (state.isScanning) {
        await stopScanning();
      }

      _discoveredDevices.clear();
      state = state.copyWith(
        isScanning: true,
        discoveredDevices: {},
      );

      // Start scanning with service UUID filter
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResult,
        onError: (error) {
          _logger.e('Scan error: $error');
          state = state.copyWith(error: error.toString());
        },
      );

      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: timeout ?? const Duration(minutes: 5),
        androidUsesFineLocation: true,
      );

      if (timeout != null) {
        _scanTimeoutTimer = Timer(timeout, () {
          stopScanning();
        });
      }

      _logger.i('Started scanning for student devices');

    } catch (e) {
      _logger.e('Error starting scan: $e');
      state = state.copyWith(
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  void _onScanResult(List<ScanResult> results) {
    final now = DateTime.now();
    
    for (final result in results) {
      try {
        final deviceId = result.device.remoteId.toString();
        final rssi = result.rssi.toDouble();
        
        // Parse advertisement data
        final advertisementData = _parseAdvertisementData(result.advertisementData);
        if (advertisementData == null) continue;
        
        final userId = advertisementData['userId'] as String?;
        if (userId == null) continue;

        final bleDevice = BleDevice(
          deviceId: deviceId,
          userId: userId,
          name: result.device.platformName.isNotEmpty 
              ? result.device.platformName 
              : 'Unknown Device',
          bleUuid: advertisementData['bleUuid'] as String? ?? '',
          rssi: rssi,
          discoveredAt: now,
          advertisementData: advertisementData,
        );

        _discoveredDevices[deviceId] = bleDevice;
        _deviceLastSeen[deviceId] = now;

        _logger.d('Discovered device: ${bleDevice.name} (RSSI: $rssi)');

      } catch (e) {
        _logger.w('Error processing scan result: $e');
      }
    }

    // Remove old devices (not seen for 30 seconds)
    final cutoffTime = now.subtract(const Duration(seconds: 30));
    _discoveredDevices.removeWhere((deviceId, device) {
      final lastSeen = _deviceLastSeen[deviceId];
      return lastSeen == null || lastSeen.isBefore(cutoffTime);
    });

    state = state.copyWith(
      discoveredDevices: Map.from(_discoveredDevices),
      lastScanUpdate: now,
    );
  }

  Map<String, dynamic>? _parseAdvertisementData(AdvertisementData data) {
    try {
      // Try to extract custom data from manufacturerData or serviceData
      if (data.manufacturerData.isNotEmpty) {
        final manufacturerId = data.manufacturerData.keys.first;
        final rawData = data.manufacturerData[manufacturerId];
        if (rawData != null && rawData.length > 4) {
          final jsonString = utf8.decode(rawData.sublist(4));
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }
      }

      if (data.serviceData.isNotEmpty) {
        final serviceId = data.serviceData.keys.first;
        final rawData = data.serviceData[serviceId];
        if (rawData != null) {
          final jsonString = utf8.decode(rawData);
          return jsonDecode(jsonString) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      _logger.w('Error parsing advertisement data: $e');
    }
    return null;
  }

  Future<void> stopScanning() async {
    try {
      if (state.isScanning) {
        await FlutterBluePlus.stopScan();
        _scanSubscription?.cancel();
        _scanTimeoutTimer?.cancel();
        
        state = state.copyWith(isScanning: false);
        _logger.i('Stopped scanning');
      }
    } catch (e) {
      _logger.e('Error stopping scan: $e');
    }
  }

  Future<void> stopAdvertising() async {
    try {
      _advertisingTimer?.cancel();
      state = state.copyWith(
        isAdvertising: false,
        advertisingUserId: null,
      );
      _logger.i('Stopped advertising');
    } catch (e) {
      _logger.e('Error stopping advertising: $e');
    }
  }

  // Get devices within RSSI threshold (for proximity verification)
  List<BleDevice> getDevicesInRange(double rssiThreshold) {
    return _discoveredDevices.values
        .where((device) => device.rssi >= rssiThreshold)
        .toList();
  }

  // Send challenge to specific device
  Future<bool> sendChallenge(String deviceId, String challengeCode) async {
    try {
      // In a real implementation, this would send the challenge via BLE characteristic
      _logger.i('Sending challenge to device: $deviceId');
      
      // Simulate challenge sending
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true;
    } catch (e) {
      _logger.e('Error sending challenge: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _advertisingTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    super.dispose();
  }
}

@freezed
class BluetoothState with _$BluetoothState {
  const factory BluetoothState({
    @Default(false) bool isSupported,
    @Default(false) bool isEnabled,
    @Default(BluetoothAdapterState.unknown) BluetoothAdapterState adapterState,
    @Default(false) bool isScanning,
    @Default(false) bool isAdvertising,
    String? advertisingUserId,
    @Default({}) Map<String, BleDevice> discoveredDevices,
    DateTime? lastScanUpdate,
    DateTime? lastAdvertisingUpdate,
    String? error,
  }) = _BluetoothState;
}

// Provider for Bluetooth service
final bluetoothServiceProvider = StateNotifierProvider<BluetoothService, BluetoothState>((ref) {
  return BluetoothService();
});