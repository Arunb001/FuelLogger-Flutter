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
    final c = context.appColors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 20, right: 16, bottom: 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.subtleBorder,
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
                        color: c.mileageGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.menu_book_outlined, color: c.mileageGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Guide & FAQs',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                          Text(
                            'How Fuel Logger tracks fills, cycles & service',
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: c.textSecondary, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: c.subtleBorder, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    icon: Icons.local_gas_station_outlined,
                    iconColor: c.accentPrimary,
                    title: '1. Full Tank vs. Half Tank (Partial Fill)',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    context,
                    title: 'Full Tank (F) — Accurate Cycle Calculations',
                    titleColor: c.mileageGreen,
                    content:
                        '• Fill all the way to the brim and enter your odometer reading.\n'
                        '• When your next Full Tank is logged, Fuel Logger pairs your trip interval and fuel volume to calculate exact mileage.\n'
                        '• Active Entry: Your newest fill shows In Tank until the next Full Tank refill.',
                  ),
                  const SizedBox(height: 10),
                  _buildGuideCard(
                    context,
                    title: 'Half Tank / Partial (P) — Cycle Remains Open',
                    titleColor: c.costAmber,
                    content:
                        '• Use whenever you top up without filling to the brim.\n'
                        '• Entry # stays linked to your open cycle.\n'
                        '• Odometer is optional on partial fills — leave as 0 or blank if preferred.\n'
                        '• Combined litres and expenses roll into your next Full Tank calculation automatically.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    context,
                    icon: Icons.repeat,
                    iconColor: c.distanceBlue,
                    title: '2. Entry Sequence & Progression',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    context,
                    title: 'How Entries Advance',
                    titleColor: c.distanceBlue,
                    content:
                        '• Each complete full-tank cycle has its own Entry #.\n'
                        '• Partial fills stay grouped under the active cycle until a closing Full Tank fill is recorded.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    context,
                    icon: Icons.edit_calendar_outlined,
                    iconColor: c.costAmber,
                    title: '3. Viewing, Editing & Deleting Logs',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    context,
                    title: 'Tap Any Card for Full Details',
                    titleColor: c.textPrimary,
                    content:
                        '• In the Logs tab, tap any entry to view full details (station, remarks, density, and mileage).\n'
                        '• Use Edit to adjust cost, litres, odometer, station, remark, or date.\n'
                        '• All totals and charts recalculate automatically.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    context,
                    icon: Icons.import_export,
                    iconColor: c.mileageGreen,
                    title: '4. Backup & CSV Import/Export',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    context,
                    title: 'Native CSV File Tools',
                    titleColor: c.mileageGreen,
                    content:
                        '• Download CSV saves your vehicle fill-up records to phone storage.\n'
                        '• Upload .csv imports historical spreadsheets in bulk.\n'
                        '• Choose Append Data or Full Replace Data before importing.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader(
                    context,
                    icon: Icons.cloud_sync_outlined,
                    iconColor: c.distanceBlue,
                    title: '5. Account & Offline Support',
                  ),
                  const SizedBox(height: 8),
                  _buildGuideCard(
                    context,
                    title: 'Instant Startup & Cloud Sync',
                    titleColor: c.textPrimary,
                    content:
                        '• Set Password in Settings to sign in quickly across devices.\n'
                        '• Google Sign-In is supported natively on Android.\n'
                        '• Logs cache locally for offline startup and sync securely to the cloud.',
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    final c = context.appColors;
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required String title,
    required Color titleColor,
    required String content,
  }) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.subtleBorder.withOpacity(0.7)),
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
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
