import 'package:flutter/material.dart';

import '../models/alert_model.dart';
import '../services/alert_service.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AlertService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alerts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          StreamBuilder<List<AlertModel>>(
            stream: service.alertsStream,
            initialData: service.alerts,
            builder: (context, snapshot) {
              final count = service.unreadCount;

              return Padding(
                padding: const EdgeInsets.only(
                  right: 16,
                ),
                child: Center(
                  child: Text(
                    '$count unread',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<List<AlertModel>>(
        stream: service.alertsStream,
        initialData: service.alerts,
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 12),

                  Text(
                    'No alerts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'You are all clear for now.',
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];

              return _AlertCard(
                alert: alert,

                onAcknowledge: () {
                  service.acknowledgeAlert(
                    alert.id,
                  );
                },

                onDismiss: () {
                  service.dismissAlert(
                    alert.id,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismiss;

  const _AlertCard({
    required this.alert,
    required this.onAcknowledge,
    required this.onDismiss,
  });

  Color _severityColor() {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return Colors.red;

      case AlertSeverity.warning:
        return Colors.orange;

      case AlertSeverity.info:
        return Colors.blue;
    }
  }

  IconData _severityIcon() {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return Icons.error;

      case AlertSeverity.warning:
        return Icons.warning;

      case AlertSeverity.info:
        return Icons.info;
    }
  }

  String _severityName() {
    return alert.severity.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),

      elevation: 1,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(
                  _severityIcon(),
                  color: color,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (!alert.acknowledged)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),

                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),

                    child: Text(
                      _severityName(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              alert.message,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '${alert.source.name} • '
                  '${_formatTime(alert.timestamp)}',
              style:
              Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment:
              MainAxisAlignment.end,

              children: [
                if (!alert.acknowledged)
                  TextButton(
                    onPressed: onAcknowledge,
                    child: const Text(
                      'Acknowledge',
                    ),
                  ),

                TextButton(
                  onPressed: onDismiss,
                  child: const Text(
                    'Dismiss',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour =
    time.hour.toString().padLeft(2, '0');

    final minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}