import re

with open('lib/features/profile/screens/profile_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove _buildDevToolsSection
dev_tools_pattern = re.compile(
    r'  // ---------------------------------------------------------------------------\n'
    r'  // Developer Tools – RBAC toggle\n'
    r'  // ---------------------------------------------------------------------------\n'
    r'.*?(?=  // ---------------------------------------------------------------------------\n  // Settings section)',
    re.DOTALL
)
content = dev_tools_pattern.sub('', content)

# Remove _buildSupportSection
support_pattern = re.compile(
    r'  // ---------------------------------------------------------------------------\n'
    r'  // Support / About section\n'
    r'  // ---------------------------------------------------------------------------\n'
    r'.*?(?=  // ---------------------------------------------------------------------------\n  // Logout tile)',
    re.DOTALL
)
content = support_pattern.sub('', content)

with open('lib/features/profile/screens/profile_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
