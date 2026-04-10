import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

/// Represents the 6-DOF pose of the camera at a single capture moment.
class CameraPoseData {
  /// Rotation matrix (flattened row-major 3x3).
  final List<double> rotationMatrix;

  /// Euler angles (pitch, roll, yaw) in radians derived from accelerometer.
  final double pitch;
  final double roll;
  final double yaw;

  /// Gyroscope angular velocities at capture time (rad/s).
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  /// Unix timestamp in milliseconds.
  final int timestamp;

  /// Capture index within a session.
  final int captureIndex;

  const CameraPoseData({
    required this.rotationMatrix,
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.timestamp,
    required this.captureIndex,
  });

  Map<String, dynamic> toJson() => {
        'rotation_matrix': rotationMatrix,
        'pitch': pitch,
        'roll': roll,
        'yaw': yaw,
        'gyro_x': gyroX,
        'gyro_y': gyroY,
        'gyro_z': gyroZ,
        'timestamp_ms': timestamp,
        'capture_index': captureIndex,
      };
}

/// Measures angular diversity between poses (0–1 score, higher = better for 3D).
double computePoseDiversity(List<CameraPoseData> poses) {
  if (poses.length < 2) return 0.0;
  double totalAngle = 0.0;
  for (int i = 1; i < poses.length; i++) {
    final a = poses[i - 1];
    final b = poses[i];
    final dp = (b.pitch - a.pitch).abs();
    final dr = (b.roll - a.roll).abs();
    final dy = (b.yaw - a.yaw).abs();
    totalAngle += math.sqrt(dp * dp + dr * dr + dy * dy);
  }
  // Normalize: 0.5 radians total movement → score ~0.5; 1+ radian → score ~1.0
  return (totalAngle / math.max(poses.length - 1, 1)).clamp(0.0, 1.0);
}

/// Service that subscribes to device IMU sensors and snaps pose data on demand.
class ArCaptureService {
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool _started = false;

  /// Start listening to sensors. Call once when the screen is opened.
  void start() {
    if (_started) return;
    _started = true;
    try {
      _accelSub = accelerometerEventStream().listen(
        (e) => _lastAccel = e,
        onError: (_) {}, // web may not have accelerometer
      );
      _gyroSub = gyroscopeEventStream().listen(
        (e) => _lastGyro = e,
        onError: (_) {},
      );
    } catch (_) {
      // sensors_plus gracefully falls back on web
    }
  }

  /// Stop listening. Call when the screen is disposed.
  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _started = false;
  }

  /// Capture current pose. Call this immediately after each photo is taken.
  CameraPoseData snapshot(int captureIndex) {
    final accel = _lastAccel;
    final gyro = _lastGyro;

    double pitch = 0, roll = 0, yaw = 0;
    double gx = 0, gy = 0, gz = 0;

    if (accel != null) {
      final ax = accel.x, ay = accel.y, az = accel.z;
      pitch = math.atan2(ay, math.sqrt(ax * ax + az * az));
      roll = math.atan2(-ax, az);
      yaw = math.atan2(ay, az); // approximate
    }

    if (gyro != null) {
      gx = gyro.x;
      gy = gyro.y;
      gz = gyro.z;
    }

    // Build rotation matrix from pitch/roll/yaw (Tait-Bryan ZYX convention)
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final cr = math.cos(roll), sr = math.sin(roll);
    final cy = math.cos(yaw), sy = math.sin(yaw);

    final rotMatrix = [
      cy * cr, cy * sr * sp - sy * cp, cy * sr * cp + sy * sp,
      sy * cr, sy * sr * sp + cy * cp, sy * sr * cp - cy * sp,
      -sr,     cr * sp,                cr * cp,
    ];

    return CameraPoseData(
      rotationMatrix: rotMatrix,
      pitch: pitch,
      roll: roll,
      yaw: yaw,
      gyroX: gx,
      gyroY: gy,
      gyroZ: gz,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      captureIndex: captureIndex,
    );
  }
}
