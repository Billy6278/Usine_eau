import 'package:flutter/material.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class UsersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const UsersPage({super.key, required this.currentUser});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getUsers();
      setState(() {
        _users = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    // Security check: Only Admin can add/edit users
    final currentRole = widget.currentUser['role'] ?? 'OPERATEUR';
    if (currentRole != 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accès refusé ! Seul l\'Administrateur peut gérer les utilisateurs.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String nom = user?['nom'] ?? '';
    String identifiant = user?['identifiant'] ?? '';
    String telephone = user?['telephone'] ?? '';
    String email = user?['email'] ?? '';
    String role = user?['role'] ?? 'OPERATEUR';
    String motDePasse = ''; // Empty by default for edit

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(user == null ? Icons.person_add : Icons.manage_accounts, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(user == null ? 'Créer un utilisateur' : 'Modifier l\'utilisateur'),
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
                    initialValue: identifiant,
                    decoration: const InputDecoration(labelText: 'Identifiant (Username)', prefixIcon: Icon(Icons.alternate_email)),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                    onSaved: (val) => identifiant = val!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: user == null ? 'Code PIN de connexion' : 'Nouveau code PIN (laisser vide si inchangé)',
                      prefixIcon: const Icon(Icons.pin),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (val) {
                      if (user == null && (val == null || val.isEmpty)) return 'Requis';
                      return null;
                    },
                    onSaved: (val) => motDePasse = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: telephone,
                    decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                    onSaved: (val) => telephone = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: email,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (val) => email = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Rôle / Permissions'),
                    items: const [
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur')),
                      DropdownMenuItem(value: 'GERANT', child: Text('Gérant')),
                      DropdownMenuItem(value: 'OPERATEUR', child: Text('Caissier / Opérateur')),
                    ],
                    onChanged: (val) {
                      if (val != null) role = val;
                    },
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

                  final Map<String, dynamic> row = {
                    if (user != null) 'id': user['id'],
                    'nom': nom,
                    'identifiant': identifiant,
                    'telephone': telephone,
                    'email': email,
                    'role': role,
                    if (motDePasse.isNotEmpty) 'mot_de_passe': motDePasse,
                  };

                  if (user == null) {
                    await DatabaseHelper.instance.insertUser(row);
                  } else {
                    await DatabaseHelper.instance.updateUser(row);
                  }

                  navigator.pop();
                  _loadUsers();
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
    // Security check: Only Admin can delete users
    final currentRole = widget.currentUser['role'] ?? 'OPERATEUR';
    if (currentRole != 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accès refusé ! Seul l\'Administrateur peut gérer les utilisateurs.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (id == widget.currentUser['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas vous supprimer vous-même !'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Désactiver l\'utilisateur'),
          content: Text('Voulez-vous révoquer l\'accès pour "$name" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await DatabaseHelper.instance.deleteUser(id);
                navigator.pop();
                _loadUsers();
              },
              child: const Text('Désactiver'),
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
                      'Gestion des Utilisateurs',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    Text(
                      'Configurez les droits d\'accès pour les administrateurs, gérants et caissiers.',
                      style: TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nouvel Utilisateur'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('Aucun utilisateur répertorié.'))
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            final role = u['role'] ?? 'OPERATEUR';
                            final isActif = u['actif'] == 1;

                            Color roleColor = AppColors.primary;
                            if (role == 'ADMIN') {
                              roleColor = AppColors.danger;
                            } else if (role == 'GERANT') {
                              roleColor = AppColors.warning;
                            }

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade100, width: 1),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: roleColor.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: roleColor),
                                ),
                                title: Row(
                                  children: [
                                    Text(u['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isActif)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'DÉSACTIVÉ',
                                          style: TextStyle(color: AppColors.danger, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text('Identifiant: ${u['identifiant']} | Email: ${u['email'] ?? 'N/A'}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: AppColors.primary),
                                      onPressed: () => _showUserDialog(user: u),
                                    ),
                                    if (isActif)
                                      IconButton(
                                        icon: const Icon(Icons.block, color: AppColors.danger),
                                        onPressed: () => _confirmDelete(u['id'], u['nom']),
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
