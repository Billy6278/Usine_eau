import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _filteredDeliveries = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getLivraisons();
      setState(() {
        _deliveries = data;
        _filteredDeliveries = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDeliveries = _deliveries.where((d) {
        final code = (d['numero_livraison'] ?? '').toString().toLowerCase();
        final driver = (d['chauffeur'] ?? '').toString().toLowerCase();
        final vehicle = (d['vehicule'] ?? '').toString().toLowerCase();
        final client = (d['client_nom'] ?? '').toString().toLowerCase();
        return code.contains(query) || driver.contains(query) || vehicle.contains(query) || client.contains(query);
      }).toList();
    });
  }

  void _showAddDeliveryDialog() async {
    final orders = await DatabaseHelper.instance.getCommandes();
    final pendingOrders = orders.where((o) => o['statut'] == 'EN_ATTENTE' || o['statut'] == 'EN_COURS').toList();

    if (!mounted) return;

    if (pendingOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune commande en cours d\'attente de livraison !'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    int? selectedOrderId = pendingOrders.first['id'] as int?;
    String chauffeur = '';
    String vehicule = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentOrderId = pendingOrders.any((o) => o['id'] == selectedOrderId)
                ? selectedOrderId
                : (pendingOrders.isNotEmpty ? pendingOrders.first['id'] as int? : null);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.local_shipping, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Planifier une livraison'),
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
                          value: currentOrderId,
                          decoration: const InputDecoration(labelText: 'Commande concernée'),
                          items: pendingOrders.map((o) {
                            return DropdownMenuItem<int>(
                              value: o['id'] as int?,
                              child: Text('${o['numero_commande']} - ${o['client_nom']} (${o['quantite_demandee']} U)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedOrderId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Veuillez sélectionner une commande' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Chauffeur / Livreur', prefixIcon: Icon(Icons.person)),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => chauffeur = val!.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Véhicule', prefixIcon: Icon(Icons.car_rental)),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => vehicule = val!.trim(),
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

                      final rand = Random().nextInt(900) + 100;
                      final numero = 'LIV-${DateTime.now().year}-$rand';

                      // 1. Create Delivery
                      await DatabaseHelper.instance.insertLivraison({
                        'numero_livraison': numero,
                        'commande_id': currentOrderId,
                        'chauffeur': chauffeur,
                        'vehicule': vehicule,
                        'statut': 'PLANIFIEE',
                      });

                      // 2. Automatically update Order Status to EN_COURS
                      await DatabaseHelper.instance.updateCommandeStatus(currentOrderId!, 'EN_COURS');

                      navigator.pop();
                      _loadDeliveries();
                    }
                  },
                  child: const Text('Planifier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateStatus(int id, String newStatus) async {
    await DatabaseHelper.instance.updateLivraisonStatus(id, newStatus);
    _loadDeliveries();
  }

  void _confirmDelete(int id, String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supprimer la livraison'),
          content: Text('Voulez-vous supprimer le planning de livraison "$code" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await DatabaseHelper.instance.deleteLivraison(id);
                navigator.pop();
                _loadDeliveries();
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
                      'Planification des Livraisons',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Gérez l\'expédition des bouteilles d\'eau, assignez des chauffeurs et véhicules.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDeliveryDialog,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Planifier expédition'),
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
                  hintText: 'Rechercher par chauffeur, véhicule ou numéro de livraison...',
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
                  : _filteredDeliveries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune livraison planifiée',
                                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredDeliveries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final d = _filteredDeliveries[index];
                            final date = DateTime.tryParse(d['date_livraison'] ?? '') ?? DateTime.now();
                            final statut = d['statut'] ?? 'PLANIFIEE';

                            Color tagBg = Colors.grey.shade100;
                            Color tagFg = Colors.grey.shade700;
                            if (statut == 'LIVREE') {
                              tagBg = Colors.green.shade50;
                              tagFg = AppColors.success;
                            } else if (statut == 'EN_COURS') {
                              tagBg = Colors.blue.shade50;
                              tagFg = AppColors.primary;
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
                                                d['numero_livraison'] ?? '',
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
                                          Text('Client: ${d['client_nom']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Chauffeur: ${d['chauffeur']} | Véhicule: ${d['vehicule']}',
                                            style: const TextStyle(color: AppColors.slate700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Commande: ${d['numero_commande']} | Date: ${_dateFormat.format(date)}',
                                            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (statut == 'PLANIFIEE')
                                          IconButton(
                                            icon: const Icon(Icons.play_arrow, color: AppColors.primary),
                                            tooltip: 'Démarrer la livraison',
                                            onPressed: () => _updateStatus(d['id'], 'EN_COURS'),
                                          ),
                                        if (statut == 'EN_COURS')
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: AppColors.success),
                                            tooltip: 'Marquer comme livrée',
                                            onPressed: () => _updateStatus(d['id'], 'LIVREE'),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: AppColors.danger),
                                          onPressed: () => _confirmDelete(d['id'], d['numero_livraison']),
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
