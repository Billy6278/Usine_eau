import 'package:flutter/material.dart';
import '../../../../core/database/sqlite_db_helper.dart';
import '../../../../core/theme/app_colors.dart';

class AuthPage extends StatefulWidget {
  final Function(Map<String, dynamic> user) onLoginSuccess;

  const AuthPage({super.key, required this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  String _pin = '';
  String _errorMessage = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final dbUsers = await DatabaseHelper.instance.getActiveUsers();
      setState(() {
        _users = dbUsers;
        if (dbUsers.isNotEmpty) {
          _selectedUser = dbUsers.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des profils.';
        _isLoading = false;
      });
    }
  }

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = '';
    });

    if (val == 'C') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
      }
    } else if (_pin.length < 4) {
      setState(() {
        _pin += val;
      });
    }
  }

  Future<void> _submitLogin() async {
    if (_selectedUser == null || _pin.length < 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _selectedUser!['identifiant'] as String;
    final loggedUser = await DatabaseHelper.instance.checkLogin(username, _pin);

    setState(() {
      _isLoading = false;
    });

    if (loggedUser != null) {
      widget.onLoginSuccess(loggedUser);
    } else {
      setState(() {
        _pin = '';
        _errorMessage = 'Code PIN incorrect.';
      });
    }
  }

  Widget _buildPinDot(int index) {
    final filled = _pin.length > index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary : Colors.grey.shade300,
        border: Border.all(
          color: filled ? AppColors.primary : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String value) {
    final isAction = value == 'C' || value == 'OK';
    return Material(
      color: isAction
          ? (value == 'OK' ? AppColors.primary : AppColors.slate100)
          : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (value == 'OK') {
            _submitLogin();
          } else {
            _onKeyPress(value);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAction ? Colors.transparent : Colors.grey.shade200,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isAction ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: value == 'OK'
                  ? AppColors.white
                  : (value == 'C' ? AppColors.danger : AppColors.slate700),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _users.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryLight.withOpacity(0.5),
              AppColors.slate50,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop, color: AppColors.primary, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Usine d\'Eau',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text(
                      'Connexion sécurisée - Mode local',
                      style: TextStyle(color: AppColors.slate400, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // User Selector
                    DropdownButtonFormField<int>(
                      value: _selectedUser?['id'] as int?,
                      decoration: const InputDecoration(
                        labelText: 'Sélectionnez votre profil',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _users.map((user) {
                        return DropdownMenuItem<int>(
                          value: user['id'] as int,
                          child: Text('${user['nom']} (${user['role']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedUser = _users.firstWhere((user) => user['id'] == val);
                          _pin = '';
                          _errorMessage = '';
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Pin Code Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => _buildPinDot(index)),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage.isNotEmpty)
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),

                    const SizedBox(height: 24),

                    // Numeric Grid
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        '1', '2', '3',
                        '4', '5', '6',
                        '7', '8', '9',
                        'C', '0', 'OK'
                      ].map((val) => _buildKeypadButton(val)).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
