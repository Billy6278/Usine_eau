import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('usine_eau_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = p.join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future _createDB(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE utilisateurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        identifiant TEXT UNIQUE NOT NULL,
        mot_de_passe_hash TEXT NOT NULL,
        role TEXT CHECK(role IN ('ADMIN', 'GERANT', 'OPERATEUR')) NOT NULL,
        telephone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        actif INTEGER DEFAULT 1,
        date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE
      )
    ''');

    // 3. Products & Raw Materials Table
    await db.execute('''
      CREATE TABLE produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categorie_id INTEGER,
        nom TEXT NOT NULL,
        code_barres TEXT UNIQUE,
        est_matiere_premiere INTEGER DEFAULT 0,
        volume_litres REAL DEFAULT 0.0,
        prix_unitaire REAL DEFAULT 0.0,
        cout_estime_production REAL DEFAULT 0.0,
        stock_actuel REAL DEFAULT 0.0,
        stock_seuil REAL DEFAULT 10.0,
        FOREIGN KEY (categorie_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // 4. Production Lots Table
    await db.execute('''
      CREATE TABLE productions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produit_fini_id INTEGER NOT NULL,
        quantite_produite INTEGER NOT NULL,
        quantite_perdue INTEGER DEFAULT 0,
        date_production TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        operateur_id INTEGER,
        remarques TEXT,
        FOREIGN KEY (produit_fini_id) REFERENCES produits(id),
        FOREIGN KEY (operateur_id) REFERENCES utilisateurs(id)
      )
    ''');

    // 5. Recipe (BOM) Table
    await db.execute('''
      CREATE TABLE recette_production (
        produit_fini_id INTEGER NOT NULL,
        matiere_premiere_id INTEGER NOT NULL,
        quantite_requise REAL NOT NULL,
        PRIMARY KEY (produit_fini_id, matiere_premiere_id),
        FOREIGN KEY (produit_fini_id) REFERENCES produits(id) ON DELETE CASCADE,
        FOREIGN KEY (matiere_premiere_id) REFERENCES produits(id) ON DELETE CASCADE
      )
    ''');

    // 6. Clients Table
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT,
        email TEXT,
        adresse TEXT,
        date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 7. Sales (Headers) Table
    await db.execute('''
      CREATE TABLE ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        operateur_id INTEGER NOT NULL,
        date_vente TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        total_brut REAL NOT NULL,
        remise REAL DEFAULT 0.0,
        total_net REAL NOT NULL,
        montant_paye REAL DEFAULT 0.0,
        statut_paiement TEXT CHECK(statut_paiement IN ('PAYE', 'CREDIT', 'PARTIEL')) NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id),
        FOREIGN KEY (operateur_id) REFERENCES utilisateurs(id)
      )
    ''');

    // 8. Sales Lines Table
    await db.execute('''
      CREATE TABLE ligne_ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL,
        produit_id INTEGER NOT NULL,
        quantite INTEGER NOT NULL,
        prix_unitaire_applique REAL NOT NULL,
        total_ligne REAL NOT NULL,
        FOREIGN KEY (vente_id) REFERENCES ventes(id) ON DELETE CASCADE,
        FOREIGN KEY (produit_id) REFERENCES produits(id)
      )
    ''');

    // 9. Credit Payments Table
    await db.execute('''
      CREATE TABLE paiements_credit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL,
        montant REAL NOT NULL,
        date_paiement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        mode_paiement TEXT CHECK(mode_paiement IN ('ESPECES', 'MOBILE_MONEY', 'CHEQUE')) NOT NULL,
        FOREIGN KEY (vente_id) REFERENCES ventes(id) ON DELETE CASCADE
      )
    ''');

    // 10. Expenses Table
    await db.execute('''
      CREATE TABLE depenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categorie TEXT NOT NULL,
        montant REAL NOT NULL,
        date_depense TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT,
        operateur_id INTEGER,
        FOREIGN KEY (operateur_id) REFERENCES utilisateurs(id)
      )
    ''');

    // 11. Revenues Table (for non-sale incomes or synced sales incomes)
    await db.execute('''
      CREATE TABLE revenus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categorie TEXT NOT NULL,
        montant REAL NOT NULL,
        date_revenu TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT,
        vente_id INTEGER,
        FOREIGN KEY (vente_id) REFERENCES ventes(id) ON DELETE SET NULL
      )
    ''');

    // 12. Stock Movements Table
    await db.execute('''
      CREATE TABLE mouvements_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produit_id INTEGER NOT NULL,
        type_mouvement TEXT CHECK(type_mouvement IN ('ENTREE', 'SORTIE', 'PRODUCTION', 'VENTE', 'AJUSTEMENT_PERTE')) NOT NULL,
        quantite REAL NOT NULL,
        date_mouvement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT,
        FOREIGN KEY (produit_id) REFERENCES produits(id) ON DELETE CASCADE
      )
    ''');

    // 13. Orders (Commandes) Table
    await db.execute('''
      CREATE TABLE commandes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_commande TEXT UNIQUE NOT NULL,
        client_id INTEGER NOT NULL,
        produit_id INTEGER NOT NULL,
        quantite_demandee REAL NOT NULL,
        date_commande TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        statut TEXT CHECK(statut IN ('EN_ATTENTE', 'EN_COURS', 'LIVREE', 'ANNULEE')) NOT NULL DEFAULT 'EN_ATTENTE',
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
        FOREIGN KEY (produit_id) REFERENCES produits(id) ON DELETE CASCADE
      )
    ''');

    // 14. Deliveries (Livraisons) Table
    await db.execute('''
      CREATE TABLE livraisons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_livraison TEXT UNIQUE NOT NULL,
        commande_id INTEGER NOT NULL,
        chauffeur TEXT NOT NULL,
        vehicule TEXT NOT NULL,
        date_livraison TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        statut TEXT CHECK(statut IN ('PLANIFIEE', 'EN_COURS', 'LIVREE')) NOT NULL DEFAULT 'PLANIFIEE',
        FOREIGN KEY (commande_id) REFERENCES commandes(id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_produits_code ON produits(code_barres)');
    await db.execute('CREATE INDEX idx_ventes_date ON ventes(date_vente)');
    await db.execute('CREATE INDEX idx_mouvements_stock_produit ON mouvements_stock(produit_id)');
    await db.execute('CREATE INDEX idx_ligne_ventes_vente ON ligne_ventes(vente_id)');
    await db.execute('CREATE INDEX idx_commandes_client ON commandes(client_id)');
    await db.execute('CREATE INDEX idx_livraisons_cmd ON livraisons(commande_id)');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // 1. Users
    final adminPin = _hashPin('1234');

    await db.insert('utilisateurs', {
      'nom': 'Super Admin',
      'identifiant': 'admin',
      'mot_de_passe_hash': adminPin,
      'role': 'ADMIN',
      'telephone': '+224 611 11 11 11',
      'email': 'admin@usine.local',
      'actif': 1
    });

    // 2. Categories
    await db.insert('categories', {'nom': 'Produits Finis'});
    await db.insert('categories', {'nom': 'Matières Premières'});
  }

  // ==========================================
  // CRUD API METHODS
  // ==========================================

  // Authentication
  Future<Map<String, dynamic>?> checkLogin(String username, String pin) async {
    final db = await instance.database;
    final pinHash = _hashPin(pin);
    final results = await db.query(
      'utilisateurs',
      where: 'identifiant = ? AND mot_de_passe_hash = ? AND actif = 1',
      whereArgs: [username, pinHash],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await instance.database;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Liters produced today
    final prodQuery = await db.rawQuery('''
      SELECT SUM(p.quantite_produite * pr.volume_litres) as total_litres
      FROM productions p
      JOIN produits pr ON p.produit_fini_id = pr.id
      WHERE strftime('%Y-%m-%d', p.date_production) = ?
    ''', [todayStr]);
    final totalLitres = prodQuery.first['total_litres'] ?? 0.0;

    // 2. Revenues today
    final revQuery = await db.rawQuery('''
      SELECT SUM(montant) as total_rev
      FROM revenus
      WHERE strftime('%Y-%m-%d', date_revenu) = ?
    ''', [todayStr]);
    final totalRevenues = revQuery.first['total_rev'] ?? 0.0;

    // 3. Expenses today
    final expQuery = await db.rawQuery('''
      SELECT SUM(montant) as total_dep
      FROM depenses
      WHERE strftime('%Y-%m-%d', date_depense) = ?
    ''', [todayStr]);
    final totalExpenses = expQuery.first['total_dep'] ?? 0.0;

    // 4. Clients count
    final clientQuery = await db.rawQuery('SELECT COUNT(*) as c_count FROM clients');
    final clientsCount = clientQuery.first['c_count'] ?? 0;

    // 5. Orders count
    final orderQuery = await db.rawQuery('SELECT COUNT(*) as o_count FROM commandes');
    final ordersCount = orderQuery.first['o_count'] ?? 0;

    // 6. Low stock alert count
    final alertQuery = await db.rawQuery('''
      SELECT COUNT(*) as alert_count
      FROM produits
      WHERE stock_actuel <= stock_seuil
    ''');
    final alertCount = alertQuery.first['alert_count'] ?? 0;

    // 7. Income for the last 7 days (weekly chart data)
    final weeklyQuery = await db.rawQuery('''
      SELECT strftime('%w', date_revenu) as day_of_week, SUM(montant) as daily_total
      FROM revenus
      WHERE date_revenu >= date('now', '-6 days')
      GROUP BY day_of_week
      ORDER BY date_revenu ASC
    ''');

    // 8. Recent activities
    final recentQuery = await db.rawQuery('''
      SELECT 'stock' as type, type_mouvement as subtype, quantite, date_mouvement as date, description FROM mouvements_stock
      UNION ALL
      SELECT 'depense' as type, categorie as subtype, montant as quantite, date_depense as date, description FROM depenses
      ORDER BY date DESC LIMIT 5
    ''');

    return {
      'production_litres_today': totalLitres,
      'ca_today': totalRevenues,
      'expenses_today': totalExpenses,
      'net_profit_today': (totalRevenues as double) - (totalExpenses as double),
      'clients_count': clientsCount,
      'orders_count': ordersCount,
      'alert_count': alertCount,
      'weekly_sales': weeklyQuery,
      'recent_activities': recentQuery
    };
  }

  // Products & Stock
  Future<List<Map<String, dynamic>>> getProducts({bool rawOnly = false, bool finishedOnly = false}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> args = [];

    if (rawOnly) {
      whereClause = 'est_matiere_premiere = 1';
    } else if (finishedOnly) {
      whereClause = 'est_matiere_premiere = 0';
    }

    return await db.query(
      'produits',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'nom ASC',
    );
  }

  Future<int> insertProduct(Map<String, dynamic> prod) async {
    final db = await instance.database;
    return await db.insert('produits', prod);
  }

  Future<int> updateProduct(Map<String, dynamic> prod) async {
    final db = await instance.database;
    return await db.update('produits', prod, where: 'id = ?', whereArgs: [prod['id']]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('produits', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(int produitId, double adjustQty, String description) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.rawUpdate('''
        UPDATE produits 
        SET stock_actuel = stock_actuel + ? 
        WHERE id = ?
      ''', [adjustQty, produitId]);

      await txn.insert('mouvements_stock', {
        'produit_id': produitId,
        'type_mouvement': adjustQty >= 0 ? 'ENTREE' : 'SORTIE',
        'quantite': adjustQty,
        'description': description
      });
    });
  }

  // Production CRUD
  Future<List<Map<String, dynamic>>> getProductions() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, pr.nom as produit_nom, u.nom as operateur_nom
      FROM productions p
      JOIN produits pr ON p.produit_fini_id = pr.id
      LEFT JOIN utilisateurs u ON p.operateur_id = u.id
      ORDER BY p.date_production DESC
    ''');
  }

  Future<bool> recordProduction({
    required int produitFiniId,
    required int qty,
    required int qtyLost,
    required int operateurId,
    String remarks = '',
  }) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      await txn.insert('productions', {
        'produit_fini_id': produitFiniId,
        'quantite_produite': qty,
        'quantite_perdue': qtyLost,
        'operateur_id': operateurId,
        'remarques': remarks
      });

      await txn.rawUpdate('''
        UPDATE produits 
        SET stock_actuel = stock_actuel + ? 
        WHERE id = ?
      ''', [qty, produitFiniId]);

      await txn.insert('mouvements_stock', {
        'produit_id': produitFiniId,
        'type_mouvement': 'PRODUCTION',
        'quantite': qty.toDouble(),
        'description': 'Production de bouteilles d\'eau'
      });

      final recipe = await txn.query(
        'recette_production',
        where: 'produit_fini_id = ?',
        whereArgs: [produitFiniId],
      );

      for (var row in recipe) {
        final rawId = row['matiere_premiere_id'] as int;
        final reqQtyPerUnit = row['quantite_requise'] as double;
        final totalDeduction = reqQtyPerUnit * qty;

        await txn.rawUpdate('''
          UPDATE produits 
          SET stock_actuel = stock_actuel - ? 
          WHERE id = ?
        ''', [totalDeduction, rawId]);

        await txn.insert('mouvements_stock', {
          'produit_id': rawId,
          'type_mouvement': 'PRODUCTION',
          'quantite': -totalDeduction,
          'description': 'Intrant utilisé pour production'
        });
      }
      return true;
    });
  }

  Future<int> deleteProduction(int id) async {
    final db = await instance.database;
    return await db.delete('productions', where: 'id = ?', whereArgs: [id]);
  }

  // Clients CRUD
  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await instance.database;
    return await db.query('clients', orderBy: 'nom ASC');
  }

  Future<int> insertClient(Map<String, dynamic> client) async {
    final db = await instance.database;
    return await db.insert('clients', client);
  }

  Future<int> updateClient(Map<String, dynamic> client) async {
    final db = await instance.database;
    return await db.update('clients', client, where: 'id = ?', whereArgs: [client['id']]);
  }

  Future<int> deleteClient(int id) async {
    final db = await instance.database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  // Ventes CRUD
  Future<List<Map<String, dynamic>>> getVentes() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT v.*, c.nom as client_nom, u.nom as operateur_nom
      FROM ventes v
      JOIN clients c ON v.client_id = c.id
      JOIN utilisateurs u ON v.operateur_id = u.id
      ORDER BY v.date_vente DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getVenteLignes(int venteId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT lv.*, p.nom as produit_nom
      FROM ligne_ventes lv
      JOIN produits p ON lv.produit_id = p.id
      WHERE lv.vente_id = ?
    ''', [venteId]);
  }

  Future<bool> recordVente({
    required int clientId,
    required int operateurId,
    required double totalBrut,
    required double remise,
    required double montantPaye,
    required String statutPaiement,
    required List<Map<String, dynamic>> details,
  }) async {
    final db = await instance.database;
    final totalNet = totalBrut - remise;
    final dateStr = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      // 1. Insert header
      final venteId = await txn.insert('ventes', {
        'client_id': clientId,
        'operateur_id': operateurId,
        'date_vente': dateStr,
        'total_brut': totalBrut,
        'remise': remise,
        'total_net': totalNet,
        'montant_paye': montantPaye,
        'statut_paiement': statutPaiement
      });

      // 2. Insert lines and update inventory
      for (var det in details) {
        final pId = det['produit_id'] as int;
        final qty = det['quantite'] as int;
        final pUnit = det['prix_unitaire'] as double;

        await txn.insert('ligne_ventes', {
          'vente_id': venteId,
          'produit_id': pId,
          'quantite': qty,
          'prix_unitaire_applique': pUnit,
          'total_ligne': qty * pUnit
        });

        // Deduct from stock
        await txn.rawUpdate('''
          UPDATE produits 
          SET stock_actuel = stock_actuel - ? 
          WHERE id = ?
        ''', [qty.toDouble(), pId]);

        // Stock movement log
        await txn.insert('mouvements_stock', {
          'produit_id': pId,
          'type_mouvement': 'VENTE',
          'quantite': -qty.toDouble(),
          'date_mouvement': dateStr,
          'description': 'Vendu facture N° $venteId'
        });
      }

      // 3. Log sales transaction to Revenues
      await txn.insert('revenus', {
        'categorie': 'Vente d\'eau',
        'montant': totalNet,
        'date_revenu': dateStr,
        'description': 'Facture Vente N° $venteId',
        'vente_id': venteId
      });

      return true;
    });
  }

  Future<int> deleteVente(int id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // Delete corresponding revenue
      await txn.delete('revenus', where: 'vente_id = ?', whereArgs: [id]);
      // Return stock back
      final details = await txn.query('ligne_ventes', where: 'vente_id = ?', whereArgs: [id]);
      for (var det in details) {
        final pId = det['produit_id'] as int;
        final qty = det['quantite'] as int;
        await txn.rawUpdate('UPDATE produits SET stock_actuel = stock_actuel + ? WHERE id = ?', [qty, pId]);
      }
      return await txn.delete('ventes', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Commandes CRUD
  Future<List<Map<String, dynamic>>> getCommandes() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT cmd.*, c.nom as client_nom, p.nom as produit_nom
      FROM commandes cmd
      JOIN clients c ON cmd.client_id = c.id
      JOIN produits p ON cmd.produit_id = p.id
      ORDER BY cmd.date_commande DESC
    ''');
  }

  Future<int> insertCommande(Map<String, dynamic> cmd) async {
    final db = await instance.database;
    return await db.insert('commandes', cmd);
  }

  Future<int> updateCommande(Map<String, dynamic> cmd) async {
    final db = await instance.database;
    return await db.update('commandes', cmd, where: 'id = ?', whereArgs: [cmd['id']]);
  }

  Future<int> updateCommandeStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update('commandes', {'statut': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCommande(int id) async {
    final db = await instance.database;
    return await db.delete('commandes', where: 'id = ?', whereArgs: [id]);
  }

  // Livraisons CRUD
  Future<List<Map<String, dynamic>>> getLivraisons() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT l.*, cmd.numero_commande, c.nom as client_nom
      FROM livraisons l
      JOIN commandes cmd ON l.commande_id = cmd.id
      JOIN clients c ON cmd.client_id = c.id
      ORDER BY l.date_livraison DESC
    ''');
  }

  Future<int> insertLivraison(Map<String, dynamic> liv) async {
    final db = await instance.database;
    return await db.insert('livraisons', liv);
  }

  Future<int> updateLivraisonStatus(int id, String status) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      await txn.update('livraisons', {'statut': status}, where: 'id = ?', whereArgs: [id]);
      if (status == 'LIVREE') {
        // Automatically mark the order as delivered too
        final livResult = await txn.query('livraisons', columns: ['commande_id'], where: 'id = ?', whereArgs: [id]);
        if (livResult.isNotEmpty) {
          final cmdId = livResult.first['commande_id'] as int;
          await txn.update('commandes', {'statut': 'LIVREE'}, where: 'id = ?', whereArgs: [cmdId]);
        }
      }
      return 1;
    });
  }

  Future<int> deleteLivraison(int id) async {
    final db = await instance.database;
    return await db.delete('livraisons', where: 'id = ?', whereArgs: [id]);
  }

  // Revenues CRUD
  Future<List<Map<String, dynamic>>> getRevenus() async {
    final db = await instance.database;
    return await db.query('revenus', orderBy: 'date_revenu DESC');
  }

  Future<int> insertRevenu(Map<String, dynamic> r) async {
    final db = await instance.database;
    return await db.insert('revenus', r);
  }

  Future<int> deleteRevenu(int id) async {
    final db = await instance.database;
    return await db.delete('revenus', where: 'id = ?', whereArgs: [id]);
  }

  // Expenses CRUD
  Future<List<Map<String, dynamic>>> getDepenses() async {
    final db = await instance.database;
    return await db.query('depenses', orderBy: 'date_depense DESC');
  }

  Future<int> insertDepense(Map<String, dynamic> d) async {
    final db = await instance.database;
    return await db.insert('depenses', d);
  }

  Future<int> deleteDepense(int id) async {
    final db = await instance.database;
    return await db.delete('depenses', where: 'id = ?', whereArgs: [id]);
  }

  // Users CRUD
  Future<List<Map<String, dynamic>>> getActiveUsers() async {
    final db = await instance.database;
    return await db.query('utilisateurs', where: 'actif = 1', orderBy: 'nom ASC');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await instance.database;
    return await db.query('utilisateurs', orderBy: 'nom ASC');
  }

  Future<int> insertUser(Map<String, dynamic> u) async {
    final db = await instance.database;
    final Map<String, dynamic> tempUser = Map.from(u);
    if (tempUser.containsKey('mot_de_passe')) {
      tempUser['mot_de_passe_hash'] = _hashPin(tempUser['mot_de_passe']);
      tempUser.remove('mot_de_passe');
    }
    return await db.insert('utilisateurs', tempUser);
  }

  Future<int> updateUser(Map<String, dynamic> u) async {
    final db = await instance.database;
    final Map<String, dynamic> tempUser = Map.from(u);
    if (tempUser.containsKey('mot_de_passe') && tempUser['mot_de_passe'].toString().isNotEmpty) {
      tempUser['mot_de_passe_hash'] = _hashPin(tempUser['mot_de_passe']);
    }
    tempUser.remove('mot_de_passe');
    return await db.update('utilisateurs', tempUser, where: 'id = ?', whereArgs: [tempUser['id']]);
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    // Hard or soft delete? We can soft-delete or hard-delete. Let's do soft delete to preserve historical integrity.
    return await db.update('utilisateurs', {'actif': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
