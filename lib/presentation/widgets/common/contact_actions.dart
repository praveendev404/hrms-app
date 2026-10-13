import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// Call / WhatsApp / email buttons for a colleague. Buttons that have no data are disabled.
class ContactBar extends StatelessWidget {
  final String? mobile;
  final String? email;
  const ContactBar({super.key, this.mobile, this.email});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app available to do that on this device.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = (mobile ?? '').trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final mail = (email ?? '').trim();

    Widget action(IconData icon, String label, Color color, VoidCallback? onTap) {
      final enabled = onTap != null;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (enabled ? color : Colors.grey).withOpacity(0.12),
                child: Icon(icon, color: enabled ? color : Colors.grey, size: 22),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: enabled ? AppColors.textPrimaryLight : Colors.grey)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      action(Icons.call_rounded, 'Call', AppColors.success,
          digits.isEmpty ? null : () => _open(context, Uri.parse('tel:$digits'))),
      action(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366),
          digits.isEmpty ? null : () => _open(context, Uri.parse('https://wa.me/${digits.replaceAll('+', '')}'))),
      action(Icons.mail_rounded, 'Email', AppColors.info,
          mail.isEmpty ? null : () => _open(context, Uri.parse('mailto:$mail'))),
    ]);
  }
}
