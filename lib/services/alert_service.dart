import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/alert_model.dart';

class AlertService {
  AlertService._();

  static final AlertService instance = AlertService._();

  // ==========================================================
  // STORAGE
  // ==========================================================

  final List<AlertModel> _alerts = [];

  // ==========================================================
  // STREAM
  // ==========================================================

  final StreamController<List<AlertModel>> _controller =
  StreamController<List<AlertModel>>.broadcast();

  Stream<List<AlertModel>> get alertsStream => _controller.stream;

  // ==========================================================
  // ALERTS
  // ==========================================================

  List<AlertModel> get alerts =>
      List.unmodifiable(
        _alerts.where((alert) => !alert.dismissed),
      );

  // ==========================================================
  // UNREAD COUNT
  // ==========================================================

  int get unreadCount =>
      _alerts.where(
            (alert) =>
        !alert.acknowledged &&
            !alert.dismissed,
      ).length;

  // ==========================================================
  // ADD ALERT
  // ==========================================================

  void addAlert({
    required AlertType type,
    required AlertSeverity severity,
    required String title,
    required String message,
    required AlertSource source,
    double? latitude,
    double? longitude,
    Map<String, dynamic> metadata = const {},
  }) {
    final alert = AlertModel(
      id: const Uuid().v4(),
      type: type,
      severity: severity,
      title: title,
      message: message,
      source: source,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      metadata: metadata,
    );

    _alerts.insert(0, alert);

    _notify();
  }

  // ==========================================================
  // CHECK FOR RECENT DUPLICATE ALERT
  // ==========================================================

  bool hasRecentAlert({
    required AlertType type,
    required AlertSource source,
    Duration duration = const Duration(minutes: 5),
  }) {
    final now = DateTime.now();

    for (final alert in _alerts) {
      if (alert.dismissed) {
        continue;
      }

      if (alert.type != type) {
        continue;
      }

      if (alert.source != source) {
        continue;
      }

      final difference =
      now.difference(alert.timestamp);

      if (difference >= Duration.zero &&
          difference <= duration) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================
  // ACKNOWLEDGE ALERT
  // ==========================================================

  void acknowledgeAlert(String id) {
    final alert = _find(id);

    if (alert != null) {
      alert.acknowledged = true;

      _notify();
    }
  }

  // ==========================================================
  // DISMISS ALERT
  // ==========================================================

  void dismissAlert(String id) {
    final alert = _find(id);

    if (alert != null) {
      alert.dismissed = true;

      _notify();
    }
  }

  // ==========================================================
  // CLEAR ALL
  // ==========================================================

  void clearAll() {
    for (final alert in _alerts) {
      alert.dismissed = true;
    }

    _notify();
  }

  // ==========================================================
  // FIND ALERT
  // ==========================================================

  AlertModel? _find(String id) {
    for (final alert in _alerts) {
      if (alert.id == id) {
        return alert;
      }
    }

    return null;
  }

  // ==========================================================
  // NOTIFY LISTENERS
  // ==========================================================

  void _notify() {
    if (_controller.isClosed) {
      return;
    }

    _controller.add(alerts);
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}