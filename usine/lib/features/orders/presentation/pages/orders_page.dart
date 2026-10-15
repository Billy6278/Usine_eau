import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getCommandes();
      setState(() {
        _orders = data;
        _filteredOrders = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrders = _orders.where((o) {
        final client = (o['client_nom'] ?? '').toString().toLowerCase();
        final code = (o['numero_commande'] ?? '').toString().toLowerCase();
        final prod = (o['produit_nom'] ?? '').toString().toLowerCase();
        return client.contains(query) || code.contains(query) || prod.contains(query);
      }).toList();
    });
  }

  void _showOrderDialog({Map<String, dynamic>? order}) async {
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

    final formKey = GlobalKey<FormState>();
    int? selectedClientId = clients.first['id'] as int?;
    int? selectedProductId = products.first['id'] as int?;
    double qty = order != null ? (order['quantite_demandee'] as num).toDouble() : 50.0;
    String status = order?['statut'] ?? 'EN_ATTENTE';

    if (order != null) {
      selectedClientId = order['client_id'] as int?;
      selectedProductId = order['produit_id'] as int?;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentClientId = clients.any((c) => c['id'] == selectedClientId)
                ? selectedClientId
                : (clients.isNotEmpty ? clients.first['id'] as int? : null);

            final currentProductId = products.any((p) => p['id'] == selectedProductId)
                ? selectedProductId
                : (products.isNotEmpty ? products.first['id'] as int? : null);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.shopping_bag, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(order == null ? 'Nouvelle Commande' : 'Modifier la Commande'),
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
                        DropdownButtonFormField<int>(
                          value: currentClientId,
                          decoration: const InputDecoration(labelText: 'Client'),
                          items: clients.map((c) {
                            return DropdownMenuItem<int>(value: c['id'] as int?, child: Text(c['nom']));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedClientId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Veuillez sélectionner un client' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: currentProductId,
                          decoration: const InputDecoration(labelText: 'Produit commandé'),
                          items: products.map((p) {
                            return DropdownMenuItem<int>(value: p['id'] as int?, child: Text(p['nom']));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProductId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Veuillez sélectionner un produit' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: qty.toString(),
                          decoration: const InputDecoration(labelText: 'Quantité commandée (bouteilles/unités)', prefixIcon: Icon(Icons.onetwothree)),
                          keyboardType: TextInputType.number,
                          validator: (val) => val == null || double.tryParse(val) == null || double.parse(val) <= 0 ? 'Nombre valide > 0' : null,
                          onSaved: (val) => qty = double.parse(val!),
                        ),
                        if (order != null) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(labelText: 'Statut de commande'),
                            items: const [
                              DropdownMenuItem(value: 'EN_ATTENTE', child: Text('En attente')),
                              DropdownMenuItem(value: 'EN_COURS', child: Text('En cours')),
                              DropdownMenuItem(value: 'LIVREE', child: Text('Livrée')),
                              DropdownMenuItem(value: 'ANNULEE', child: Text('Annulée')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                status = val ?? 'EN_ATTENTE';
                              });
                            },
                          ),
                        ],
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

                      if (order == null) {
                        final rand = Random().nextInt(900) + 100;
                        final numero = 'CMD-${DateTime.now().year}-$rand';
                        await DatabaseHelper.instance.insertCommande({
                          'numero_commande': numero,
                          'client_id': currentClientId,
                          'produit_id': currentProductId,
                          'quantite_demandee': qty,
                          'statut': 'EN_ATTENTE',
                        });
                      } else {
                        await DatabaseHelper.instance.updateCommande({
                          'id': order['id'],
                          'numero_commande': order['numero_commande'],
                          'client_id': currentClientId,
                          'produit_id': currentProductId,
                          'quantite_demandee': qty,
                          'statut': status,
                        });
                      }

                      navigator.pop();
                      _loadOrders();
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int id, String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supprimer la commande'),
          content: Text('Voulez-vous supprimer la commande "$code" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await DatabaseHelper.instance.deleteCommande(id);
                navigator.pop();
                _loadOrders();
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
                      'Gestion des Commandes',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Suivez les commandes clients et planifiez les expéditions.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showOrderDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle Commande'),
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
                  hintText: 'Rechercher une commande par numéro ou client...',
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
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune commande répertoriée',
                                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final o = _filteredOrders[index];
                            final date = DateTime.tryParse(o['date_commande'] ?? '') ?? DateTime.now();
                            final statut = o['statut'] ?? 'EN_ATTENTE';

                            Color tagBg = Colors.grey.shade100;
                            Color tagFg = Colors.grey.shade700;
                            if (statut == 'LIVREE') {
                              tagBg = Colors.green.shade50;
                              tagFg = AppColors.success;
                            } else if (statut == 'EN_COURS') {
                              tagBg = Colors.blue.shade50;
                              tagFg = AppColors.primary;
                            } else if (statut == 'ANNULEE') {
                              tagBg = Colors.red.shade50;
                              tagFg = AppColors.danger;
                            }

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade100, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                o['numero_commande'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
                                                child: Text(
                                                  statut,
                                                  style: TextStyle(color: tagFg, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Client: ${o['client_nom']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Produit: ${o['quantite_demandee']} bouteilles de ${o['produit_nom']}',
                                            style: const TextStyle(color: AppColors.slate700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Enregistré le : ${_dateFormat.format(date)}',
                                            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppColors.primary),
                                          onPressed: () => _showOrderDialog(order: o),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: AppColors.danger),
                                          onPressed: () => _confirmDelete(o['id'], o['numero_commande']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
