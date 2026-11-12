import '../models/models.dart';

/// Dados fictícios usados somente no modo demonstração.
class DemoData {
  static int _nextProductId = 9;
  static int _nextMovementId = 4;

  static final List<CatalogOption> categories = [
    const CatalogOption(id: 1, name: 'Informática'),
    const CatalogOption(id: 2, name: 'Escritório'),
    const CatalogOption(id: 3, name: 'Acessórios'),
  ];

  static final List<CatalogOption> suppliers = [
    const CatalogOption(id: 1, name: 'Fornecedor Central'),
    const CatalogOption(id: 2, name: 'Distribuidora Alfa'),
    const CatalogOption(id: 3, name: 'Tech Supply'),
  ];

  static final List<Product> products = [
    const Product(
      id: 1,
      name: 'Mouse sem fio',
      categoryId: 3,
      category: 'Acessórios',
      supplierId: 3,
      supplier: 'Tech Supply',
      price: 59.90,
      quantity: 24,
    ),
    const Product(
      id: 2,
      name: 'Teclado USB',
      categoryId: 3,
      category: 'Acessórios',
      supplierId: 3,
      supplier: 'Tech Supply',
      price: 89.90,
      quantity: 3,
      isLowStock: true,
    ),
    const Product(
      id: 3,
      name: 'Monitor 24 polegadas',
      categoryId: 1,
      category: 'Informática',
      supplierId: 1,
      supplier: 'Fornecedor Central',
      price: 799.90,
      quantity: 8,
    ),
    const Product(
      id: 4,
      name: 'Caderno universitário',
      categoryId: 2,
      category: 'Escritório',
      supplierId: 2,
      supplier: 'Distribuidora Alfa',
      price: 19.90,
      quantity: 2,
      isLowStock: true,
    ),
    const Product(
      id: 5,
      name: 'Headset USB',
      categoryId: 3,
      category: 'Acessórios',
      supplierId: 3,
      supplier: 'Tech Supply',
      price: 129.90,
      quantity: 12,
    ),
    const Product(
      id: 6,
      name: 'Webcam HD',
      categoryId: 1,
      category: 'Informática',
      supplierId: 1,
      supplier: 'Fornecedor Central',
      price: 149.90,
      quantity: 4,
      isLowStock: true,
    ),
    const Product(
      id: 7,
      name: 'Papel A4 - pacote',
      categoryId: 2,
      category: 'Escritório',
      supplierId: 2,
      supplier: 'Distribuidora Alfa',
      price: 29.90,
      quantity: 31,
    ),
    const Product(
      id: 8,
      name: 'Cabo USB-C',
      categoryId: 3,
      category: 'Acessórios',
      supplierId: 3,
      supplier: 'Tech Supply',
      price: 24.90,
      quantity: 18,
    ),
  ];

  static final List<Movement> movements = [
    Movement(
      id: 3,
      productId: 1,
      productName: 'Mouse sem fio',
      type: 'Entry',
      quantity: 10,
      dateUtc: DateTime.now().subtract(const Duration(hours: 2)),
      userName: 'Admin',
    ),
    Movement(
      id: 2,
      productId: 2,
      productName: 'Teclado USB',
      type: 'Exit',
      quantity: 2,
      dateUtc: DateTime.now().subtract(const Duration(days: 1)),
      userName: 'Operador',
    ),
    Movement(
      id: 1,
      productId: 3,
      productName: 'Monitor 24 polegadas',
      type: 'Entry',
      quantity: 5,
      dateUtc: DateTime.now().subtract(const Duration(days: 2)),
      userName: 'Admin',
    ),
  ];

  static List<Product> productsSnapshot() {
    return List<Product>.unmodifiable(products);
  }

  static List<Movement> movementsSnapshot() {
    return List<Movement>.unmodifiable(movements);
  }

  /// Adiciona um produto fictício ao catálogo.
  static void addProduct({
    required String name,
    required int categoryId,
    required int supplierId,
    required double price,
    required int quantity,
  }) {
    final category = categories.firstWhere((item) => item.id == categoryId);

    final supplier = suppliers.firstWhere((item) => item.id == supplierId);

    products.add(
      Product(
        id: _nextProductId++,
        name: name,
        categoryId: categoryId,
        category: category.name,
        supplierId: supplierId,
        supplier: supplier.name,
        price: price,
        quantity: quantity,
        isLowStock: quantity < 5,
      ),
    );
  }

  /// Adiciona uma movimentação fictícia e atualiza o estoque.
  static void addMovement({
    required int productId,
    required bool isEntry,
    required int quantity,
    String? paymentMethod,
  }) {
    if (quantity <= 0) {
      throw Exception('A quantidade precisa ser maior que zero.');
    }

    final index = products.indexWhere((product) => product.id == productId);

    if (index < 0) {
      throw Exception('Produto não encontrado.');
    }

    final product = products[index];

    if (!isEntry && quantity > product.quantity) {
      throw Exception('A saída não pode ser maior que o estoque disponível.');
    }

    final updatedQuantity = isEntry
        ? product.quantity + quantity
        : product.quantity - quantity;

    // Preserva o estoque mínimo configurado.
    // Quando não houver estoque mínimo, utiliza cinco unidades como padrão.
    final minimumStock = product.minimumStock > 0 ? product.minimumStock : 5;

    // Atualiza a quantidade sem perder os demais dados do produto.
    products[index] = Product(
      id: product.id,
      name: product.name,
      categoryId: product.categoryId,
      category: product.category,
      supplierId: product.supplierId,
      supplier: product.supplier,
      price: product.price,
      quantity: updatedQuantity,
      isLowStock: updatedQuantity < minimumStock,
      barcode: product.barcode,
      minimumStock: product.minimumStock,
      isActive: product.isActive,
      updatedAt: DateTime.now().toUtc(),
    );

    movements.insert(
      0,
      Movement(
        id: _nextMovementId++,
        productId: product.id,
        productName: product.name,
        type: isEntry ? 'Entry' : 'Exit',
        quantity: quantity,
        dateUtc: DateTime.now(),
        userName: 'Demonstração',
        paymentMethod: paymentMethod,
      ),
    );
  }
}
