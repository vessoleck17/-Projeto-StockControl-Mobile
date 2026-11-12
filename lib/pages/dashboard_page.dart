import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.apiService,
    required this.onOpenProducts,
    required this.onOpenMovements,
  });

  final AppUser user;
  final ApiService apiService;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenMovements;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Product> _products = [];
  List<Movement> _movements = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      late List<Product> products;
      late List<Movement> movements;

      if (AppConfig.demoMode) {
        products = DemoData.productsSnapshot();
        movements = DemoData.movementsSnapshot();
      } else {
        products = await widget.apiService.getProducts();
        movements = await widget.apiService.getMovements();
      }

      if (!mounted) return;

      setState(() {
        _products = products;
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

  int get _lowStockCount {
    return _products.where((product) => product.isLowStock).length;
  }

  int get _totalUnits {
    return _products.fold<int>(0, (total, product) => total + product.quantity);
  }

  int get _totalEntries {
    return _movements
        .where((movement) => movement.isEntry)
        .fold<int>(0, (total, movement) => total + movement.quantity);
  }

  int get _totalExits {
    return _movements
        .where((movement) => !movement.isEntry)
        .fold<int>(0, (total, movement) => total + movement.quantity);
  }

  Future<void> _logout() async {
    if (!AppConfig.demoMode) {
      await widget.apiService.sessionStore.clearSession();
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(apiService: widget.apiService),
      ),
      (route) => false,
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF17233C);
    const blue = Color(0xFF2457C5);
    const muted = Color(0xFF667085);
    const green = Color(0xFF16845B);
    const orange = Color(0xFFB7791F);

    final firstName = widget.user.name.trim().isEmpty
        ? 'Usuário'
        : widget.user.name.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'StockControl',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Olá, $firstName',
                        style: const TextStyle(
                          color: navy,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Confira o resumo do seu estoque.',
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      if (AppConfig.demoMode)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EDF4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'MODO DEMONSTRAÇÃO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: navy,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Visão geral',
                        style: TextStyle(
                          color: navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorMessage != null)
                        _ErrorPanel(message: _errorMessage!, onRetry: _loadData)
                      else ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricCard(
                              width: _cardWidth(constraints.maxWidth),
                              title: 'Produtos',
                              value: '${_products.length}',
                              subtitle: 'Itens cadastrados',
                              icon: Icons.inventory_2_outlined,
                              iconColor: blue,
                            ),
                            _MetricCard(
                              width: _cardWidth(constraints.maxWidth),
                              title: 'Unidades',
                              value: '$_totalUnits',
                              subtitle: 'No estoque atual',
                              icon: Icons.warehouse_outlined,
                              iconColor: navy,
                            ),
                            _MetricCard(
                              width: _cardWidth(constraints.maxWidth),
                              title: 'Estoque baixo',
                              value: '$_lowStockCount',
                              subtitle: 'Produtos para verificar',
                              icon: Icons.warning_amber_rounded,
                              iconColor: orange,
                            ),
                            _MetricCard(
                              width: _cardWidth(constraints.maxWidth),
                              title: 'Entradas',
                              value: '$_totalEntries',
                              subtitle: 'Unidades movimentadas',
                              icon: Icons.arrow_downward_rounded,
                              iconColor: green,
                            ),
                            _MetricCard(
                              width: _cardWidth(constraints.maxWidth),
                              title: 'Saídas',
                              value: '$_totalExits',
                              subtitle: 'Unidades movimentadas',
                              icon: Icons.arrow_upward_rounded,
                              iconColor: blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Acesso rápido',
                          style: TextStyle(
                            color: navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _QuickAccessTile(
                          icon: Icons.inventory_2_outlined,
                          title: 'Produtos',
                          subtitle: 'Consultar o catálogo de produtos',
                          onTap: widget.onOpenProducts,
                        ),
                        const SizedBox(height: 10),
                        _QuickAccessTile(
                          icon: Icons.swap_horiz_rounded,
                          title: 'Movimentações',
                          subtitle: 'Consultar entradas e saídas',
                          onTap: widget.onOpenMovements,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Movimentações recentes',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Atualizar dados',
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_movements.isEmpty)
                          const _EmptyPanel(
                            message: 'Nenhuma movimentação registrada.',
                          )
                        else
                          ..._movements
                              .take(5)
                              .map(
                                (movement) => _MovementTile(
                                  movement: movement,
                                  dateLabel: _formatDate(movement.dateUtc),
                                ),
                              ),
                      ],
                      const SizedBox(height: 28),
                      const Text(
                        'StockControl • Gestão inteligente de estoque',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _cardWidth(double availableWidth) {
    final usableWidth = availableWidth > 1000 ? 960.0 : availableWidth - 40;
    final columns = usableWidth >= 760 ? 4 : 2;

    return (usableWidth - ((columns - 1) * 12)) / columns;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 23, color: iconColor),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17233C),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: const Color(0xFF2457C5), size: 25),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF667085),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.dateLabel});

  final Movement movement;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.isEntry;
    final color = isEntry ? const Color(0xFF16845B) : const Color(0xFF2457C5);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEntry ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: color,
          ),
        ),
        title: Text(
          movement.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${isEntry ? 'Entrada' : 'Saída'} • $dateLabel',
          style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
        ),
        trailing: Text(
          '${isEntry ? '+' : '-'}${movement.quantity}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar os dados',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ),
      ),
    );
  }
}
