import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class ProductionPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const ProductionPage({super.key, required this.currentUser});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  List<Map<String, dynamic>> _productions = [];
  List<Map<String, dynamic>> _finishedProducts = [];
  bool _isLoading = true;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prods = await DatabaseHelper.instance.getProductions();
      final finished = await DatabaseHelper.instance.getProducts(finishedOnly: true);
      setState(() {
        _productions = prods;
        _finishedProducts = finished;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddProductionDialog() {
    if (_finishedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord ajouter un produit fini dans le module Stock.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    int? selectedProductId = _finishedProducts.first['id'] as int?;
    int qty = 0;
    int qtyLost = 0;
    String remarks = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.factory, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Enregistrer une Production'),
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
                        // Product Selector
                        DropdownButtonFormField<int>(
                          value: selectedProductId,
                          decoration: const InputDecoration(
                            labelText: 'Produit fini obtenu',
                            prefixIcon: Icon(Icons.water_drop_outlined),
                          ),
                          items: _finishedProducts.map((p) {
                            return DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text(p['nom']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProductId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Veuillez sélectionner un produit' : null,
                        ),
                        const SizedBox(height: 16),

                        // Quantity Produced
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Quantité produite (unités)',
                            prefixIcon: Icon(Icons.add_chart),
                            hintText: 'Ex: 200',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Requis';
                            final val = int.tryParse(value);
                            if (val == null || val <= 0) return 'Nombre valide supérieur à 0';
                            return null;
                          },
                          onSaved: (val) => qty = int.parse(val!),
                        ),
                        const SizedBox(height: 16),

                        // Quantity Lost
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Pertes estimées (unités)',
                            prefixIcon: Icon(Icons.trending_down),
                            hintText: 'Ex: 2',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null; // Optional
                            final val = int.tryParse(value);
                            if (val == null || val < 0) return 'Nombre valide';
                            return null;
                          },
                          onSaved: (val) => qtyLost = val != null && val.isNotEmpty ? int.parse(val) : 0,
                        ),
                        const SizedBox(height: 16),

                        // Remarks
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Remarques / Observations',
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 2,
                          onSaved: (val) => remarks = val ?? '',
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
                      final messenger = ScaffoldMessenger.of(context);

                      final success = await DatabaseHelper.instance.recordProduction(
                        produitFiniId: selectedProductId!,
                        qty: qty,
                        qtyLost: qtyLost,
                        operateurId: widget.currentUser['id'],
                        remarks: remarks,
                      );

                      if (success) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Production enregistrée avec succès. Stocks mis à jour.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        _loadData();
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Erreur lors de l\'enregistrement de la production.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
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
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suivi de Production',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Enregistrez les lots d\'eau mis en bouteille et suivez la consommation des matières premières.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddProductionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Déclarer un Lot'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Production List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _productions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.factory, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun lot de production enregistré',
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
                              itemCount: _productions.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final prod = _productions[index];
                                final date = DateTime.tryParse(prod['date_production'] ?? '') ?? DateTime.now();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Icon(Icons.opacity, color: AppColors.primary),
                                  ),
                                  title: Text(
                                    '${prod['quantite_produite']} unités de ${prod['produit_nom']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate900),
                                  ),
                                  subtitle: Text(
                                    'Par ${prod['operateur_nom']} - ${_dateFormat.format(date)}',
                                    style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (prod['quantite_perdue'] > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '-${prod['quantite_perdue']} pertes',
                                            style: const TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      if (prod['remarques'] != null && prod['remarques'].toString().isNotEmpty)
                                        Text(
                                          prod['remarques'],
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 11,
                                            color: AppColors.slate400,
                                          ),
                                        ),
                                    ],
                                  ),
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
