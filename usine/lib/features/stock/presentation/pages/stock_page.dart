import 'package:flutter/material.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _finishedProducts = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final finished = await DatabaseHelper.instance.getProducts(finishedOnly: true);
      final raw = await DatabaseHelper.instance.getProducts(rawOnly: true);
      setState(() {
        _finishedProducts = finished;
        _rawMaterials = raw;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStockStatusBadge(double current, double threshold) {
    Color badgeColor = AppColors.success;
    String label = 'Normal';

    if (current <= threshold / 2) {
      badgeColor = AppColors.danger;
      label = 'Critique';
    } else if (current <= threshold) {
      badgeColor = AppColors.warning;
      label = 'Faible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAdjustStockDialog() {
    final allItems = [..._finishedProducts, ..._rawMaterials];
    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun article de stock disponible. Veuillez d\'abord ajouter un produit fini ou une matière première.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    int? selectedItemId = allItems.first['id'] as int?;
    bool isEntry = true; // true = Entry (Add), false = Exit (Deduct)
    double qty = 0;
    String reason = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.inventory, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Ajustement du Stock'),
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
                        // Product Dropdown
                        DropdownButtonFormField<int>(
                          value: selectedItemId,
                          decoration: const InputDecoration(labelText: 'Article'),
                          items: allItems.map((item) {
                            final isRaw = item['est_matiere_premiere'] == 1;
                            return DropdownMenuItem<int>(
                              value: item['id'] as int,
                              child: Text('${item['nom']} (${isRaw ? 'Matière P.' : 'Produit F.'})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedItemId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Veuillez sélectionner un article' : null,
                        ),
                        const SizedBox(height: 16),

                      // Toggle Movement Type
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Entrée (+)')),
                              selected: isEntry,
                              selectedColor: AppColors.success.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isEntry ? AppColors.success : AppColors.slate700,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                setDialogState(() {
                                  isEntry = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Sortie (-)')),
                              selected: !isEntry,
                              selectedColor: AppColors.danger.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: !isEntry ? AppColors.danger : AppColors.slate700,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                setDialogState(() {
                                  isEntry = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quantity
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          prefixIcon: Icon(Icons.numbers),
                          hintText: 'Ex: 50',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requis';
                          final val = double.tryParse(value);
                          if (val == null || val <= 0) return 'Nombre valide supérieur à 0';
                          return null;
                        },
                        onSaved: (val) => qty = double.parse(val!),
                      ),
                      const SizedBox(height: 16),

                      // Reason / Description
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Motif de l\'ajustement',
                          prefixIcon: Icon(Icons.notes),
                          hintText: 'Ex: Inventaire physique, casse, perte',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Le motif est obligatoire';
                          return null;
                        },
                        onSaved: (val) => reason = val ?? '',
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

                      final finalQty = isEntry ? qty : -qty;
                      final typeLabel = isEntry ? 'Entrée manuelle' : 'Sortie manuelle';

                      await DatabaseHelper.instance.adjustStock(
                        selectedItemId!,
                        finalQty,
                        '$typeLabel : $reason',
                      );

                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Ajustement de stock enregistré avec succès.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      _loadData();
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

  void _showProductDialog({Map<String, dynamic>? product}) {
    final formKey = GlobalKey<FormState>();
    String nom = product?['nom'] ?? '';
    String codeBarres = product?['code_barres'] ?? '';
    bool estMatierePremiere = product != null 
        ? (product['est_matiere_premiere'] == 1) 
        : (_tabController.index == 1);
    double volumeLitres = (product?['volume_litres'] as num?)?.toDouble() ?? 0.0;
    double prixUnitaire = (product?['prix_unitaire'] as num?)?.toDouble() ?? 0.0;
    double coutEstimeProduction = (product?['cout_estime_production'] as num?)?.toDouble() ?? 0.0;
    double stockActuel = (product?['stock_actuel'] as num?)?.toDouble() ?? 0.0;
    double stockSeuil = (product?['stock_seuil'] as num?)?.toDouble() ?? 10.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(product == null ? Icons.add_box : Icons.edit, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(product == null ? 'Nouveau Produit / Matière' : 'Modifier l\'Article'),
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
                          initialValue: nom,
                          decoration: const InputDecoration(
                            labelText: 'Nom de l\'article',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => nom = val!.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: codeBarres,
                          decoration: const InputDecoration(
                            labelText: 'Code Barres',
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          onSaved: (val) => codeBarres = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Est-ce une matière première ?'),
                          subtitle: Text(estMatierePremiere ? 'Oui (Matière Première)' : 'Non (Produit Fini)'),
                          value: estMatierePremiere,
                          activeColor: AppColors.primary,
                          onChanged: product != null ? null : (val) {
                            setDialogState(() {
                              estMatierePremiere = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!estMatierePremiere) ...[
                          TextFormField(
                            initialValue: volumeLitres > 0 ? volumeLitres.toString() : '',
                            decoration: const InputDecoration(
                              labelText: 'Volume en litres (Ex: 0.5, 1.5)',
                              prefixIcon: Icon(Icons.local_drink_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Requis pour les produits finis';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed < 0) return 'Nombre valide';
                              return null;
                            },
                            onSaved: (val) => volumeLitres = double.parse(val!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: prixUnitaire > 0 ? prixUnitaire.toStringAsFixed(0) : '',
                            decoration: const InputDecoration(
                              labelText: 'Prix unitaire de vente (GNF)',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Requis pour les produits finis';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed < 0) return 'Nombre valide';
                              return null;
                            },
                            onSaved: (val) => prixUnitaire = double.parse(val!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: coutEstimeProduction > 0 ? coutEstimeProduction.toStringAsFixed(0) : '',
                            decoration: const InputDecoration(
                              labelText: 'Coût estimé de production (GNF)',
                              prefixIcon: Icon(Icons.trending_up),
                            ),
                            keyboardType: TextInputType.number,
                            onSaved: (val) => coutEstimeProduction = (val != null && val.isNotEmpty) ? double.parse(val) : 0.0,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          initialValue: stockActuel.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Stock actuel / initial',
                            prefixIcon: Icon(Icons.warehouse_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Requis';
                            final parsed = double.tryParse(val);
                            if (parsed == null || parsed < 0) return 'Nombre valide';
                            return null;
                          },
                          onSaved: (val) => stockActuel = double.parse(val!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: stockSeuil.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Seuil d\'alerte',
                            prefixIcon: Icon(Icons.warning_amber_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Requis';
                            final parsed = double.tryParse(val);
                            if (parsed == null || parsed < 0) return 'Nombre valide';
                            return null;
                          },
                          onSaved: (val) => stockSeuil = double.parse(val!),
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

                      final Map<String, dynamic> row = {
                        if (product != null) 'id': product['id'],
                        'nom': nom,
                        'code_barres': codeBarres.isNotEmpty ? codeBarres : null,
                        'est_matiere_premiere': estMatierePremiere ? 1 : 0,
                        'categorie_id': estMatierePremiere ? 2 : 1,
                        'volume_litres': estMatierePremiere ? 0.0 : volumeLitres,
                        'prix_unitaire': estMatierePremiere ? 0.0 : prixUnitaire,
                        'cout_estime_production': estMatierePremiere ? 0.0 : coutEstimeProduction,
                        'stock_actuel': stockActuel,
                        'stock_seuil': stockSeuil,
                      };

                      try {
                        if (product == null) {
                          await DatabaseHelper.instance.insertProduct(row);
                        } else {
                          await DatabaseHelper.instance.updateProduct(row);
                        }
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(product == null ? 'Produit ajouté avec succès.' : 'Produit mis à jour.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        _loadData();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString()}'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
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

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer l\'article "$name" ?\nCette action peut perturber l\'historique si l\'article est référencé.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await DatabaseHelper.instance.deleteProduct(id);
                  navigator.pop();
                  _loadData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression: ${e.toString()}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Aucun article dans cette catégorie',
              style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Article', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Code Barres', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Stock Actuel', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Seuil Alerte', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: items.map((item) {
                final double stock = (item['stock_actuel'] as num?)?.toDouble() ?? 0.0;
                final double threshold = (item['stock_seuil'] as num?)?.toDouble() ?? 0.0;

                return DataRow(
                  cells: [
                    DataCell(Text(item['nom'] ?? '')),
                    DataCell(Text(item['code_barres'] ?? 'N/A', style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(
                      Text(
                        stock.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: stock <= threshold / 2
                              ? AppColors.danger
                              : (stock <= threshold ? AppColors.warning : AppColors.slate700),
                        ),
                      ),
                    ),
                    DataCell(Text(threshold.toStringAsFixed(0))),
                    DataCell(_buildStockStatusBadge(stock, threshold)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                            onPressed: () => _showProductDialog(product: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                            onPressed: () => _confirmDelete(item['id'], item['nom']),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des Stocks',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Suivi en temps réel des bouteilles disponibles et des intrants de fabrication.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showProductDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau Produit'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.slate700,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: _showAdjustStockDialog,
                      icon: const Icon(Icons.tune),
                      label: const Text('Ajuster le Stock'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.slate400,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Produits Finis', icon: Icon(Icons.water_drop)),
                Tab(text: 'Matières Premières', icon: Icon(Icons.widgets_outlined)),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStockTable(_finishedProducts),
                        _buildStockTable(_rawMaterials),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
