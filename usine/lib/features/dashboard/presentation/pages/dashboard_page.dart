import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'GNF ',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await DatabaseHelper.instance.getDashboardStats();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Color? bgColor,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor ?? color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySalesChart(List<dynamic> rawSales) {
    // Week days in French starting Monday
    final List<String> days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

    // Map query result by day (0-6)
    final Map<int, double> salesMap = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    double maxSale = 1000.0; // Avoid division by zero

    for (var sale in rawSales) {
      final day = int.tryParse(sale['day_of_week']?.toString() ?? '0') ?? 0;
      final total = double.tryParse(sale['daily_total']?.toString() ?? '0') ?? 0.0;
      salesMap[day] = total;
      if (total > maxSale) {
        maxSale = total;
      }
    }

    // Sort to show last 7 days logically or just Mon-Sun
    // For simplicity, we show Mon-Sun
    final List<int> sortedDaysKeys = [1, 2, 3, 4, 5, 6, 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ventes Hebdomadaires (7 derniers jours)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: sortedDaysKeys.map((dayKey) {
              final salesAmount = salesMap[dayKey] ?? 0.0;
              final percentage = salesAmount / maxSale;
              final dayName = days[dayKey];

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      salesAmount > 0 ? '${(salesAmount / 1000).toStringAsFixed(0)}k' : '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      height: (percentage * 150).clamp(5, 150).toDouble(),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary,
                            AppColors.accent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _stats ?? {};
    final double prodLitres = stats['production_litres_today'] ?? 0.0;
    final double caToday = stats['ca_today'] ?? 0.0;
    final double profit = stats['net_profit_today'] ?? 0.0;
    final int alertCount = stats['alert_count'] ?? 0;
    final List<dynamic> weeklySales = stats['weekly_sales'] ?? [];
    final List<dynamic> recentActivities = stats['recent_activities'] ?? [];

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, Gérant',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Text(
                        'Voici l\'état de la production et des finances locales aujourd\'hui.',
                        style: TextStyle(color: AppColors.slate400),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.8 : 1.3,
                children: [
                  _buildKpiCard(
                    title: 'PRODUCTION DU JOUR',
                    value: '${prodLitres.toStringAsFixed(0)} Litres',
                    icon: Icons.water_drop,
                    color: AppColors.primary,
                  ),
                  _buildKpiCard(
                    title: 'CHIFFRE D\'AFFAIRES',
                    value: _currencyFormat.format(caToday),
                    icon: Icons.monetization_on,
                    color: AppColors.success,
                  ),
                  _buildKpiCard(
                    title: 'BÉNÉFICE ESTIMÉ',
                    value: _currencyFormat.format(profit),
                    icon: Icons.trending_up,
                    color: profit >= 0 ? AppColors.success : AppColors.danger,
                  ),
                  _buildKpiCard(
                    title: 'STOCK CRITIQUE',
                    value: '$alertCount Article${alertCount > 1 ? 's' : ''}',
                    icon: Icons.warning_amber_rounded,
                    color: alertCount > 0 ? AppColors.danger : AppColors.success,
                    bgColor: alertCount > 0 ? AppColors.danger.withOpacity(0.1) : null,
                    trailing: alertCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Alerte',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Chart and quick list section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly Sales Chart
                  Expanded(
                    flex: isDesktop ? 2 : 1,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          height: 250,
                          child: _buildWeeklySalesChart(weeklySales),
                        ),
                      ),
                    ),
                  ),

                  // Low stock items preview (only on desktop)
                  if (isDesktop) ...[
                    const SizedBox(width: 24),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: SizedBox(
                            height: 250,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Activités Système Récentes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.slate900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: recentActivities.isEmpty
                                      ? const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.info_outline, color: AppColors.slate400, size: 36),
                                              SizedBox(height: 8),
                                              Text(
                                                'Aucune activité récente',
                                                style: TextStyle(color: AppColors.slate400, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          child: Column(
                                            children: recentActivities.map((act) {
                                              final String type = act['type'] ?? '';
                                              final String subtype = act['subtype'] ?? '';
                                              final double qty = double.tryParse(act['quantite']?.toString() ?? '0') ?? 0.0;
                                              final String desc = act['description'] ?? '';
                                              final String rawDate = act['date'] ?? '';
                                              
                                              String title = '';
                                              String subtitle = '';
                                              IconData icon = Icons.info;
                                              Color iconColor = AppColors.primary;
                                              Color bgColor = AppColors.primaryLight;

                                              if (type == 'stock') {
                                                if (subtype == 'PRODUCTION') {
                                                  title = 'Production enregistrée';
                                                  subtitle = '$desc (+${qty.toStringAsFixed(0)} u)';
                                                  icon = Icons.water_drop;
                                                  iconColor = AppColors.primary;
                                                  bgColor = AppColors.primaryLight;
                                                } else if (subtype == 'VENTE') {
                                                  title = 'Vente effectuée';
                                                  subtitle = '$desc (${qty.toStringAsFixed(0)} u)';
                                                  icon = Icons.shopping_cart;
                                                  iconColor = AppColors.success;
                                                  bgColor = const Color(0xFFE8F5E9);
                                                } else {
                                                  title = 'Ajustement de stock';
                                                  subtitle = '$desc (${qty > 0 ? '+' : ''}${qty.toStringAsFixed(0)} u)';
                                                  icon = Icons.tune;
                                                  iconColor = Colors.orange;
                                                  bgColor = const Color(0xFFFFF3E0);
                                                }
                                              } else if (type == 'depense') {
                                                title = 'Dépense enregistrée';
                                                subtitle = '$subtype : ${qty.toStringAsFixed(0)} GNF';
                                                icon = Icons.trending_down;
                                                iconColor = AppColors.danger;
                                                bgColor = const Color(0xFFFFEbee);
                                              }

                                              String timeStr = '';
                                              try {
                                                final parsedDate = DateTime.parse(rawDate);
                                                timeStr = DateFormat('dd/MM HH:mm').format(parsedDate);
                                              } catch (_) {
                                                timeStr = rawDate;
                                              }

                                              return ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                leading: CircleAvatar(
                                                  backgroundColor: bgColor,
                                                  child: Icon(icon, color: iconColor, size: 20),
                                                ),
                                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                subtitle: Text('$subtitle • $timeStr', style: const TextStyle(fontSize: 12)),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
