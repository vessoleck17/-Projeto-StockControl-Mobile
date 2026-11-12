class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.role,
    this.id,
    this.establishmentId,
    this.establishment = '',
  });

  final int? id;
  final String name;
  final String email;
  final String role;
  final int? establishmentId;
  final String establishment;

  bool get canManageCatalog {
    final normalized = normalizeRole(role);
    return normalized == 'Admin' || normalized == 'Gerente';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _toInt(json['id']),
      name: (json['nome'] ?? json['name'] ?? 'Usuário').toString(),
      email: (json['email'] ?? '').toString(),
      role: normalizeRole(json['perfil'] ?? json['role']),
      establishmentId: _toInt(json['estabelecimentoId'] ?? json['companyId']),
      establishment: (json['estabelecimento'] ?? json['company'] ?? '')
          .toString(),
    );
  }

  static String normalizeRole(dynamic value) {
    final raw = (value ?? 'Operador').toString().toLowerCase();

    switch (raw) {
      case '1':
      case 'admin':
        return 'Admin';
      case '2':
      case 'manager':
      case 'gerente':
        return 'Gerente';
      case '3':
      case 'employee':
      case 'operator':
      case 'operador':
        return 'Operador';
      default:
        return value?.toString() ?? 'Operador';
    }
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.category,
    required this.supplierId,
    required this.supplier,
    required this.price,
    required this.quantity,
    this.isLowStock = false,
    this.barcode = '',
    this.minimumStock = 0,
    this.isActive = true,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int categoryId;
  final String category;
  final int supplierId;
  final String supplier;
  final double price;
  final int quantity;
  final bool isLowStock;

  final String barcode;
  final int minimumStock;
  final bool isActive;
  final DateTime? updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) {
    final quantity = _toInt(json['estoqueAtual'] ?? json['quantity']);
    final minimumStock = _toInt(json['estoqueMinimo'] ?? json['minimumStock']);

    final lowStock =
        json['abaixoDoMinimo'] ?? json['isLowStock'] ?? json['lowStock'];

    return Product(
      id: _toInt(json['id']),
      name: (json['nome'] ?? json['name'] ?? 'Produto sem nome').toString(),
      categoryId: _toInt(json['categoriaId'] ?? json['categoryId']),
      category: (json['categoria'] ?? json['category'] ?? '').toString(),
      supplierId: _toInt(json['fornecedorId'] ?? json['supplierId']),
      supplier: (json['fornecedor'] ?? json['supplier'] ?? '').toString(),
      price: _toDouble(json['preco'] ?? json['price']),
      quantity: quantity,
      isLowStock: lowStock is bool
          ? lowStock
          : quantity < (minimumStock > 0 ? minimumStock : 5),
      barcode: (json['codigoBarras'] ?? json['barcode'] ?? '').toString(),
      minimumStock: minimumStock,
      isActive: _toBool(json['ativo'] ?? json['isActive'], true),
      updatedAt: _toDateTime(json['atualizadoEm'] ?? json['updatedAt']),
    );
  }
}

class Movement {
  const Movement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.dateUtc,
    required this.userName,
    this.paymentMethod,
  });

  final int id;
  final int productId;
  final String productName;
  final String type;
  final int quantity;
  final DateTime dateUtc;
  final String userName;

  // Campo mantido para compatibilidade com a tela existente.
  // Na API nova, este conteúdo corresponde à observação.
  final String? paymentMethod;

  bool get isEntry {
    final normalized = type.toUpperCase();
    return normalized == 'ENTRADA' || normalized == 'ENTRY';
  }

  factory Movement.fromJson(Map<String, dynamic> json) {
    final rawType = (json['tipo'] ?? json['type'] ?? '').toString();

    return Movement(
      id: _toInt(json['id']),
      productId: _toInt(json['produtoId'] ?? json['productId']),
      productName: (json['produto'] ?? json['product'] ?? 'Produto').toString(),
      type:
          rawType.toUpperCase() == 'ENTRADA' || rawType.toLowerCase() == 'entry'
          ? 'ENTRADA'
          : 'SAIDA',
      quantity: _toInt(json['quantidade'] ?? json['quantity']),
      dateUtc: _toDateTime(json['data'] ?? json['dateUtc']) ?? DateTime.now(),
      userName: (json['usuario'] ?? json['user'] ?? '').toString(),
      paymentMethod: (json['observacao'] ?? json['paymentMethod'])?.toString(),
    );
  }
}

