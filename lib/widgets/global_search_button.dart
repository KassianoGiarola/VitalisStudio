import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class GlobalSearchButton extends StatelessWidget {
  final String role;
  final String currentPage;
  final ValueChanged<String> onNavigate;

  const GlobalSearchButton({
    super.key,
    required this.role,
    required this.currentPage,
    required this.onNavigate,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  List<_GlobalSearchResult> get _moduleItems {
    final base = <_GlobalSearchResult>[
      const _GlobalSearchResult(
        pageKey: 'home',
        title: 'Painel inicial',
        subtitle: 'Voltar para a visão geral',
        icon: Icons.dashboard_rounded,
        type: 'Módulo',
        keywords: 'home painel inicio inicial dashboard visão geral',
      ),
      const _GlobalSearchResult(
        pageKey: 'clientes',
        title: 'Clientes',
        subtitle: 'Cadastro, edição, busca e WhatsApp',
        icon: Icons.people_alt_rounded,
        type: 'Módulo',
        keywords: 'clientes cliente cadastro editar telefone cpf whatsapp',
      ),
      const _GlobalSearchResult(
        pageKey: 'servicos',
        title: 'Serviços',
        subtitle: 'Planos, valores e tipos de cobrança',
        icon: Icons.design_services_rounded,
        type: 'Módulo',
        keywords:
            'serviços servicos planos valores preço preco natação pilates hidro',
      ),
      const _GlobalSearchResult(
        pageKey: 'mensalidades',
        title: 'Mensalidades',
        subtitle: 'Lançamentos, pagamentos e vencimentos',
        icon: Icons.event_note_rounded,
        type: 'Módulo',
        keywords:
            'mensalidades mensalidade pagamento vencimento vencido pendente pago',
      ),
      const _GlobalSearchResult(
        pageKey: 'cobrancas',
        title: 'Cobranças',
        subtitle: 'Mensagens e pendências de pagamento',
        icon: Icons.chat_bubble_outline_rounded,
        type: 'Módulo',
        keywords:
            'cobranças cobrancas cobrança whatsapp mensagem pendencias pendências',
      ),
      const _GlobalSearchResult(
        pageKey: 'aniversariantes',
        title: 'Aniversariantes',
        subtitle: 'Clientes com aniversário próximo',
        icon: Icons.cake_rounded,
        type: 'Módulo',
        keywords:
            'aniversariantes aniversario aniversário parabens parabéns criança cliente',
      ),
      const _GlobalSearchResult(
        pageKey: 'financeiro',
        title: 'Lançamentos financeiros',
        subtitle: 'Entradas, saídas e movimentações',
        icon: Icons.attach_money_rounded,
        type: 'Módulo',
        keywords:
            'financeiro dinheiro pix entrada saída saida saldo movimentação movimentacao lançamento lançamentos',
      ),
      const _GlobalSearchResult(
        pageKey: 'pdfs',
        title: 'PDFs',
        subtitle: 'Modelos, documentos e impressões',
        icon: Icons.picture_as_pdf_rounded,
        type: 'Módulo',
        keywords: 'pdf pdfs documentos modelos imprimir impressão impressao',
      ),
    ];

    if (!isAdmin) return base;

    return [
      ...base,
      const _GlobalSearchResult(
        pageKey: 'dashboard',
        title: 'Dashboard',
        subtitle: 'Indicadores analíticos do negócio',
        icon: Icons.insights_rounded,
        type: 'Módulo',
        keywords:
            'dashboard indicadores analitico analítico gráficos graficos receita lucro faturamento',
      ),
      const _GlobalSearchResult(
        pageKey: 'caixa',
        title: 'Caixa',
        subtitle: 'Abertura, fechamento e histórico',
        icon: Icons.point_of_sale_rounded,
        type: 'Módulo',
        keywords: 'caixa abertura fechamento troco retirada saldo dinheiro',
      ),
      const _GlobalSearchResult(
        pageKey: 'lembretes',
        title: 'Lembretes',
        subtitle: 'Mensagens, lembretes e preferências',
        icon: Icons.notifications_active_outlined,
        type: 'Módulo',
        keywords:
            'lembrete lembretes configurações configuracoes mensagem aniversario cobrança cobranca',
      ),
    ];
  }

  Future<void> _abrirPesquisa(BuildContext context) async {
    await showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => _GlobalSearchDialog(
        moduleItems: _moduleItems,
        currentPage: currentPage,
        role: role,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pesquisar no sistema',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _abrirPesquisa(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: const Icon(Icons.search_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlobalSearchDialog extends StatefulWidget {
  final List<_GlobalSearchResult> moduleItems;
  final String currentPage;
  final String role;
  final ValueChanged<String> onNavigate;

  const _GlobalSearchDialog({
    required this.moduleItems,
    required this.currentPage,
    required this.role,
    required this.onNavigate,
  });

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final TextEditingController _controller = TextEditingController();

  String _busca = '';
  bool _loading = true;

  final List<_GlobalSearchResult> _dataItems = [];

  bool get isAdmin => widget.role.trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        _busca = _controller.text;
      });
    });

    _carregarDadosPesquisa();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _podeAcessar(String pageKey) {
    if (isAdmin) return true;

    const paginasFuncionario = {
      'home',
      'clientes',
      'servicos',
      'mensalidades',
      'cobrancas',
      'aniversariantes',
      'pdfs',
      'financeiro',
    };

    return paginasFuncionario.contains(pageKey);
  }

  Future<void> _carregarDadosPesquisa() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final resultados = await Future.wait([
        firestore.collection('clientes').orderBy('nome').limit(500).get(),
        firestore.collection('servicos').orderBy('nome').limit(300).get(),
        firestore
            .collection('mensalidades')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get(),
      ]);

      final clientes = resultados[0];
      final servicos = resultados[1];
      final mensalidades = resultados[2];

      final itens = <_GlobalSearchResult>[];

      for (final doc in clientes.docs) {
        final data = doc.data();

        final nome = (data['nome'] ?? 'Sem nome').toString();
        final telefone = (data['telefone'] ?? '').toString();
        final cpf = (data['cpf'] ?? '').toString();
        final nomeCrianca = (data['nomeCrianca'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        final categoria = (data['categoria'] ?? '').toString();

        itens.add(
          _GlobalSearchResult(
            pageKey: 'clientes',
            title: nome,
            subtitle: [
              'Cliente',
              if (telefone.isNotEmpty) telefone,
              if (cpf.isNotEmpty) cpf,
              if (nomeCrianca.isNotEmpty) 'Criança: $nomeCrianca',
            ].join(' • '),
            icon: Icons.person_rounded,
            type: 'Cliente',
            keywords:
                '$nome $telefone $cpf $nomeCrianca $status $categoria cliente clientes',
          ),
        );
      }

      for (final doc in servicos.docs) {
        final data = doc.data();

        final nome = (data['nome'] ?? 'Sem serviço').toString();
        final tipo = (data['tipoCobranca'] ?? '').toString();
        final valor = (data['valor'] ?? '').toString();
        final ativo = data['ativo'] == true ? 'ativo' : 'inativo';

        itens.add(
          _GlobalSearchResult(
            pageKey: 'servicos',
            title: nome,
            subtitle: 'Serviço • $tipo • R\$ $valor',
            icon: Icons.design_services_rounded,
            type: 'Serviço',
            keywords:
                '$nome $tipo $valor $ativo serviço servico serviços servicos',
          ),
        );
      }

      for (final doc in mensalidades.docs) {
        final data = doc.data();

        final nomeCliente = (data['nomeCliente'] ?? 'Sem cliente').toString();
        final nomeServico = (data['nomeServico'] ?? 'Sem serviço').toString();
        final status = (data['status'] ?? '').toString();
        final competencia = (data['competencia'] ?? '').toString();
        final tipoCobranca = (data['tipoCobranca'] ?? '').toString();
        final valorFinal = (data['valorFinal'] ?? '').toString();

        itens.add(
          _GlobalSearchResult(
            pageKey: 'mensalidades',
            title: '$nomeCliente • $nomeServico',
            subtitle: 'Mensalidade • $status • $competencia • R\$ $valorFinal',
            icon: Icons.event_note_rounded,
            type: 'Mensalidade',
            keywords:
                '$nomeCliente $nomeServico $status $competencia $tipoCobranca $valorFinal mensalidade mensalidades pagamento vencimento',
          ),
        );
      }

      final itensPermitidos = itens.where((item) {
        return _podeAcessar(item.pageKey);
      }).toList();

      if (!mounted) return;

      setState(() {
        _dataItems.clear();
        _dataItems.addAll(itensPermitidos);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  List<_GlobalSearchResult> get _filtrados {
    final busca = _normalizar(_busca);

    final todos = [...widget.moduleItems, ..._dataItems].where((item) {
      return _podeAcessar(item.pageKey);
    }).toList();

    if (busca.isEmpty) {
      return widget.moduleItems.where((item) {
        return _podeAcessar(item.pageKey);
      }).toList();
    }

    return todos.where((item) {
      final texto = _normalizar(
        '${item.title} ${item.subtitle} ${item.type} ${item.keywords}',
      );

      return texto.contains(busca);
    }).toList();
  }

  void _selecionar(_GlobalSearchResult item) {
    if (!_podeAcessar(item.pageKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para acessar esta área.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    if (item.pageKey == widget.currentPage) {
      return;
    }

    widget.onNavigate(item.pageKey);
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Material(
            color: VitalisColors.offWhite,
            elevation: 10,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: VitalisColors.verdeEsmeralda.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: VitalisColors.verdeEsmeralda,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pesquisa global',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: VitalisColors.azulMarinhoProfundo,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Busque clientes, serviços, mensalidades e módulos.',
                              style: TextStyle(color: VitalisColors.cinzaMedio),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Pesquisar no sistema',
                      hintText: 'Ex.: Maria, natação, CPF, telefone...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _busca.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: _controller.clear,
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const LinearProgressIndicator(
                      color: VitalisColors.verdeEsmeralda,
                    ),
                  if (_loading) const SizedBox(height: 10),
                  Expanded(
                    child: filtrados.isEmpty
                        ? Center(
                            child: Text(
                              _loading
                                  ? 'Carregando dados para pesquisa...'
                                  : 'Nenhum resultado encontrado.',
                              style: const TextStyle(
                                color: VitalisColors.cinzaMedio,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = filtrados[index];
                              final ativo = item.pageKey == widget.currentPage;

                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _selecionar(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: ativo
                                            ? VitalisColors.verdeEsmeralda
                                                  .withOpacity(0.35)
                                            : VitalisColors.borda,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: _corTipo(
                                              item.type,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            item.icon,
                                            color: _corTipo(item.type),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      item.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: VitalisColors
                                                            .azulMarinhoProfundo,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _SearchTypeChip(
                                                    label: item.type,
                                                    color: _corTipo(item.type),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color:
                                                      VitalisColors.cinzaMedio,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (ativo)
                                          const _SearchStatusChip(
                                            label: 'Atual',
                                          )
                                        else
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                            color: VitalisColors.cinzaMedio,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _corTipo(String type) {
    switch (type.toLowerCase()) {
      case 'cliente':
        return VitalisColors.verdeEsmeralda;
      case 'serviço':
      case 'servico':
        return VitalisColors.info;
      case 'mensalidade':
        return VitalisColors.cobreQueimado;
      default:
        return VitalisColors.azulMarinhoProfundo;
    }
  }
}

class _SearchTypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SearchTypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchStatusChip extends StatelessWidget {
  final String label;

  const _SearchStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: VitalisColors.verdeEsmeralda.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VitalisColors.verdeEsmeralda,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GlobalSearchResult {
  final String pageKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final String type;
  final String keywords;

  const _GlobalSearchResult({
    required this.pageKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.keywords,
  });
}
