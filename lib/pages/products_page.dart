import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.user, required this.apiService});

  final AppUser user;
  final ApiService apiService;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = AppConfig.demoMode
          ? DemoData.productsSnapshot()
          : await widget.apiService.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _products;

    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.supplier.toLowerCase().contains(query);
    }).toList();
  }

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _openProductForm() async {
    List<CatalogOption> categories;
    List<CatalogOption> suppliers;

    try {
      if (AppConfig.demoMode) {
        categories = DemoData.categories;
        suppliers = DemoData.suppliers;
      } else {
        categories = await widget.apiService.getCategories();
        suppliers = await widget.apiService.getSuppliers();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar categorias e fornecedores: $error',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    if (categories.isEmpty || suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'É necessário ter pelo menos uma categoria e '
            'um fornecedor cadastrados.',
          ),
        ),
      );
      return;
    }

    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) =>
          _ProductFormDialog(categories: categories, suppliers: suppliers),
    );

    if (draft == null || !mounted) return;

    try {
      if (AppConfig.demoMode) {
        DemoData.addProduct(
          name: draft.name,
          categoryId: draft.categoryId,
          supplierId: draft.supplierId,
          price: draft.price,
          quantity: draft.quantity,
        );
      } else {
        await widget.apiService.createProduct(
          name: draft.name,
          categoryId: draft.categoryId,
          supplierId: draft.supplierId,
          price: draft.price,
          quantity: draft.quantity,
        );
      }

      if (!mounted) return;

      await _loadProducts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto cadastrado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível cadastrar o produto: $error')),
      );
    }
  }

  void _showDetails(Product product) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final lowStock = product.isLowStock;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17233C),
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  label: 'Categoria',
                  value: product.category.isEmpty
                      ? 'Não informada'
                      : product.category,
                ),
                _DetailRow(
                  label: 'Fornecedor',
                  value: product.supplier.isEmpty
                      ? 'Não informado'
                      : product.supplier,
                ),
                _DetailRow(
                  label: 'Preço unitário',
                  value: _currency(product.price),
                ),
                _DetailRow(
                  label: 'Quantidade em estoque',
                  value: '${product.quantity} unidades',
                ),
                _DetailRow(label: 'Identificador', value: '${product.id}'),
                if (lowStock) ...[
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB7791F),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atenção: este produto está com estoque baixo.',
                          style: TextStyle(
                            color: Color(0xFF8A5A00),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Produtos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar produtos',
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.user.canManageCatalog
          ? FloatingActionButton.extended(
              onPressed: _openProductForm,
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catálogo de produtos',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17233C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_products.length} produtos cadastrados',
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar produto, categoria ou fornecedor',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildProductList(filteredProducts)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Color(0xFFB42318),
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar os produtos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: Color(0xFF98A2B3),
              ),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isEmpty
                    ? 'Nenhum produto cadastrado.'
                    : 'Nenhum produto encontrado.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final lowStock = product.isLowStock;

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showDetails(product),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDF8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF2457C5),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF17233C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.category.isEmpty
                                ? 'Sem categoria'
                                : product.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _currency(product.price),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF344054),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.quantity}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF17233C),
                          ),
                        ),
                        const Text(
                          'unidades',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF667085),
                          ),
                        ),
                        if (lowStock) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1D6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Estoque baixo',
                              style: TextStyle(
                                color: Color(0xFF8A5A00),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.name,
    required this.categoryId,
    required this.supplierId,
    required this.price,
    required this.quantity,
  });

  final String name;
  final int categoryId;
  final int supplierId;
  final double price;
  final int quantity;
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.categories, required this.suppliers});

  final List<CatalogOption> categories;
  final List<CatalogOption> suppliers;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');

  int? _categoryId;
  int? _supplierId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.first.id;
    _supplierId = widget.suppliers.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  double? _parsePrice(String value) {
    final normalized = value.trim().replaceAll(' ', '');

    if (normalized.contains(',') && normalized.contains('.')) {
      return double.tryParse(
        normalized.replaceAll('.', '').replaceAll(',', '.'),
      );
    }

    return double.tryParse(normalized.replaceAll(',', '.'));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final price = _parsePrice(_priceController.text);
    final quantity = int.tryParse(_quantityController.text.trim());

    if (price == null || !price.isFinite || price < 0) {
      return;
    }

    if (quantity == null ||
        quantity < 0 ||
        _categoryId == null ||
        _supplierId == null) {
      return;
    }

    Navigator.of(context).pop(
      _ProductDraft(
        name: _nameController.text.trim(),
        categoryId: _categoryId!,
        supplierId: _supplierId!,
        price: price,
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo produto'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: widget.categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _categoryId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione uma categoria.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Fornecedor'),
                  items: widget.suppliers.map((supplier) {
                    return DropdownMenuItem<int>(
                      value: supplier.id,
                      child: Text(supplier.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _supplierId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione um fornecedor.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário',
                    hintText: 'Ex.: 49,90',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o preço.';
                    }

                    final price = _parsePrice(value);

                    if (price == null || !price.isFinite || price < 0) {
                      return 'Informe um preço válido.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade inicial',
                  ),
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');

                    if (quantity == null || quantity < 0) {
                      return 'Informe uma quantidade válida.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Cadastrar')),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF17233C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
