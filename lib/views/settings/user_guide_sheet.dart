import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class UserGuideSheet extends StatelessWidget {
  const UserGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const UserGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle and Title Bar
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 20, right: 16, bottom: 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.mileageGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_outlined, color: AppTheme.mileageGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Guide & FAQs',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'How Fuel Logger calculates mileage and telemetry',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    icon: Icons.local_gas_station_outlined,
                    iconColor: AppTheme.primary,
                    title: '1. Full Tank vs. Half Tank (Partial Fill)',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    title: 'Full Tank (F) — Closes the Cycle',
                    titleColor: AppTheme.mileageGreen,
                    content:
                        '• Always marks the completion of a mileage cycle.\n'
                        '• Requires an accurate Odometer reading.\n'
                        '• The app calculates:\n'
                        '   Mileage (km/L) = Distance travelled ÷ Liters consumed\n'
                        '   Cost per km = Total money spent ÷ Distance travelled',
                  ),
                  const SizedBox(height: 10),
                  _buildGuideCard(
                    title: 'Half Tank / Partial (P) — Cycle Remains Open',
                    titleColor: AppTheme.costAmber,
                    content:
                        '• Use whenever you top up with a fixed amount (e.g. ₹500 or 10 L) without filling to the brim.\n'
                        '• Run # stays locked: If Run #12 is active, 1st half fill and 2nd half fill all stay under Run #12.\n'
                        '• Odometer is optional: Leave as 0 km or empty.\n'
                        '• Liters & expenses accumulate: When you next fill Full Tank, mileage is calculated accurately over the full combined fuel volume and distance.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    icon: Icons.repeat,
                    iconColor: AppTheme.distanceBlue,
                    title: '2. Run Number & Telemetry Progression',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    title: 'How Cycles Advance',
                    titleColor: AppTheme.distanceBlue,
                    content:
                        '• Each complete cycle is one Run # (e.g. Run 1, Run 2, Run 3).\n'
                        '• Toggling between Full and Half tank does not change or decrement your current cycle number.\n'
                        '• In the Logs list, the closing Full Tank is placed on top of earlier partial fills under the same Run # for easy reference.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    icon: Icons.edit_calendar_outlined,
                    iconColor: AppTheme.costAmber,
                    title: '3. Editing & Correcting Logs',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    title: 'Tap to Edit or Delete',
                    titleColor: Colors.white,
                    content:
                        '• On the Logs tab, tap any fuel entry to open the edit dialog.\n'
                        '• Interactive Date Picker: Tap the calendar button to backdate or correct the fill-up date.\n'
                        '• Update Liters, Cost, Fuel Type, or Odometer reading anytime.\n'
                        '• All mileage stats and calculations automatically recalculate in real-time.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    icon: Icons.import_export,
                    iconColor: AppTheme.mileageGreen,
                    title: '4. Backup & CSV Import/Export',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    title: 'Native CSV File Tools',
                    titleColor: AppTheme.mileageGreen,
                    content:
                        '• Download CSV: Saves your complete fuel logbook as a .csv file directly to your phone storage.\n'
                        '• Upload .csv: Pick any CSV file to import multiple logs at once.\n'
                        '• Download sample.csv: Generates a template with exact column headers and a sample row.\n'
                        '• Append vs. Full Replace: Choose whether to add imported rows to existing logs or replace them completely.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    icon: Icons.cloud_sync_outlined,
                    iconColor: AppTheme.distanceBlue,
                    title: '5. Account & Offline Capabilities',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    title: 'Instant Sign-In & Offline Cache',
                    titleColor: Colors.white,
                    content:
                        '• Set Password in Settings → Account to sign in in 150ms on any device without waiting for emails.\n'
                        '• Google Sign-In: Supported natively on Android with automatic web fallback.\n'
                        '• Offline First: Logs are saved instantly on your phone and automatically sync to Supabase Cloud PostgreSQL whenever internet is connected.',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required String title,
    required Color titleColor,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}
