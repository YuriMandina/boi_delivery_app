import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  // Padrão Singleton para garantir apenas uma conexão com o banco
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'boi_delivery_offline.db');
    return await openDatabase(
      path,
      version: 2, // Subimos a versão!
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Cria a coluna que faltava no celular sem apagar os dados
          await db.execute(
            "ALTER TABLE venda_itens ADD COLUMN observacao TEXT DEFAULT ''",
          );
        }
      },
    );
  }

  // Criação das tabelas locais (Espelho simplificado do seu PostgreSQL)
  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabela de Clientes
    await db.execute('''
      CREATE TABLE clientes(
        id INTEGER PRIMARY KEY,
        nome TEXT
      )
    ''');

    // 2. Tabela de Produtos
    await db.execute('''
      CREATE TABLE produtos(
        id INTEGER PRIMARY KEY,
        nome TEXT,
        preco REAL,
        tipo_unidade TEXT
      )
    ''');

    // 3. Tabela de Vendas (Capa)
    await db.execute('''
      CREATE TABLE vendas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        numero_nota TEXT,
        data_venda TEXT,
        valor_total REAL,
        eh_saida_avancada INTEGER,
        status_sincronizacao TEXT DEFAULT 'pendente' 
      )
    ''');

    // 4. Tabela de Itens da Venda
    await db.execute('''
      CREATE TABLE venda_itens(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER,
        produto_id INTEGER,
        quantidade_kg REAL,
        quantidade_pecas TEXT,
        preco_unitario REAL,
        subtotal REAL,
        FOREIGN KEY (venda_id) REFERENCES vendas (id) ON DELETE CASCADE
      )
    ''');
  }
}
