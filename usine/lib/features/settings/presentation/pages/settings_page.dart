import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  String _companyName = 'Eau Pure SARL';
  String _address = 'Zone Industrielle, Conakry';
  String _phone = '+224 620 00 00 00';
  String _currency = 'GNF';
  bool _darkMode = false;

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètres locaux enregistrés avec succès.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paramètres Système',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  Text(
                    'Configurez les données de facturation locales et les préférences.',
                    style: TextStyle(color: AppColors.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INFORMATIONS DE L\'ENTREPRISE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _companyName,
                          decoration: const InputDecoration(labelText: 'Nom de l\'Entreprise', prefixIcon: Icon(Icons.business)),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => _companyName = val!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _address,
                          decoration: const InputDecoration(labelText: 'Adresse de Facturation', prefixIcon: Icon(Icons.location_on)),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => _address = val!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _phone,
                          decoration: const InputDecoration(labelText: 'Téléphone de Contact', prefixIcon: Icon(Icons.phone)),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          onSaved: (val) => _phone = val!,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'PRÉFÉRENCES RÉGIONALES',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: const InputDecoration(labelText: 'Devise monétaire'),
                          items: const [
                            DropdownMenuItem(value: 'GNF', child: Text('Franc Guinéen (GNF)')),
                            DropdownMenuItem(value: 'FCFA', child: Text('Franc CFA (FCFA)')),
                            DropdownMenuItem(value: 'USD', child: Text('Dollar US (\$)')),
                            DropdownMenuItem(value: 'EUR', child: Text('Euro (€)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _currency = val);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mode sombre local'),
                          subtitle: const Text('Activer le thème visuel sombre sur cet appareil.'),
                          value: _darkMode,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() => _darkMode = val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thème mis à jour (mock).'),
                                duration: Duration(milliseconds: 700),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(Icons.save),
                            label: const Text('Enregistrer les paramètres'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
