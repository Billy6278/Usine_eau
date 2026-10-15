import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade100, width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.water_drop, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Gestion Usine d\'Eau',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      const Text(
                        'Version 1.0.0 (Stable)',
                        style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        'Une application professionnelle et ultra-légère conçue spécifiquement pour la gestion autonome d\'usines de production et d\'embouteillage d\'eau minérale.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate700, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(Icons.offline_bolt, '100% Hors ligne et autonome'),
                      const SizedBox(height: 12),
                      _buildFeatureRow(Icons.storage, 'Base de données SQLite locale'),
                      const SizedBox(height: 12),
                      _buildFeatureRow(Icons.security, 'Sécurité des données garantie localement'),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        '© 2026 Équipe de Conception Usine d\'Eau.\nTous droits réservés.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900),
          ),
        ),
      ],
    );
  }
}
