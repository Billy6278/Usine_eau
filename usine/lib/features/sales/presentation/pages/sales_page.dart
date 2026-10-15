import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class SalesPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const SalesPage({super.key, required this.currentUser});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'GNF ',
    decimalDigits: 0,
    locale: 'fr_FR',
  );

  @override
  void initState() {
    super.initState();
    _loadSales();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getVentes();
      setState(() {
        _sales = data;
        _filteredSales = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSales = _sales.where((s) {
        final client = (s['client_nom'] ?? '').toString().toLowerCase();
        final code = (s['id'] ?? '').toString();
        final total = (s['total_net'] ?? '').toString();
        return client.contains(query) || code.contains(query) || total.contains(query);
      }).toList();
    });
  }

  void _showSaleDetails(int id, String clientNom) async {
    final lines = await DatabaseHelper.instance.getVenteLignes(id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Détails Vente N° $id - $clientNom'),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: lines.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                final line = lines[idx];
                return ListTile(
                  title: Text(line['produit_nom'] ?? ''),
                  subtitle: Text('${line['quantite']} x ${_currencyFormat.format(line['prix_unitaire_applique'])}'),
                  trailing: Text(
                    _currencyFormat.format(line['total_ligne']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showNewSaleDialog() async {
    final clients = await DatabaseHelper.instance.getClients();
    final products = await DatabaseHelper.instance.getProducts(finishedOnly: true);

    if (!mounted) return;

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter un client dans le module Clients.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter un produit fini dans le module Stock.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return _NewSaleWizard(
          clients: clients,
          products: products,
          currentUser: widget.currentUser,
          onSuccess: () {
            _loadSales();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des Ventes',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Enregistrez les factures de caisse et suivez l\'historique des ventes d\'eau.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showNewSaleDialog,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Nouvelle Vente'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate400.withValues(alpha: 0.05),
                    spreadRadius: 2,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une vente par client, montant ou numéro...',
                  prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune vente enregistrée',
                                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ListView.separated(
                              itemCount: _filteredSales.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = _filteredSales[index];
                                final date = DateTime.tryParse(s['date_vente'] ?? '') ?? DateTime.now();
                                final double total = s['total_net'] ?? 0.0;
                                final status = s['statut_paiement'] ?? 'CREDIT';

                                Color statusBg = Colors.grey.shade100;
                                Color statusFg = Colors.grey.shade700;
                                if (status == 'PAYE') {
                                  statusBg = Colors.green.shade50;
                                  statusFg = AppColors.success;
                                } else if (status == 'PARTIEL') {
                                  statusBg = Colors.orange.shade50;
                                  statusFg = AppColors.warning;
                                } else if (status == 'CREDIT') {
                                  statusBg = Colors.red.shade50;
                                  statusFg = AppColors.danger;
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  title: Text(
                                    'Vente N° ${s['id']} - ${s['client_nom']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate900),
                                  ),
                                  subtitle: Text(
                                    'Par ${s['operateur_nom']} - ${_dateFormat.format(date)}',
                                    style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _currencyFormat.format(total),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: statusFg,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => _showSaleDetails(s['id'], s['client_nom']),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSaleWizard extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic> currentUser;
  final VoidCallback onSuccess;

  const _NewSaleWizard({
    required this.clients,
    required this.products,
    required this.currentUser,
    required this.onSuccess,
  });

  @override
  State<_NewSaleWizard> createState() => _NewSaleWizardState();
}

class _NewSaleWizardState extends State<_NewSaleWizard> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedClientId;
  final List<Map<String, dynamic>> _items = [];
  double _discount = 0.0;
  double _amountPaid = 0.0;
  String _paymentStatus = 'PAYE';
  final TextEditingController _amountPaidController = TextEditingController();
  bool _isAmountPaidEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.clients.isNotEmpty) {
      _selectedClientId = widget.clients.first['id'] as int?;
    }
    _addItemLine();
    _updateAmountPaid();
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  void _updateAmountPaid() {
    if (!_isAmountPaidEdited) {
      final net = _netTotal;
      _amountPaid = net;
      _amountPaidController.text = net.toStringAsFixed(0);
      _paymentStatus = 'PAYE';
    }
  }

  void _addItemLine() {
    if (widget.products.isEmpty) return;
    setState(() {
      _items.add({
        'product_id': widget.products.first['id'] as int,
        'quantity': 1,
      });
      _updateAmountPaid();
    });
  }

  void _removeItemLine(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
      _updateAmountPaid();
    });
  }

  double get _grossTotal {
    double total = 0.0;
    for (var item in _items) {
      final pId = item['product_id'] as int;
      final p = widget.products.firstWhere((prod) => prod['id'] == pId, orElse: () => widget.products.first);
      final qty = item['quantity'] as int;
      final price = (p['prix_unitaire'] as num?)?.toDouble() ?? 0.0;
      total += qty * price;
    }
    return total;
  }

  double get _netTotal => (_grossTotal - _discount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    // Make sure _selectedClientId is valid and exists in widget.clients
    final currentClientId = widget.clients.any((c) => c['id'] == _selectedClientId)
        ? _selectedClientId
        : (widget.clients.isNotEmpty ? widget.clients.first['id'] as int? : null);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.point_of_sale, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Facturer une Vente'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 550 : double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Selector
                DropdownButtonFormField<int>(
                  value: currentClientId,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: widget.clients.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int?,
                      child: Text(c['nom']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedClientId = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Articles de la facture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),

                // Dynamic lines of items
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    final pId = item['product_id'] as int?;
                    final currentProductId = widget.products.any((p) => p['id'] == pId)
                        ? pId
                        : (widget.products.isNotEmpty ? widget.products.first['id'] as int? : null);

                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: currentProductId,
                            decoration: const InputDecoration(labelText: 'Produit fini'),
                            items: widget.products.map((p) {
                              final stock = (p['stock_actuel'] as num?)?.toDouble() ?? 0.0;
                              return DropdownMenuItem<int>(
                                value: p['id'] as int?,
                                child: Text('${p['nom']} (Stock: ${stock.toStringAsFixed(0)})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item['product_id'] = val;
                                _updateAmountPaid();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: item['quantity'].toString(),
                            decoration: const InputDecoration(labelText: 'Qté'),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Requis';
                              final qty = int.tryParse(val);
                              if (qty == null || qty <= 0) return '> 0';
                              return null;
                            },
                            onChanged: (val) {
                              final qty = int.tryParse(val) ?? 1;
                              setState(() {
                                item['quantity'] = qty;
                                _updateAmountPaid();
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                          onPressed: () => _removeItemLine(idx),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _addItemLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un produit'),
                ),
                const Divider(height: 24),

                // Financial values
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Brut:'),
                    Text('${_grossTotal.toStringAsFixed(0)} GNF', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Remise (GNF)', prefixIcon: Icon(Icons.discount)),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      _discount = double.tryParse(val) ?? 0.0;
                      _updateAmountPaid();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net à payer:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_netTotal.toStringAsFixed(0)} GNF',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountPaidController,
                  decoration: const InputDecoration(labelText: 'Montant encaissé (GNF)', prefixIcon: Icon(Icons.payments)),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Requis';
                    final amt = double.tryParse(val);
                    if (amt == null || amt < 0) return 'Montant invalide';
                    return null;
                  },
                  onChanged: (val) {
                    setState(() {
                      _isAmountPaidEdited = true;
                      _amountPaid = double.tryParse(val) ?? 0.0;
                      if (_amountPaid >= _netTotal) {
                        _paymentStatus = 'PAYE';
                      } else if (_amountPaid > 0) {
                        _paymentStatus = 'PARTIEL';
                      } else {
                        _paymentStatus = 'CREDIT';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Statut de paiement calculé:'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _paymentStatus == 'PAYE'
                            ? Colors.green.shade50
                            : (_paymentStatus == 'PARTIEL' ? Colors.orange.shade50 : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _paymentStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _paymentStatus == 'PAYE'
                              ? AppColors.success
                              : (_paymentStatus == 'PARTIEL' ? AppColors.warning : AppColors.danger),
                        ),
                      ),
                    ),
                  ],
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
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // 1. Stock check
              for (var item in _items) {
                final pId = item['product_id'] as int;
                final p = widget.products.firstWhere((prod) => prod['id'] == pId, orElse: () => widget.products.first);
                final qty = item['quantity'] as int;
                final stock = (p['stock_actuel'] as num?)?.toDouble() ?? 0.0;
                if (qty > stock) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Stock insuffisant pour ${p['nom']} ! Stock disponible : ${stock.toStringAsFixed(0)}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
              }

              // 2. Perform write
              final success = await DatabaseHelper.instance.recordVente(
                clientId: currentClientId!,
                operateurId: widget.currentUser['id'],
                totalBrut: _grossTotal,
                remise: _discount,
                montantPaye: _amountPaid,
                statutPaiement: _paymentStatus,
                details: _items.map((it) {
                  final pId = it['product_id'] as int;
                  final p = widget.products.firstWhere((prod) => prod['id'] == pId, orElse: () => widget.products.first);
                  return {
                    'produit_id': pId,
                    'quantite': it['quantity'],
                    'prix_unitaire': (p['prix_unitaire'] as num?)?.toDouble() ?? 0.0,
                  };
                }).toList(),
              );

              if (success) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Vente enregistrée avec succès.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                widget.onSuccess();
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Erreur de base de données.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }
          },
          child: const Text('Valider la facture'),
        ),
      ],
    );
  }
}
