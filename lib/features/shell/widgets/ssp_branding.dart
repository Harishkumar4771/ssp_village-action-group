import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SspBranding extends StatelessWidget {
  final bool isDesktop;

  const SspBranding({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Powered by SSP',
              style: TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
            const SizedBox(height: 8),
            Image.asset(
              'assets/images/ssp_logo.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ssp_logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ],
        ),
      );
    }
  }
}
