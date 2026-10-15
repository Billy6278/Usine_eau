import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ResponsiveLayout extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Widget Function(int selectedIndex) pageBuilder;
  final VoidCallback onLogout;

  const ResponsiveLayout({
    super.key,
    required this.currentUser,
    required this.pageBuilder,
    required this.onLogout,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _navigationItems = [
    {'label': 'Tableau de Bord', 'icon': Icons.dashboard},
    {'label': 'Production', 'icon': Icons.factory},
    {'label': 'Stock', 'icon': Icons.inventory_2},
    {'label': 'Ventes', 'icon': Icons.point_of_sale},
    {'label': 'Commandes', 'icon': Icons.shopping_bag},
    {'label': 'Livraisons', 'icon': Icons.local_shipping},
    {'label': 'Clients', 'icon': Icons.people},
    {'label': 'Finances', 'icon': Icons.calculate},
    {'label': 'Rapports & Stats', 'icon': Icons.bar_chart},
    {'label': 'Utilisateurs', 'icon': Icons.manage_accounts},
    {'label': 'Paramètres', 'icon': Icons.settings},
    {'label': 'À Propos', 'icon': Icons.info},
  ];

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Déconnexion'),
          content: const Text('Voulez-vous vraiment vous déconnecter de votre session ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              child: const Text('Se Déconnecter'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerContent(BuildContext context, bool inDrawer) {
    return Column(
      children: [
        // Header
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (widget.currentUser['nom'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          accountName: Text(
            widget.currentUser['nom'] ?? 'Utilisateur',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          accountEmail: Text(
            widget.currentUser['role'] ?? 'Opérateur',
            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ),

        // Scrollable List of Navigation Items
        Expanded(
          child: ListView.builder(
            itemCount: _navigationItems.length,
            itemBuilder: (context, index) {
              final item = _navigationItems[index];
              final isSelected = _selectedIndex == index;

              return ListTile(
                leading: Icon(
                  item['icon'] as IconData,
                  color: isSelected ? AppColors.primary : AppColors.slate700,
                ),
                title: Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.slate900,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  if (inDrawer) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),

        const Divider(height: 1),

        // Logout tile
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.danger),
          title: const Text(
            'Déconnexion',
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            if (inDrawer) {
              Navigator.pop(context);
            }
            _confirmLogout(context);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.water_drop, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'Usine d\'Eau',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hors Ligne',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
      ),
      drawer: !isDesktop
          ? Drawer(
              child: _buildDrawerContent(context, true),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 260,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: _buildDrawerContent(context, false),
              ),
            ),
          Expanded(
            child: widget.pageBuilder(_selectedIndex),
          ),
        ],
      ),
    );
  }
}
