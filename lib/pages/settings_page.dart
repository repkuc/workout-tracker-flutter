import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'settings.title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('settings.language'.tr()),
                    _buildCard(children: [
                      _buildLanguageItem(context, '🇷🇺', 'Русский', 'ru'),
                      _buildDivider(),
                      _buildLanguageItem(context, '🇱🇻', 'Latviešu', 'lv'),
                      _buildDivider(),
                      _buildLanguageItem(context, '🇬🇧', 'English', 'en'),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionTitle('settings.data'.tr()),
                    _buildCard(children: [
                      _buildActionItem(
                        icon: Icons.upload,
                        color: AppColors.iconExport,
                        title: 'backup.export'.tr(),
                        subtitle: 'settings.export_subtitle'.tr(),
                        onTap: () async {
                          try {
                            await BackupService().exportData();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${'backup.export_error'.tr()}: $e'),
                                    backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                      ),
                      _buildDivider(),
                      _buildActionItem(
                        icon: Icons.download,
                        color: AppColors.iconImport,
                        title: 'backup.import'.tr(),
                        subtitle: 'settings.import_subtitle'.tr(),
                        onTap: () async {
                          try {
                            final count = await BackupService().importData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(count > 0
                                      ? 'backup.imported_count'
                                          .tr(namedArgs: {'count': '$count'})
                                      : 'backup.no_new_workouts'.tr()),
                                  backgroundColor: count > 0
                                      ? AppColors.success
                                      : AppColors.snackbarNeutral,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${'backup.import_error'.tr()}: $e'),
                                    backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionTitle('settings.support'.tr()),
                    GestureDetector(
                      onTap: _openDonateLink,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('☕',
                                  style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'settings.donate_title'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'settings.donate_subtitle'.tr(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('settings.about'.tr()),
                    _buildCard(children: [
                      _buildInfoItem(
                        icon: Icons.info_outline,
                        color: AppColors.iconInfo,
                        title: 'settings.version'.tr(),
                        value: _version,
                      ),
                      _buildDivider(),
                      _buildActionItem(
                        icon: Icons.privacy_tip_outlined,
                        color: AppColors.accent,
                        title: 'settings.privacy'.tr(),
                        subtitle: '',
                        onTap: () async {
                          final url = Uri.parse(
                              'https://repkuc.github.io/workout-diary-privacy/');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
        height: 1, color: AppColors.background, indent: 16, endIndent: 16);
  }

  Widget _buildLanguageItem(
      BuildContext context, String flag, String name, String code) {
    final isSelected = context.locale.languageCode == code;
    return GestureDetector(
      onTap: () => context.setLocale(Locale(code)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 15))),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
      {required IconData icon,
      required Color color,
      required String title,
      required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 15))),
          Text(value,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _openDonateLink() async {
    final url = Uri.parse('https://ko-fi.com/repkuc');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
