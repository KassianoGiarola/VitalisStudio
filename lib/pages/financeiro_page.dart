import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/financeiro_service.dart';
import '../widgets/app_shell.dart';

class FinanceiroPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const FinanceiroPage({
    super.key,
    this.nome = '',
    this.email = '',
    required this.role,
    this.embedded = false,
  });

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  bool _mostrarTotais = false;

  bool get isAdmin => widget.role == 'admin';

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatarValorOuOculto(double valor) {
    return _mostrarTotais ? _formatarValor(valor) : '••••••';
  }

  double _toDouble(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0;
  }

  Color _corTipo(String tipo) {
    return tipo == 'entrada' ? VitalisColors.sucesso : VitalisColors.erro;
  }

  IconData _iconeTipo(String tipo) {
    return tipo == 'entrada'
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
  }

  String _formatarData(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Sem data';

    final data = timestamp.toDate();
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano • $hora:$minuto';
  }

  String _formatarDataCurta(DateTime? data) {
    if (data == null) return '--/--/----';

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  bool _estaDentroDoFiltro(Timestamp? timestamp) {
    if (timestamp == null) return false;

    final data = timestamp.toDate();

    if (_dataInicial != null) {
      final inicio = DateTime(
        _dataInicial!.year,
        _dataInicial!.month,
        _dataInicial!.day,
      );

      if (data.isBefore(inicio)) {
        return false;
      }
    }

    if (_dataFinal != null) {
      final fim = DateTime(
        _dataFinal!.year,
        _dataFinal!.month,
        _dataFinal!.day,
        23,
        59,
        59,
      );

      if (data.isAfter(fim)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _selecionarDataInicial() async {
    final agora = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataInicial ?? agora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() {
        _dataInicial = data;
      });
    }
  }

  Future<void> _selecionarDataFinal() async {
    final agora = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataFinal ?? _dataInicial ?? agora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() {
        _dataFinal = data;
      });
    }
  }

  void _limparFiltro() {
    setState(() {
      _dataInicial = null;
      _dataFinal = null;
    });
  }

  Future<void> _abrirNovaMovimentacao() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NovaMovimentacaoDialog(),
    );
  }

  Future<void> _abrirEdicaoMovimentacao(
    String id,
    Map<String, dynamic> dados,
  ) async {
    if ((dados['mensalidadeId'] ?? '').toString().isNotEmpty) {
      _mostrarMovimentacaoAutomatica();
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovaMovimentacaoDialog(movimentacaoId: id, dados: dados),
    );
  }

  Future<void> _excluirMovimentacao(
    String id,
    Map<String, dynamic> dados,
  ) async {
    if ((dados['mensalidadeId'] ?? '').toString().isNotEmpty) {
      _mostrarMovimentacaoAutomatica();
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir movimentação?'),
        content: Text(
          'A movimentação "${(dados['descricao'] ?? 'Sem descrição')}" será excluída permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VitalisColors.erro),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await FinanceiroService.excluirMovimentacao(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimentação excluída com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir movimentação: $error')),
      );
    }
  }

  void _mostrarMovimentacaoAutomatica() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Esta movimentação foi gerada por uma mensalidade. Faça a alteração na página Mensalidades.',
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      if (isAdmin)
        IconButton(
          tooltip: _mostrarTotais ? 'Ocultar totais' : 'Mostrar totais',
          onPressed: () {
            setState(() {
              _mostrarTotais = !_mostrarTotais;
            });
          },
          icon: Icon(
            _mostrarTotais
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: Colors.white,
          ),
        ),
    ];
  }

  Widget _buildEmbeddedHeader() {
    if (!isAdmin) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitalisColors.borda),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: VitalisColors.verdeEsmeralda.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: VitalisColors.verdeEsmeralda,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controle financeiro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Acompanhe movimentações, filtros e totais do período.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: VitalisColors.cinzaMedio),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _mostrarTotais ? 'Ocultar totais' : 'Mostrar totais',
            onPressed: () {
              setState(() {
                _mostrarTotais = !_mostrarTotais;
              });
            },
            icon: Icon(
              _mostrarTotais
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: VitalisColors.azulMarinhoProfundo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      backgroundColor: VitalisColors.verdeEsmeralda,
      foregroundColor: Colors.white,
      onPressed: _abrirNovaMovimentacao,
      icon: const Icon(Icons.add),
      label: const Text('Nova movimentação'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Financeiro',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'financeiro',
      actions: _buildActions(),
      floatingActionButton: _buildFloatingActionButton(),
      child: content,
    );
  }

  Widget _buildContent() {
    final filtroAtivo = _dataInicial != null || _dataFinal != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FinanceiroService.listarMovimentacoes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: VitalisColors.verdeEsmeralda,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar movimentações.',
                style: TextStyle(
                  color: VitalisColors.azulMarinhoProfundo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final docsFiltrados = docs.where((doc) {
            final data = doc.data();
            return _estaDentroDoFiltro(data['createdAt'] as Timestamp?);
          }).toList();

          double totalEntradas = 0;
          double totalSaidas = 0;

          for (final doc in docsFiltrados) {
            final data = doc.data();
            final tipo = (data['tipo'] ?? '').toString();
            final valor = _toDouble(data['valor']);

            if (tipo == 'entrada') {
              totalEntradas += valor;
            } else if (tipo == 'saida') {
              totalSaidas += valor;
            }
          }

          final saldo = totalEntradas - totalSaidas;

          final resumoCards = [
            _ResumoFinanceiroCard(
              titulo: 'Entradas',
              valor: _formatarValorOuOculto(totalEntradas),
              icone: Icons.arrow_downward_rounded,
              valorColor: VitalisColors.sucesso,
            ),
            _ResumoFinanceiroCard(
              titulo: 'Saídas',
              valor: _formatarValorOuOculto(totalSaidas),
              icone: Icons.arrow_upward_rounded,
              valorColor: VitalisColors.erro,
            ),
            _ResumoFinanceiroCard(
              titulo: 'Saldo',
              valor: _formatarValorOuOculto(saldo),
              icone: Icons.account_balance_wallet_outlined,
              valorColor: saldo >= 0
                  ? VitalisColors.sucesso
                  : VitalisColors.erro,
            ),
          ];

          return Column(
            children: [
              if (widget.embedded) _buildEmbeddedHeader(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: VitalisColors.borda),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Filtro por período',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: VitalisColors.azulMarinhoProfundo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        SizedBox(
                          width: 185,
                          child: InkWell(
                            onTap: _selecionarDataInicial,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data inicial',
                                prefixIcon: Icon(Icons.calendar_month_outlined),
                              ),
                              child: Text(_formatarDataCurta(_dataInicial)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 185,
                          child: InkWell(
                            onTap: _selecionarDataFinal,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data final',
                                prefixIcon: Icon(
                                  Icons.event_available_outlined,
                                ),
                              ),
                              child: Text(_formatarDataCurta(_dataFinal)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: OutlinedButton.icon(
                            onPressed: filtroAtivo ? _limparFiltro : null,
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      filtroAtivo
                          ? '${docsFiltrados.length} movimentação(ões) no período.'
                          : 'Exibindo todas as movimentações.',
                      style: const TextStyle(
                        color: VitalisColors.cinzaEscuro,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: resumoCards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) => resumoCards[index],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_money_rounded,
                                size: 54,
                                color: VitalisColors.cobreQueimado,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Nenhuma movimentação registrada.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: VitalisColors.azulMarinhoProfundo,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Clique em "Nova movimentação" para começar.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : docsFiltrados.isEmpty
                    ? Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_alt_off_rounded,
                                size: 54,
                                color: VitalisColors.cobreQueimado,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Nenhuma movimentação encontrada nesse período.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: VitalisColors.azulMarinhoProfundo,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: docsFiltrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc = docsFiltrados[i];
                          final data = doc.data();

                          final tipo = (data['tipo'] ?? '').toString();
                          final valor = _toDouble(data['valor']);
                          final descricao =
                              (data['descricao'] ?? 'Sem descrição').toString();
                          final forma = (data['formaPagamento'] ?? 'Sem forma')
                              .toString();
                          final categoria =
                              (data['categoria'] ?? 'Sem categoria').toString();
                          final afetaCaixa = data['afetaCaixa'] == true;
                          final createdAt = data['createdAt'];

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _corTipo(
                                      tipo,
                                    ).withOpacity(0.12),
                                    child: Icon(
                                      _iconeTipo(tipo),
                                      color: _corTipo(tipo),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          descricao,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: VitalisColors
                                                .azulMarinhoProfundo,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _MovimentoChip(
                                              label: categoria,
                                              icon: Icons.category_outlined,
                                            ),
                                            _MovimentoChip(
                                              label: forma,
                                              icon: Icons.payments_outlined,
                                            ),
                                            _MovimentoChip(
                                              label: afetaCaixa
                                                  ? 'Afeta caixa'
                                                  : 'Não afeta caixa',
                                              icon: afetaCaixa
                                                  ? Icons
                                                        .account_balance_wallet_outlined
                                                  : Icons.credit_card_outlined,
                                              color: afetaCaixa
                                                  ? VitalisColors.verdeEsmeralda
                                                  : VitalisColors.cinzaMedio,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatarData(createdAt),
                                          style: const TextStyle(
                                            color: VitalisColors.cinzaMedio,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatarValor(valor),
                                    style: TextStyle(
                                      color: _corTipo(tipo),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      tooltip: 'Ações',
                                      onSelected: (acao) {
                                        if (acao == 'editar') {
                                          _abrirEdicaoMovimentacao(
                                            doc.id,
                                            data,
                                          );
                                        } else if (acao == 'excluir') {
                                          _excluirMovimentacao(doc.id, data);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'editar',
                                          child: ListTile(
                                            leading: Icon(Icons.edit_outlined),
                                            title: Text('Editar'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'excluir',
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.delete_outline_rounded,
                                              color: VitalisColors.erro,
                                            ),
                                            title: Text('Excluir'),
                                            contentPadding: EdgeInsets.zero,
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NovaMovimentacaoDialog extends StatefulWidget {
  final String? movimentacaoId;
  final Map<String, dynamic>? dados;

  const NovaMovimentacaoDialog({super.key, this.movimentacaoId, this.dados});

  bool get isEdicao => movimentacaoId != null;

  @override
  State<NovaMovimentacaoDialog> createState() => _NovaMovimentacaoDialogState();
}

class _NovaMovimentacaoDialogState extends State<NovaMovimentacaoDialog> {
  final _formKey = GlobalKey<FormState>();

  String _tipo = 'saida';
  String _forma = 'dinheiro';

  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _categoriaController = TextEditingController();

  bool _loading = false;

  final List<String> _formas = const [
    'dinheiro',
    'pix',
    'cartao',
    'transferencia',
  ];

  @override
  void initState() {
    super.initState();

    final dados = widget.dados;
    if (dados == null) return;

    _tipo = (dados['tipo'] ?? 'saida').toString();
    _forma = (dados['formaPagamento'] ?? 'dinheiro').toString();
    _valorController.text = _toDouble(
      dados['valor'],
    ).toStringAsFixed(2).replaceAll('.', ',');
    _descricaoController.text = (dados['descricao'] ?? '').toString();
    _categoriaController.text = (dados['categoria'] ?? '').toString();
  }

  double _toDouble(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido maior que zero.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final categoria = _categoriaController.text.trim().isEmpty
          ? 'manual'
          : _categoriaController.text.trim();
      final descricao = _descricaoController.text.trim();

      if (widget.isEdicao) {
        await FinanceiroService.atualizarMovimentacao(
          id: widget.movimentacaoId!,
          tipo: _tipo,
          valor: valor,
          formaPagamento: _forma,
          categoria: categoria,
          descricao: descricao,
        );
      } else {
        await FinanceiroService.registrarMovimentacao(
          tipo: _tipo,
          valor: valor,
          formaPagamento: _forma,
          categoria: categoria,
          descricao: descricao,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdicao
                ? 'Movimentação atualizada com sucesso.'
                : 'Movimentação registrada com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao ${widget.isEdicao ? 'atualizar' : 'registrar'} movimentação: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final afetaCaixa = _forma == 'dinheiro';

    return AlertDialog(
      backgroundColor: VitalisColors.offWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isEdicao ? 'Editar movimentação' : 'Nova movimentação',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: VitalisColors.azulMarinhoProfundo,
        ),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.swap_vert_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                    DropdownMenuItem(value: 'saida', child: Text('Saída')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tipo = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o valor.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _forma,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: _formas
                      .map(
                        (forma) => DropdownMenuItem<String>(
                          value: forma,
                          child: Text(forma),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _forma = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        afetaCaixa
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card_outlined,
                        color: afetaCaixa
                            ? VitalisColors.verdeEsmeralda
                            : VitalisColors.cinzaMedio,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          afetaCaixa
                              ? 'Essa movimentação afeta o caixa.'
                              : 'Essa movimentação não afeta o caixa.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: afetaCaixa
                                ? VitalisColors.verdeEsmeralda
                                : VitalisColors.cinzaMedio,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoriaController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe uma descrição.';
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
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _salvar,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ResumoFinanceiroCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color valorColor;

  const _ResumoFinanceiroCard({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.valorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VitalisColors.borda),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: valorColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: valorColor, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: valorColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimentoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _MovimentoChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? VitalisColors.cinzaMedio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