class CatalogOption {
  const CatalogOption({required this.id, required this.name});

  final int id;
  final String name;

  factory CatalogOption.fromJson(Map<String, dynamic> json) {
    return CatalogOption(
      id: _toInt(json['id']),
      name: (json['nome'] ?? json['razaoSocial'] ?? json['name'] ?? '')
          .toString(),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    this.totalProducts = 0,
    this.totalCategories = 0,
    this.totalSuppliers = 0,
    this.stockValue = 0,
    this.entriesToday = 0,
    this.exitsToday = 0,
    this.salesToday = 0,
    this.itemsSoldToday = 0,
    this.lowStockProducts = const [],
    this.latestMovements = const [],
    this.salesLastSevenDays = const [],
    this.bestSellingProducts = const [],
  });

  final int totalProducts;
  final int totalCategories;
  final int totalSuppliers;
  final double stockValue;
  final int entriesToday;
  final int exitsToday;
  final double salesToday;
  final int itemsSoldToday;
  final List<LowStockProduct> lowStockProducts;
  final List<Movement> latestMovements;
  final List<SalesDay> salesLastSevenDays;
  final List<TopSellingProduct> bestSellingProducts;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalProducts: _toInt(json['totalProdutosAtivos']),
      totalCategories: _toInt(json['totalCategorias']),
      totalSuppliers: _toInt(json['totalFornecedores']),
      stockValue: _toDouble(json['valorEmEstoque']),
      entriesToday: _toInt(json['entradasHoje']),
      exitsToday: _toInt(json['saidasHoje']),
      salesToday: _toDouble(json['valorVendidoHoje']),
      itemsSoldToday: _toInt(json['itensVendidosHoje']),
      lowStockProducts: _toObjectList(
        json['produtosAbaixoDoMinimo'],
      ).map(LowStockProduct.fromJson).toList(),
      latestMovements: _toObjectList(
        json['ultimasMovimentacoes'],
      ).map(Movement.fromJson).toList(),
      salesLastSevenDays: _toObjectList(
        json['vendasUltimos7Dias'],
      ).map(SalesDay.fromJson).toList(),
      bestSellingProducts: _toObjectList(
        json['maisVendidos'],
      ).map(TopSellingProduct.fromJson).toList(),
    );
  }
}

class LowStockProduct {
  const LowStockProduct({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.currentStock,
    required this.minimumStock,
    required this.missingQuantity,
  });

  final int id;
  final String name;
  final String barcode;
  final String category;
  final int currentStock;
  final int minimumStock;
  final int missingQuantity;

  factory LowStockProduct.fromJson(Map<String, dynamic> json) {
    return LowStockProduct(
      id: _toInt(json['id']),
      name: (json['nome'] ?? '').toString(),
      barcode: (json['codigoBarras'] ?? '').toString(),
      category: (json['categoria'] ?? '').toString(),
      currentStock: _toInt(json['estoqueAtual']),
      minimumStock: _toInt(json['estoqueMinimo']),
      missingQuantity: _toInt(json['quantidadeFaltante']),
    );
  }
}

class SalesDay {
  const SalesDay({required this.day, required this.value, required this.items});

  final DateTime day;
  final double value;
  final int items;

  factory SalesDay.fromJson(Map<String, dynamic> json) {
    return SalesDay(
      day: _toDateTime(json['dia']) ?? DateTime.now(),
      value: _toDouble(json['valor']),
      items: _toInt(json['itens']),
    );
  }
}

class TopSellingProduct {
  const TopSellingProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.value,
  });

  final int productId;
  final String name;
  final int quantity;
  final double value;

  factory TopSellingProduct.fromJson(Map<String, dynamic> json) {
    return TopSellingProduct(
      productId: _toInt(json['produtoId']),
      name: (json['nome'] ?? '').toString(),
      quantity: _toInt(json['quantidade']),
      value: _toDouble(json['valor']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final raw = value?.toString().toLowerCase();
  if (raw == 'true' || raw == '1') return true;
  if (raw == 'false' || raw == '0') return false;

  return fallback;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

List<Map<String, dynamic>> _toObjectList(dynamic value) {
  if (value is! List) return [];

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
