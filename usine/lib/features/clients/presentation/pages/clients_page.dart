import 'package:flutter/material.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getClients();
      setState(() {
        _clients = data;
        _filteredClients = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((c) {
        final name = (c['nom'] ?? '').toString().toLowerCase();
        final phone = (c['telephone'] ?? '').toString().toLowerCase();
        final addr = (c['adresse'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query) || addr.contains(query);
      }).toList();
    });
  }

  void _showClientDialog({Map<String, dynamic>? client}) {
    final formKey = GlobalKey<FormState>();
    String nom = client?['nom'] ?? '';
    String telephone = client?['telephone'] ?? '';
    String email = client?['email'] ?? '';
    String adresse = client?['adresse'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(client == null ? Icons.person_add : Icons.edit_note, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(client == null ? 'Ajouter un client' : 'Modifier le client'),
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
                    decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person)),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                    onSaved: (val) => nom = val!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: telephone,
                    decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                    onSaved: (val) => telephone = val?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: email,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (val) => email = val?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: adresse,
                    decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on)),
                    onSaved: (val) => adresse = val?.trim() ?? '',
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

                  final row = {
                    if (client != null) 'id': client['id'],
                    'nom': nom,
                    'telephone': telephone,
                    'email': email,
                    'adresse': adresse,
                  };

                  if (client == null) {
                    await DatabaseHelper.instance.insertClient(row);
                  } else {
                    await DatabaseHelper.instance.updateClient(row);
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(client == null ? 'Client ajouté avec succès.' : 'Client mis à jour.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadClients();
                }
              },
              child: const Text('Valider'),
            ),
          ],
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
          content: Text('Voulez-vous vraiment supprimer le client "$name" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await DatabaseHelper.instance.deleteClient(id);
                navigator.pop();
                _loadClients();
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

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
                      'Gestion des Clients',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Consultez et éditez votre fichier clients locaux.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showClientDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nouveau Client'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
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
                  hintText: 'Rechercher un client par nom, téléphone ou adresse...',
                  prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Client Cards or Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredClients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun client trouvé',
                                style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildClientTable()
                          : _buildClientList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Téléphone', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Adresse', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredClients.map((client) {
            return DataRow(
              cells: [
                DataCell(Text(client['nom'] ?? '')),
                DataCell(Text(client['telephone'] ?? 'Non renseigné')),
                DataCell(Text(client['email'] ?? 'Non renseigné')),
                DataCell(Text(client['adresse'] ?? 'Non renseigné')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _showClientDialog(client: client),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => _confirmDelete(client['id'], client['nom']),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClientList() {
    return ListView.separated(
      itemCount: _filteredClients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = _filteredClients[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: AppColors.primary),
            ),
            title: Text(client['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client['telephone']?.isNotEmpty == true)
                  Text('Tél: ${client['telephone']}', style: const TextStyle(fontSize: 12)),
                if (client['adresse']?.isNotEmpty == true)
                  Text('Adresse: ${client['adresse']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () => _showClientDialog(client: client),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => _confirmDelete(client['id'], client['nom']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
