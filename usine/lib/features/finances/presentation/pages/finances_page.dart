import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class FinancesPage extends StatefulWidget {
  const FinancesPage({super.key});

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'GNF ',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFinanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
      final inc = await DatabaseHelper.instance.getRevenus();
      final exp = await DatabaseHelper.instance.getDepenses();
      setState(() {
        _incomes = inc;
        _expenses = exp;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalIncomes {
    return _incomes.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0.0));
  }

  double get _totalExpenses {
    return _expenses.fold(0.0, (sum, item) => sum + ((item['montant'] as num?)?.toDouble() ?? 0.0));
  }

  double get _netProfit => _totalIncomes - _totalExpenses;

  void _showAddTransactionDialog(bool isIncome) {
    final formKey = GlobalKey<FormState>();
    double montant = 0.0;
    String desc = '';
    String cat = isIncome ? 'Vente Diverse' : 'Achat Matières';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isIncome ? Icons.trending_up : Icons.trending_down, color: isIncome ? AppColors.success : AppColors.danger),
              const SizedBox(width: 8),
              Text(isIncome ? 'Enregistrer une Recette' : 'Déclarer une Dépense'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 600 ? 550 : double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Montant (GNF)', prefixIcon: Icon(Icons.monetization_on)),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || double.tryParse(val) == null || double.parse(val) <= 0 ? 'Nombre valide > 0' : null,
                    onSaved: (val) => montant = double.parse(val!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: cat,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: (isIncome
                            ? ['Vente d\'eau', 'Vente Diverse', 'Subvention', 'Autre']
                            : ['Carburant', 'Maintenance', 'Salaires', 'Achat Matières', 'Logistique', 'Autre'])
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) cat = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description / Note', prefixIcon: Icon(Icons.notes)),
                    onSaved: (val) => desc = val ?? '',
                  ),
                ],
              ),
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final navigator = Navigator.of(context);

                  if (isIncome) {
                    await DatabaseHelper.instance.insertRevenu({
                      'categorie': cat,
                      'montant': montant,
                      'description': desc,
                      'date_revenu': DateTime.now().toIso8601String(),
                    });
                  } else {
                    await DatabaseHelper.instance.insertDepense({
                      'categorie': cat,
                      'montant': montant,
                      'description': desc,
                      'date_depense': DateTime.now().toIso8601String(),
                    });
                  }

                  navigator.pop();
                  _loadFinanceData();
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(int id, bool isIncome) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supprimer la transaction'),
          content: const Text('Voulez-vous supprimer cette ligne d\'écriture comptable ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (isIncome) {
                  await DatabaseHelper.instance.deleteRevenu(id);
                } else {
                  await DatabaseHelper.instance.deleteDepense(id);
                }
                navigator.pop();
                _loadFinanceData();
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.slate400,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Recettes (Entrées)', icon: Icon(Icons.trending_up)),
                      Tab(text: 'Dépenses (Sorties)', icon: Icon(Icons.trending_down)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Financial Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'RECETTES TOTALES',
                          _currencyFormat.format(_totalIncomes),
                          AppColors.success,
                          Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'DÉPENSES TOTALES',
                          _currencyFormat.format(_totalExpenses),
                          AppColors.danger,
                          Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'RÉSULTAT NET',
                          _currencyFormat.format(_netProfit),
                          _netProfit >= 0 ? AppColors.success : AppColors.danger,
                          Icons.account_balance_wallet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Journaux Financiers Locaux',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                            onPressed: () => _showAddTransactionDialog(true),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter Recette'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            onPressed: () => _showAddTransactionDialog(false),
                            icon: const Icon(Icons.remove),
                            label: const Text('Déclarer Dépense'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionList(_incomes, true),
                        _buildTransactionList(_expenses, false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate400)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> list, bool isIncome) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.currency_exchange, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Aucune transaction enregistrée',
              style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        final rawDate = isIncome ? item['date_revenu'] : item['date_depense'];
        final date = DateTime.tryParse(rawDate ?? '') ?? DateTime.now();
        final double amount = item['montant'] ?? 0.0;
        final cat = item['categorie'] ?? '';
        final desc = item['description'] ?? '';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? AppColors.success : AppColors.danger,
            ),
            title: Text(
              cat,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 12)),
                Text(_dateFormat.format(date), style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.success : AppColors.danger,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: AppColors.danger),
                  onPressed: () => _confirmDelete(item['id'], isIncome),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
