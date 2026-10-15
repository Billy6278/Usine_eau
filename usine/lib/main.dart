import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/sqlite_db_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_layout.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/production/presentation/pages/production_page.dart';
import 'features/stock/presentation/pages/stock_page.dart';
import 'features/sales/presentation/pages/sales_page.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/deliveries/presentation/pages/deliveries_page.dart';
import 'features/clients/presentation/pages/clients_page.dart';
import 'features/finances/presentation/pages/finances_page.dart';
import 'features/reports/presentation/pages/reports_page.dart';
import 'features/users/presentation/pages/users_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/about/presentation/pages/about_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    // Initialize FFI for sqflite on desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize SQLite Database and populate demo data
  await DatabaseHelper.instance.database;

  // Initialize French locale date formatting
  await initializeDateFormatting('fr_FR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usine d\'Eau',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Pre-login default Admin user for testing convenience
  Map<String, dynamic>? _currentUser = {
    'id': 1,
    'nom': 'Super Admin',
    'identifiant': 'admin',
    'role': 'ADMIN',
  };

  void _login(Map<String, dynamic> user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _logout() {
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return AuthPage(onLoginSuccess: _login);
    }

    return ResponsiveLayout(
      currentUser: _currentUser!,
      onLogout: _logout,
      pageBuilder: (index) {
        switch (index) {
          case 0:
            return const DashboardPage();
          case 1:
            return ProductionPage(currentUser: _currentUser!);
          case 2:
            return const StockPage();
          case 3:
            return SalesPage(currentUser: _currentUser!);
          case 4:
            return const OrdersPage();
          case 5:
            return const DeliveriesPage();
          case 6:
            return const ClientsPage();
          case 7:
            return const FinancesPage();
          case 8:
            return const ReportsPage();
          case 9:
            return UsersPage(currentUser: _currentUser!);
          case 10:
            return const SettingsPage();
          case 11:
            return const AboutPage();
          default:
            return const Center(child: Text('Page non trouvée'));
        }
      },
    );
  }
}
