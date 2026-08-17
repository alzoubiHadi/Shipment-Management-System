import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../API/config.dart';

/// Driver Phase 5 (2026-08-20): "Support Center" — contact-only per the
/// confirmed scope (no ticket backend exists, so no "Create Ticket" flow).
/// Just Call/WhatsApp/Email plus a static FAQ list.
class SupportCenterPage extends StatelessWidget {
  const SupportCenterPage({super.key});

  static const _phone = '+963986790892';
  static const _whatsapp = '963995571800'; // wa.me wants no leading + or 00
  static const _email = 'gpssa.alba@gmail.com';

  static const _faqs = <(String, String)>[
    (
      'How do I get matched with a shipment?',
      'Available shipments matching your truck type and destinations show up under Shipments. You can accept one directly from the list or after reviewing its details.',
    ),
    (
      'When do I get paid for a completed trip?',
      'Once the company confirms delivery, the trip amount is credited to your wallet balance. You can request a payout from the Wallet screen.',
    ),
    (
      'My documents are about to expire — what do I do?',
      'Go to Profile > My Documents and upload the renewed file. It replaces the old one immediately.',
    ),
    (
      'Why can\'t I edit my truck details?',
      'Truck details can only be edited when an admin has requested changes to your registration. Contact support if something needs updating outside of that.',
    ),
    (
      'I forgot my password, what now?',
      'Use "Forgot password" on the login screen, or contact support below if you\'re still signed in and just want to set a new one from Profile > Change Password.',
    ),
  ];

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open — is the app installed?')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('Support Center', style: TextStyle(color: AppColors.cream)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Need Help?', style: TextStyle(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Our team is here to help with anything trip or account related.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 16),
                _ContactButton(
                  icon: Icons.call_outlined,
                  label: 'Call Us',
                  subtitle: _phone,
                  onTap: () => _launch(context, Uri.parse('tel:$_phone')),
                ),
                const SizedBox(height: 10),
                _ContactButton(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  subtitle: '+$_whatsapp',
                  onTap: () => _launch(context, Uri.parse('https://wa.me/$_whatsapp')),
                ),
                const SizedBox(height: 10),
                _ContactButton(
                  icon: Icons.email_outlined,
                  label: 'Email Us',
                  subtitle: _email,
                  onTap: () => _launch(context, Uri.parse('mailto:$_email?subject=Driver%20Support%20Request')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Frequently Asked Questions', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ..._faqs.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactButton({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: AppColors.muted,
          iconColor: AppColors.gold,
          title: Text(question, style: const TextStyle(color: AppColors.cream, fontSize: 13.5, fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
