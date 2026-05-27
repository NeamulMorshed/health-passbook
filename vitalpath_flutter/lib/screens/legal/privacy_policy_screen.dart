import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: const [
          _SectionHeader('Last updated: May 2026'),
          SizedBox(height: 16),
          _Body(
            'Omra ("we", "our", "the app") is a personal health-tracking application. '
            'This Privacy Policy explains what data we collect, how we use it, '
            'and your rights as a user.',
          ),
          SizedBox(height: 24),
          _SectionTitle('1. Data We Collect'),
          _Body(
            'When you use Omra, we may collect:\n\n'
            '• Account information: name, email address, and user type (patient, doctor, or family member).\n\n'
            '• Health data: vital signs (blood pressure, heart rate, blood glucose, etc.), '
            'medication records, meal logs, activity data, and health profile details you enter.\n\n'
            '• Location data: approximate or precise location used for activity tracking and '
            'finding nearby healthcare providers, only when you grant permission.\n\n'
            '• Photos: profile pictures and prescription images you upload, processed locally '
            'via on-device OCR.\n\n'
            '• Device data: Firebase Cloud Messaging token for push notifications, '
            'crash reports collected by Firebase Crashlytics (in non-debug builds only).',
          ),
          SizedBox(height: 24),
          _SectionTitle('2. How We Use Your Data'),
          _Body(
            '• To provide the core app features: tracking health records, managing medicines, '
            'scheduling appointments, and coordinating care with connected doctors and family members.\n\n'
            '• To send push notifications for medication reminders and appointment updates.\n\n'
            '• To improve app stability using anonymised crash reports.\n\n'
            'We do not sell, rent, or trade your personal or health data to any third party.',
          ),
          SizedBox(height: 24),
          _SectionTitle('3. Data Sharing'),
          _Body(
            'Your health data is shared only with:\n\n'
            '• Doctors you explicitly connect with through the app.\n\n'
            '• Family members you invite as care companions, limited to the permissions you grant.\n\n'
            '• Google / Firebase infrastructure for secure cloud storage, authentication, '
            'push notifications, and crash reporting. Firebase\'s data processing is governed '
            'by Google\'s Privacy Policy.',
          ),
          SizedBox(height: 24),
          _SectionTitle('4. Data Storage & Security'),
          _Body(
            'All data is stored in Google Cloud Firestore and Firebase Storage. '
            'Data is encrypted in transit (TLS) and at rest by Google. '
            'Access is controlled by Firestore security rules that restrict each user '
            'to only their own data and explicitly connected parties.',
          ),
          SizedBox(height: 24),
          _SectionTitle('5. Sensitive Permissions'),
          _Body(
            '• Location: used only when active and only to support features you initiate. '
            'We do not track your location in the background.\n\n'
            '• Activity Recognition: used to count steps for activity logging. '
            'Data stays on-device and in your personal Firestore document.\n\n'
            '• Camera: used only for profile photos and on-device OCR of prescription labels. '
            'Images are not stored unless you explicitly save them.\n\n'
            '• Exact Alarms: used to deliver medication reminders at your scheduled times.',
          ),
          SizedBox(height: 24),
          _SectionTitle('6. Data Retention & Deletion'),
          _Body(
            'Your data is retained for as long as your account is active. '
            'You can delete your account at any time from Settings → Privacy & Security → Delete Account. '
            'This permanently removes all your health data from our servers within 30 days.',
          ),
          SizedBox(height: 24),
          _SectionTitle('7. Children\'s Privacy'),
          _Body(
            'Omra is intended for users aged 18 and over. '
            'We do not knowingly collect data from children under 18. '
            'If you believe a child has provided us with personal data, '
            'please contact us and we will delete it promptly.',
          ),
          SizedBox(height: 24),
          _SectionTitle('8. Your Rights'),
          _Body(
            'Depending on your location, you may have rights to:\n\n'
            '• Access a copy of the personal data we hold about you.\n\n'
            '• Request correction of inaccurate data.\n\n'
            '• Request deletion of your data.\n\n'
            '• Withdraw consent at any time.\n\n'
            'To exercise these rights, contact us at the email below.',
          ),
          SizedBox(height: 24),
          _SectionTitle('9. Changes to This Policy'),
          _Body(
            'We may update this Privacy Policy from time to time. '
            'When we do, we will update the "Last updated" date at the top of this page '
            'and notify you via in-app notification.',
          ),
          SizedBox(height: 24),
          _SectionTitle('10. Contact Us'),
          _Body(
            'If you have any questions about this Privacy Policy or how we handle your data, '
            'please contact us at:\n\n'
            'Email: support@omra.health\n'
            'App: Omra — Personal Health Tracker\n'
            'Package: com.vitalpath.app',
          ),
          SizedBox(height: 32),
          Divider(),
          SizedBox(height: 12),
          _Body(
            'This app is not a medical device and does not provide medical advice. '
            'Always consult a qualified healthcare professional.',
            italic: true,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      );
}

class _Body extends StatelessWidget {
  final String text;
  final bool italic;
  const _Body(this.text, {this.italic = false});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.6,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      );
}
