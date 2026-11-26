import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VehicleLimitDialog {
  static Future<void> show(BuildContext context, {int limit = 2}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardTheme.color ?? AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.costAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_filled, color: AppTheme.costAmber, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Free Vehicle Limit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Free accounts support up to $limit vehicles.\n\n'
            'Your existing vehicles and logs remain 100% unlocked. Unlimited vehicles and fleet features will be available soon in Fuel Logger Pro.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(ctx).textTheme.bodyMedium?.color?.withOpacity(0.85),
              height: 1.45,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got It'),
            ),
          ],
        );
      },
    );
  }
}
