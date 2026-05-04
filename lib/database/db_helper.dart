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
      version: 4, // v4: campos completos em clientes + status_sincronizacao
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE venda_itens ADD COLUMN observacao TEXT DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE produtos ADD COLUMN is_produto_banda INTEGER DEFAULT 0",
          );
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE clientes ADD COLUMN cpf_cnpj TEXT DEFAULT ''");
          await db.execute("ALTER TABLE clientes ADD COLUMN telefone TEXT DEFAULT ''");
          await db.execute("ALTER TABLE clientes ADD COLUMN email TEXT DEFAULT ''");
          await db.execute("ALTER TABLE clientes ADD COLUMN endereco TEXT DEFAULT ''");
          // 'sincronizado' para clientes que vieram do servidor, 'pendente' para os criados offline
          await db.execute("ALTER TABLE clientes ADD COLUMN status_sincronizacao TEXT DEFAULT 'sincronizado'");
        }
      },
    );
  }

  // Criação das tabelas locais (Espelho simplificado do seu PostgreSQL)
  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabela de Clientes (schema completo)
    await db.execute('''
      CREATE TABLE clientes(
        id INTEGER PRIMARY KEY,
        nome TEXT,
        cpf_cnpj TEXT DEFAULT '',
        telefone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        endereco TEXT DEFAULT '',
        status_sincronizacao TEXT DEFAULT 'sincronizado'
      )
    ''');

    // 2. Tabela de Produtos
    await db.execute('''
      CREATE TABLE produtos(
        id INTEGER PRIMARY KEY,
        nome TEXT,
        preco REAL,
        tipo_unidade TEXT,
        is_produto_banda INTEGER DEFAULT 0
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