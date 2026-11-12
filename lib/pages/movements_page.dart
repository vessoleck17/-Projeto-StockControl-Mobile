import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class MovementsPage extends StatefulWidget {
  const MovementsPage({
    super.key,
    required this.user,
    required this.apiService,
  });

  final AppUser user;
  final ApiService apiService;

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Movement> _movements = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'Todas';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    _loadData();
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

  // Carrega o histórico de movimentações.
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movements = AppConfig.demoMode
          ? DemoData.movementsSnapshot()
          : await widget.apiService.getMovements();

      if (!mounted) return;

      setState(() {
        _movements = movements;
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

  // Filtra movimentações por produto, usuário e tipo.
  List<Movement> get _filteredMovements {
    final query = _searchController.text.trim().toLowerCase();

    return _movements.where((movement) {
      final matchesSearch =
          movement.productName.toLowerCase().contains(query) ||
          movement.userName.toLowerCase().contains(query);

      final matchesType = switch (_filter) {
        'Entradas' => movement.isEntry,
        'Saídas' => !movement.isEntry,
        _ => true,
      };

      return matchesSearch && matchesType;
    }).toList();
  }

  // Formata a data da movimentação.
  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} às $hour:$minute';
  }

  // Abre o formulário para registrar uma nova movimentação.
  Future<void> _openMovementForm() async {
    try {
      // Consulta os produtos disponíveis.
      final products = AppConfig.demoMode
          ? DemoData.productsSnapshot()
          : await widget.apiService.getProducts();

      if (!mounted) return;

      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cadastre um produto antes de registrar uma movimentação.',
            ),
          ),
        );
        return;
      }

      final draft = await showDialog<_MovementDraft>(
        context: context,
        builder: (_) => _MovementFormDialog(products: products),
      );

      if (draft == null || !mounted) return;

      // Registra a movimentação no modo de demonstração ou na API.
      if (AppConfig.demoMode) {
        DemoData.addMovement(
          productId: draft.productId,
          isEntry: draft.isEntry,
          quantity: draft.quantity,
          paymentMethod: draft.paymentMethod,
        );
      } else {
        await widget.apiService.createMovement(
          productId: draft.productId,
          isEntry: draft.isEntry,
          quantity: draft.quantity,
          paymentMethod: draft.paymentMethod,
        );
      }

      if (!mounted) return;

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimentação registrada com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final movements = _filteredMovements;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Movimentações',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar histórico',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMovementForm,
        icon: const Icon(Icons.add),
        label: const Text('Nova movimentação'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Histórico de estoque',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17233C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Acompanhe as entradas e saídas de produtos.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar produto ou usuário',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Limpar busca',
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<String>(
                            value: 'Todas',
                            label: Text('Todas'),
                          ),
                          ButtonSegment<String>(
                            value: 'Entradas',
                            label: Text('Entradas'),
                          ),
                          ButtonSegment<String>(
                            value: 'Saídas',
                            label: Text('Saídas'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildMovementList(movements)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Exibe o histórico de movimentações.
  Widget _buildMovementList(List<Movement> movements) {
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
                size: 40,
                color: Color(0xFFB42318),
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar as movimentações.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (movements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma movimentação encontrada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF667085)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: movements.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final movement = movements[index];
          final isEntry = movement.isEntry;

          final color = isEntry
              ? const Color(0xFF16845B)
              : const Color(0xFF2457C5);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEntry
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                ),
              ),
              title: Text(
                movement.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF17233C),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '${isEntry ? 'Entrada' : 'Saída'} • '
                  '${_formatDate(movement.dateUtc)}'
                  '${movement.userName.isEmpty ? '' : '\nResponsável: ${movement.userName}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF667085),
                  ),
                ),
              ),
              trailing: Text(
                '${isEntry ? '+' : '-'}${movement.quantity}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Dados temporários do formulário.
class _MovementDraft {
  const _MovementDraft({
    required this.productId,
    required this.isEntry,
    required this.quantity,
    this.paymentMethod,
  });

  final int productId;
  final bool isEntry;
  final int quantity;
  final String? paymentMethod;
}

// Formulário de entrada e saída de estoque.
class _MovementFormDialog extends StatefulWidget {
  const _MovementFormDialog({required this.products});

  final List<Product> products;

  @override
  State<_MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<_MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController(text: '1');

  int? _productId;
  String _type = 'Entry';
  String? _paymentMethod;

  bool get _isEntry => _type == 'Entry';

  @override
  void initState() {
    super.initState();
    _productId = widget.products.first.id;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0 || _productId == null) {
      return;
    }

    final product = widget.products.firstWhere((item) => item.id == _productId);

    if (!_isEntry && quantity > product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A saída não pode exceder o estoque disponível.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _MovementDraft(
        productId: _productId!,
        isEntry: _isEntry,
        quantity: quantity,
        paymentMethod: _isEntry ? null : _paymentMethod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = widget.products.firstWhere(
      (product) => product.id == _productId,
    );

    return AlertDialog(
      title: const Text('Nova movimentação'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de movimentação',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Entry', child: Text('Entrada')),
                    DropdownMenuItem(value: 'Exit', child: Text('Saída')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _type = value;
                      _paymentMethod = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produto'),
                  items: widget.products.map((product) {
                    return DropdownMenuItem<int>(
                      value: product.id,
                      child: Text(
                        '${product.name} (${product.quantity} un.)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _productId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione um produto.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Estoque atual: ${selectedProduct.quantity} unidades',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');

                    if (quantity == null || quantity <= 0) {
                      return 'Informe uma quantidade maior que zero.';
                    }

                    return null;
                  },
                ),
                if (!_isEntry) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento (opcional)',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Dinheiro',
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                      DropdownMenuItem(value: 'Cartão', child: Text('Cartão')),
                      DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _paymentMethod = value;
                      });
                    },
                  ),
                ],
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
        FilledButton(onPressed: _save, child: const Text('Registrar')),
      ],
    );
  }
}
