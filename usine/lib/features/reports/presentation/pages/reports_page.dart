import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  String _timeFilter = 'Semaine'; // Semaine, Mois, Année

  // Aggregated data
  double _totalProduced = 0.0;
  double _totalLost = 0.0;
  double _totalSales = 0.0;
  double _totalExpenses = 0.0;
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _lowStockItems = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'GNF ',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final dbHelper = DatabaseHelper.instance;

      // 1. Load general dashboard metrics (as representative today)
      final stats = await dbHelper.getDashboardStats();

      // 2. Load products to count stock levels
      final products = await dbHelper.getProducts();
      final lowStock = products.where((p) {
        final current = (p['stock_actuel'] as num?)?.toDouble() ?? 0.0;
        final threshold = (p['stock_seuil'] as num?)?.toDouble() ?? 0.0;
        return current <= threshold;
      }).toList();

      // 3. Load all productions for totals
      final productions = await dbHelper.getProductions();
      double prodSum = 0.0;
      double lostSum = 0.0;
      for (var p in productions) {
        prodSum += (p['quantite_produite'] as num).toDouble();
        lostSum += (p['quantite_perdue'] as num).toDouble();
      }

      // 4. Load all finances for summaries
      final incomes = await dbHelper.getRevenus();
      final expenses = await dbHelper.getDepenses();

      double incSum = incomes.fold(0.0, (s, i) => s + ((i['montant'] as num?)?.toDouble() ?? 0.0));
      double expSum = expenses.fold(0.0, (s, e) => s + ((e['montant'] as num?)?.toDouble() ?? 0.0));

      setState(() {
        _totalProduced = prodSum;
        _totalLost = lostSum;
        _totalSales = incSum;
        _totalExpenses = expSum;
        _lowStockItems = lowStock;
        _chartData = List<Map<String, dynamic>>.from(stats['weekly_sales']);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Time Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rapports et Statistiques',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                            ),
                            Text(
                              'Synthèse globale de l\'usine et des finances locales.',
                              style: TextStyle(color: AppColors.slate400),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: _timeFilter,
                          items: ['Semaine', 'Mois', 'Année'].map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _timeFilter = val;
                                _loadReportData();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Metrics row
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isDesktop ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isDesktop ? 2 : 1.3,
                      children: [
                        _buildReportCard(
                          'PRODUCTION TOTALÉ',
                          '${_totalProduced.toStringAsFixed(0)} Unités',
                          AppColors.primary,
                          Icons.water_drop,
                        ),
                        _buildReportCard(
                          'PERTES FABRICATION',
                          '${_totalLost.toStringAsFixed(0)} Unités',
                          AppColors.danger,
                          Icons.trending_down,
                        ),
                        _buildReportCard(
                          'CHIFFRE D\'AFFAIRES',
                          _currencyFormat.format(_totalSales),
                          AppColors.success,
                          Icons.monetization_on,
                        ),
                        _buildReportCard(
                          'DÉPENSES TOTALES',
                          _currencyFormat.format(_totalExpenses),
                          AppColors.warning,
                          Icons.payments,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chart & list sections
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isDesktop ? 2 : 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rapport de ventes hebdomadaires',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        height: 250,
                                        child: _buildWeeklySalesChart(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                  height: 295,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alerte : Rupture de Stock Imminente',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: _lowStockItems.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'Tous les stocks sont corrects.',
                                                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                                ),
                                              )
                                            : ListView.separated(
                                                itemCount: _lowStockItems.length,
                                                separatorBuilder: (_, __) => const Divider(),
                                                itemBuilder: (context, idx) {
                                                  final item = _lowStockItems[idx];
                                                  final current = (item['stock_actuel'] as num).toDouble();
                                                  return ListTile(
                                                    contentPadding: EdgeInsets.zero,
                                                    leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                                                    title: Text(item['nom'] ?? ''),
                                                    subtitle: Text('Stock: ${current.toStringAsFixed(0)} (Seuil: ${item['stock_seuil']})'),
                                                  );
                                                },
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

  Widget _buildReportCard(String title, String value, Color color, IconData icon) {
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
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: AppColors.slate900, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySalesChart() {
    final List<String> days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final Map<int, double> salesMap = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    double maxSale = 1000.0;

    for (var sale in _chartData) {
      final day = int.tryParse(sale['day_of_week']?.toString() ?? '0') ?? 0;
      final total = double.tryParse(sale['daily_total']?.toString() ?? '0') ?? 0.0;
      salesMap[day] = total;
      if (total > maxSale) {
        maxSale = total;
      }
    }

    final List<int> sortedDaysKeys = [1, 2, 3, 4, 5, 6, 0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: sortedDaysKeys.map((dayKey) {
        final amount = salesMap[dayKey] ?? 0.0;
        final pct = amount / maxSale;
        final dayName = days[dayKey];

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                amount > 0 ? '${(amount / 1000).toStringAsFixed(0)}k' : '',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: (pct * 160).clamp(5, 160).toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dayName,
                style: const TextStyle(fontSize: 12, color: AppColors.slate700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
