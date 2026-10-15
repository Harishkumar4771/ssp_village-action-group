import re

with open('lib/features/profile/screens/profile_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_settings_section = '''  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    String languageSubtitle = 'English';
    if (currentLocale.languageCode == 'mr') languageSubtitle = 'मराठी (Marathi)';
    if (currentLocale.languageCode == 'hi') languageSubtitle = 'हिन्दी (Hindi)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Settings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          color: AppColors.surfaceCard,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                iconColor: AppColors.info,
                title: 'Language',
                subtitle: languageSubtitle,
                onTap: () => _showLanguageSelector(context, ref, currentLocale),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref, Locale currentLocale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              trailing: currentLocale.languageCode == 'en' ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('हिन्दी (Hindi)'),
              trailing: currentLocale.languageCode == 'hi' ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('hi'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('मराठी (Marathi)'),
              trailing: currentLocale.languageCode == 'mr' ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('mr'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }'''

settings_pattern = re.compile(
    r'  Widget _buildSettingsSection\(BuildContext context\) \{.*?(?=  // ---------------------------------------------------------------------------\n  // Logout tile)',
    re.DOTALL
)

content = settings_pattern.sub(new_settings_section + '\n', content)

with open('lib/features/profile/screens/profile_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
