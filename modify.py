import re

with open('lib/features/profile/screens/profile_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import
if 'locale_provider.dart' not in content:
    content = content.replace(
        "import 'package:vag_dmp_frontend/core/auth/supabase_auth_service.dart';",
        "import 'package:vag_dmp_frontend/core/auth/supabase_auth_service.dart';\nimport 'package:vag_dmp_frontend/core/localization/locale_provider.dart';"
    )

# 2. Remove isAdmin from build method
content = re.sub(
    r'\s*final isAdmin = ref\.watch\(isAdminProvider\);\n',
    '\n',
    content
)

# 3. Remove _buildDevToolsSection usage
content = re.sub(
    r'\s*_buildDevToolsSection\(context, ref, isAdmin\),\s*const SizedBox\(height: AppConstants\.spacingLg\),',
    '',
    content
)

# 4. Remove _buildSupportSection usage
content = re.sub(
    r'\s*_buildSupportSection\(context\),\s*const SizedBox\(height: AppConstants\.spacingLg\),',
    '',
    content
)

# 5. Update _buildSettingsSection(context) usage
content = content.replace(
    '_buildSettingsSection(context)',
    '_buildSettingsSection(context, ref)'
)

# 6. Remove _buildDevToolsSection definition
dev_tools_pattern = re.compile(r'// ---\n\s*// Developer Tools.*?// ---\n.*?Widget _buildDevToolsSection.*?\n    \)\n  \}', re.DOTALL)
# Wait, a regex for the whole block is risky. Let's do it manually or via string replacements.
