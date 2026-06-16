import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../services/financeiro_service.dart';
import '../services/mensalidade_service.dart';
import '../widgets/app_shell.dart';

class DashboardPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const DashboardPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'admin',
    this.embedded = false,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _mostrarValores = false;
  final ScrollController _kpiScrollController = ScrollController();
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void dispose() {
    _kpiScrollController.dispose();
    super.dispose();
  }

  Future<void> _rolarIndicadores(double deslocamento) async {
    if (!_kpiScrollController.hasClients) return;

    final destino = (_kpiScrollController.offset + deslocamento).clamp(
      0.0,
      _kpiScrollController.position.maxScrollExtent,
    );

    await _kpiScrollController.animateTo(
      destino,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _valorOuOculto(double valor) {
    return _mostrarValores ? _formatarValor(valor) : '••••••';
  }

  String _mesTexto(DateTime data) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${meses[data.month - 1]} de ${data.year}';
  }

  bool _isMesSelecionado(dynamic timestamp) {
    if (timestamp is! Timestamp) return false;

    final data = timestamp.toDate();
    return data.month == _mesSelecionado.month &&
        data.year == _mesSelecionado.year;
  }

  void _alterarMes(int meses) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + meses,
      );
    });
  }

  Future<void> _selecionarMes() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecione uma data do mês desejado',
    );

    if (selecionada == null || !mounted) return;

    setState(() {
      _mesSelecionado = DateTime(selecionada.year, selecionada.month);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _movimentacoesDoMesSelecionado() {
    return FinanceiroService.listarMovimentacoesPorPeriodo(
      dataInicial: DateTime(_mesSelecionado.year, _mesSelecionado.month, 1),
      dataFinal: DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0),
    );
  }

  bool _mensalidadeVencida(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();

    if (status == 'pago') return false;

    final vencimento = data['vencimento'];
    if (vencimento is! Timestamp) return false;

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    final venc = vencimento.toDate();
    final vencSemHora = DateTime(venc.year, venc.month, venc.day);

    return hojeSemHora.isAfter(vencSemHora);
  }

  bool _mensalidadeVencendo(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();

    if (status == 'pago') return false;

    final vencimento = data['vencimento'];
    if (vencimento is! Timestamp) return false;

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    final venc = vencimento.toDate();
    final vencSemHora = DateTime(venc.year, venc.month, venc.day);

    final dias = vencSemHora.difference(hojeSemHora).inDays;

    return dias >= 0 && dias <= 3;
  }

  bool _estaEmAbertoAteMesSelecionado(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final inicioProximoMes = DateTime(
      _mesSelecionado.year,
      _mesSelecionado.month + 1,
      1,
    );

    if (status == 'pago') {
      final dataPagamento = data['dataPagamento'];
      if (dataPagamento is! Timestamp ||
          dataPagamento.toDate().isBefore(inicioProximoMes)) {
        return false;
      }
    }

    final referencia = data['vencimento'] is Timestamp
        ? data['vencimento'] as Timestamp
        : data['dataServico'] is Timestamp
        ? data['dataServico'] as Timestamp
        : null;

    if (referencia == null) return true;

    return referencia.toDate().isBefore(inicioProximoMes);
  }

  List<Widget> _buildActions() {
    return [
      IconButton(
        tooltip: _mostrarValores ? 'Ocultar valores' : 'Mostrar valores',
        onPressed: () {
          setState(() {
            _mostrarValores = !_mostrarValores;
          });
        },
        icon: Icon(
          _mostrarValores
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          color: Colors.white,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Dashboard',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'dashboard',
      actions: _buildActions(),
      child: content,
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ClienteService.listarClientes(),
        builder: (context, clientesSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: MensalidadeService.listarMensalidades(),
            builder: (context, mensalidadesSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _movimentacoesDoMesSelecionado(),
                builder: (context, financeiroSnapshot) {
                  final carregando =
                      clientesSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      mensalidadesSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      financeiroSnapshot.connectionState ==
                          ConnectionState.waiting;

                  if (carregando &&
                      !clientesSnapshot.hasData &&
                      !mensalidadesSnapshot.hasData &&
                      !financeiroSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: VitalisColors.verdeEsmeralda,
                      ),
                    );
                  }

                  if (clientesSnapshot.hasError ||
                      mensalidadesSnapshot.hasError ||
                      financeiroSnapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar dashboard.',
                        style: TextStyle(
                          color: VitalisColors.azulMarinhoProfundo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  final clientesDocs = clientesSnapshot.data?.docs ?? [];
                  final mensalidadesDocs =
                      mensalidadesSnapshot.data?.docs ?? [];
                  final financeiroDocs = financeiroSnapshot.data?.docs ?? [];

                  final totalClientes = clientesDocs.length;

                  final clientesAtivos = clientesDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    return status == 'ativo';
                  }).length;

                  final clientesInativos = clientesDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    return status == 'inativo';
                  }).length;

                  final clientesNatacao = clientesDocs.where((doc) {
                    return doc.data()['clienteNatacao'] == true;
                  }).length;

                  final mensalidadesPagas = mensalidadesDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    return status == 'pago';
                  }).length;

                  final mensalidadesPendentes = mensalidadesDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    return status != 'pago';
                  }).length;

                  final mensalidadesVencidas = mensalidadesDocs.where((doc) {
                    return _mensalidadeVencida(doc.data());
                  }).length;

                  final mensalidadesVencendo = mensalidadesDocs.where((doc) {
                    return _mensalidadeVencendo(doc.data());
                  }).length;

                  double totalEmAberto = 0.0;
                  int quantidadeEmAberto = 0;
                  double totalPrevistoMes = 0.0;

                  final servicosContagem = <String, int>{};

                  for (final doc in mensalidadesDocs) {
                    final data = doc.data();
                    final valor = _toDouble(
                      data['valorFinal'] ?? data['valorBase'],
                    );
                    final nomeServico = (data['nomeServico'] ?? 'Sem serviço')
                        .toString();

                    servicosContagem[nomeServico] =
                        (servicosContagem[nomeServico] ?? 0) + 1;

                    if (_estaEmAbertoAteMesSelecionado(data)) {
                      totalEmAberto += valor;
                      quantidadeEmAberto++;
                    }

                    final vencimento = data['vencimento'];
                    final dataServico = data['dataServico'];

                    if (_isMesSelecionado(vencimento) ||
                        _isMesSelecionado(dataServico)) {
                      totalPrevistoMes += valor;
                    }
                  }

                  double entradasMes = 0.0;
                  double saidasMes = 0.0;
                  int qtdEntradasMes = 0;
                  int qtdSaidasMes = 0;

                  for (final doc in financeiroDocs) {
                    final data = doc.data();

                    if (!_isMesSelecionado(data['createdAt'])) continue;

                    final tipo = (data['tipo'] ?? '').toString();
                    final valor = _toDouble(data['valor']);

                    if (tipo == 'entrada') {
                      entradasMes += valor;
                      qtdEntradasMes++;
                    } else if (tipo == 'saida') {
                      saidasMes += valor;
                      qtdSaidasMes++;
                    }
                  }

                  final saldoMes = entradasMes - saidasMes;
                  final lucroPrevistoMes = totalPrevistoMes - saidasMes;
                  final ticketMedio = qtdEntradasMes == 0
                      ? 0.0
                      : entradasMes / qtdEntradasMes;
                  final margem = entradasMes <= 0
                      ? 0.0
                      : (saldoMes / entradasMes) * 100;

                  final servicosOrdenados = servicosContagem.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  final topServicos = servicosOrdenados.take(5).toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isWide = width >= 980;

                      final kpiCards = [
                        _MetricCard(
                          title: 'Receita do mês',
                          value: _valorOuOculto(entradasMes),
                          subtitle: '$qtdEntradasMes entrada(s)',
                          icon: Icons.trending_up_rounded,
                          color: VitalisColors.sucesso,
                        ),
                        _MetricCard(
                          title: 'Saídas do mês',
                          value: _valorOuOculto(saidasMes),
                          subtitle: '$qtdSaidasMes saída(s)',
                          icon: Icons.trending_down_rounded,
                          color: VitalisColors.erro,
                        ),
                        _MetricCard(
                          title: 'Resultado',
                          value: _valorOuOculto(saldoMes),
                          subtitle: _mesTexto(_mesSelecionado),
                          icon: Icons.account_balance_wallet_rounded,
                          color: saldoMes >= 0
                              ? VitalisColors.sucesso
                              : VitalisColors.erro,
                        ),
                        _MetricCard(
                          title: 'Lucro previsto',
                          value: _valorOuOculto(lucroPrevistoMes),
                          subtitle: 'Previsto menos saídas',
                          icon: Icons.auto_graph_rounded,
                          color: lucroPrevistoMes >= 0
                              ? VitalisColors.sucesso
                              : VitalisColors.erro,
                        ),
                        _MetricCard(
                          title: 'Em aberto',
                          value: _valorOuOculto(totalEmAberto),
                          subtitle:
                              '$quantidadeEmAberto até ${_mesTexto(_mesSelecionado)}',
                          icon: Icons.pending_actions_rounded,
                          color: VitalisColors.alerta,
                        ),
                        _MetricCard(
                          title: 'Previsto no mês',
                          value: _valorOuOculto(totalPrevistoMes),
                          subtitle: 'Recebido + aberto no mês',
                          icon: Icons.calendar_month_rounded,
                          color: VitalisColors.info,
                        ),
                      ];

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DashboardHeader(
                              mesAtual: _mesTexto(_mesSelecionado),
                              resultado: _valorOuOculto(saldoMes),
                              positivo: saldoMes >= 0,
                              onToggleValues: () {
                                setState(() {
                                  _mostrarValores = !_mostrarValores;
                                });
                              },
                              mostrarValores: _mostrarValores,
                            ),
                            const SizedBox(height: 12),
                            _FiltroMesDashboard(
                              mes: _mesTexto(_mesSelecionado),
                              onAnterior: () => _alterarMes(-1),
                              onProximo: () => _alterarMes(1),
                              onSelecionar: _selecionarMes,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 92,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Indicadores anteriores',
                                    onPressed: () => _rolarIndicadores(-600),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      controller: _kpiScrollController,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: kpiCards.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (_, index) =>
                                          kpiCards[index],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Próximos indicadores',
                                    onPressed: () => _rolarIndicadores(600),
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _FinancialAnalysisCard(
                                      entradas: entradasMes,
                                      saidas: saidasMes,
                                      aberto: totalEmAberto,
                                      previsto: totalPrevistoMes,
                                      lucroPrevisto: lucroPrevistoMes,
                                      formatarValor: _valorOuOculto,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 5,
                                    child: _BusinessHealthCard(
                                      clientesAtivos: clientesAtivos,
                                      clientesInativos: clientesInativos,
                                      totalClientes: totalClientes,
                                      clientesNatacao: clientesNatacao,
                                      pagas: mensalidadesPagas,
                                      pendentes: mensalidadesPendentes,
                                      vencidas: mensalidadesVencidas,
                                      vencendo: mensalidadesVencendo,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _FinancialAnalysisCard(
                                    entradas: entradasMes,
                                    saidas: saidasMes,
                                    aberto: totalEmAberto,
                                    previsto: totalPrevistoMes,
                                    lucroPrevisto: lucroPrevistoMes,
                                    formatarValor: _valorOuOculto,
                                  ),
                                  const SizedBox(height: 14),
                                  _BusinessHealthCard(
                                    clientesAtivos: clientesAtivos,
                                    clientesInativos: clientesInativos,
                                    totalClientes: totalClientes,
                                    clientesNatacao: clientesNatacao,
                                    pagas: mensalidadesPagas,
                                    pendentes: mensalidadesPendentes,
                                    vencidas: mensalidadesVencidas,
                                    vencendo: mensalidadesVencendo,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _IndicatorsCard(
                                      margem: margem,
                                      ticketMedio: _valorOuOculto(ticketMedio),
                                      entradas: qtdEntradasMes,
                                      saidas: qtdSaidasMes,
                                      mensalidadesVencidas:
                                          mensalidadesVencidas,
                                      mensalidadesVencendo:
                                          mensalidadesVencendo,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _TopServicesCard(
                                      servicos: topServicos,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _IndicatorsCard(
                                    margem: margem,
                                    ticketMedio: _valorOuOculto(ticketMedio),
                                    entradas: qtdEntradasMes,
                                    saidas: qtdSaidasMes,
                                    mensalidadesVencidas: mensalidadesVencidas,
                                    mensalidadesVencendo: mensalidadesVencendo,
                                  ),
                                  const SizedBox(height: 14),
                                  _TopServicesCard(servicos: topServicos),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FiltroMesDashboard extends StatelessWidget {
  final String mes;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final VoidCallback onSelecionar;

  const _FiltroMesDashboard({
    required this.mes,
    required this.onAnterior,
    required this.onProximo,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Período financeiro',
          style: TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        InkWell(
          onTap: onSelecionar,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VitalisColors.borda),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: VitalisColors.verdeEsmeralda,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    mes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitalisColors.azulMarinhoProfundo,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: onProximo,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String mesAtual;
  final String resultado;
  final bool positivo;
  final bool mostrarValores;
  final VoidCallback onToggleValues;

  const _DashboardHeader({
    required this.mesAtual,
    required this.resultado,
    required this.positivo,
    required this.mostrarValores,
    required this.onToggleValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VitalisColors.azulMarinhoProfundo,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: VitalisColors.sombra,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard analítico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Indicadores financeiros, clientes e mensalidades.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  positivo
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: positivo
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mesAtual,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      resultado,
                      style: TextStyle(
                        color: positivo
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFECACA),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: mostrarValores ? 'Ocultar valores' : 'Mostrar valores',
            onPressed: onToggleValues,
            icon: Icon(
              mostrarValores
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
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
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitalisColors.azulMarinhoProfundo,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitalisColors.cinzaMedio,
                    fontSize: 11.5,
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

class _FinancialAnalysisCard extends StatelessWidget {
  final double entradas;
  final double saidas;
  final double aberto;
  final double previsto;
  final double lucroPrevisto;
  final String Function(double) formatarValor;

  const _FinancialAnalysisCard({
    required this.entradas,
    required this.saidas,
    required this.aberto,
    required this.previsto,
    required this.lucroPrevisto,
    required this.formatarValor,
  });

  @override
  Widget build(BuildContext context) {
    final maior = [
      entradas.abs(),
      saidas.abs(),
      aberto.abs(),
      previsto.abs(),
      lucroPrevisto.abs(),
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Análise financeira',
              subtitle: 'Comparativo do mês e valores em aberto.',
            ),
            const SizedBox(height: 16),
            _HorizontalMetricBar(
              label: 'Entradas',
              value: entradas,
              maxValue: maior,
              color: VitalisColors.sucesso,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalMetricBar(
              label: 'Saídas',
              value: saidas,
              maxValue: maior,
              color: VitalisColors.erro,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalMetricBar(
              label: 'Em aberto',
              value: aberto,
              maxValue: maior,
              color: VitalisColors.cobreQueimado,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalMetricBar(
              label: 'Previsto no mês',
              value: previsto,
              maxValue: maior,
              color: VitalisColors.info,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalMetricBar(
              label: 'Lucro previsto',
              value: lucroPrevisto,
              maxValue: maior,
              color: lucroPrevisto >= 0
                  ? VitalisColors.sucesso
                  : VitalisColors.erro,
              formatarValor: formatarValor,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessHealthCard extends StatelessWidget {
  final int clientesAtivos;
  final int clientesInativos;
  final int totalClientes;
  final int clientesNatacao;
  final int pagas;
  final int pendentes;
  final int vencidas;
  final int vencendo;

  const _BusinessHealthCard({
    required this.clientesAtivos,
    required this.clientesInativos,
    required this.totalClientes,
    required this.clientesNatacao,
    required this.pagas,
    required this.pendentes,
    required this.vencidas,
    required this.vencendo,
  });

  @override
  Widget build(BuildContext context) {
    final totalMensalidades = pagas + pendentes;
    final totalSeguro = totalMensalidades == 0 ? 1 : totalMensalidades;

    final percentualPagas = pagas / totalSeguro;
    final percentualPendentes = pendentes / totalSeguro;
    final percentualVencidas = vencidas / totalSeguro;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.health_and_safety_rounded,
              title: 'Saúde do negócio',
              subtitle: 'Clientes e mensalidades em uma visão única.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      pagas: percentualPagas,
                      pendentes: percentualPendentes,
                      vencidas: percentualVencidas,
                    ),
                    child: Center(
                      child: Text(
                        '$totalMensalidades',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _LegendLine(
                        color: VitalisColors.sucesso,
                        label: 'Pagas',
                        value: pagas.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLine(
                        color: VitalisColors.alerta,
                        label: 'Pendentes',
                        value: pendentes.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLine(
                        color: VitalisColors.erro,
                        label: 'Vencidas',
                        value: vencidas.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLine(
                        color: VitalisColors.cobreQueimado,
                        label: 'Vencendo',
                        value: vencendo.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallInfoChip(
                  label: '$clientesAtivos ativo(s)',
                  color: VitalisColors.sucesso,
                ),
                _SmallInfoChip(
                  label: '$clientesInativos inativo(s)',
                  color: VitalisColors.cinzaMedio,
                ),
                _SmallInfoChip(
                  label: '$clientesNatacao natação',
                  color: VitalisColors.info,
                ),
                _SmallInfoChip(
                  label: '$totalClientes cliente(s)',
                  color: VitalisColors.azulMarinhoProfundo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorsCard extends StatelessWidget {
  final double margem;
  final String ticketMedio;
  final int entradas;
  final int saidas;
  final int mensalidadesVencidas;
  final int mensalidadesVencendo;

  const _IndicatorsCard({
    required this.margem,
    required this.ticketMedio,
    required this.entradas,
    required this.saidas,
    required this.mensalidadesVencidas,
    required this.mensalidadesVencendo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.analytics_rounded,
              title: 'Indicadores gerenciais',
              subtitle: 'Leitura rápida da operação atual.',
            ),
            const SizedBox(height: 14),
            _IndicatorLine(
              label: 'Entradas no mês',
              value: entradas.toString(),
            ),
            _IndicatorLine(label: 'Saídas no mês', value: saidas.toString()),
            _IndicatorLine(label: 'Ticket médio', value: ticketMedio),
            _IndicatorLine(
              label: 'Margem estimada',
              value: '${margem.toStringAsFixed(1).replaceAll('.', ',')}%',
              valueColor: margem >= 0
                  ? VitalisColors.sucesso
                  : VitalisColors.erro,
            ),
            _IndicatorLine(
              label: 'Mensalidades vencidas',
              value: mensalidadesVencidas.toString(),
              valueColor: mensalidadesVencidas > 0
                  ? VitalisColors.erro
                  : VitalisColors.sucesso,
            ),
            _IndicatorLine(
              label: 'Vencendo em até 3 dias',
              value: mensalidadesVencendo.toString(),
              valueColor: mensalidadesVencendo > 0
                  ? VitalisColors.alerta
                  : VitalisColors.sucesso,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopServicesCard extends StatelessWidget {
  final List<MapEntry<String, int>> servicos;

  const _TopServicesCard({required this.servicos});

  @override
  Widget build(BuildContext context) {
    final maior = servicos.isEmpty ? 1 : servicos.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              icon: Icons.star_rounded,
              title: 'Serviços mais usados',
              subtitle: 'Baseado nos lançamentos recentes.',
            ),
            const SizedBox(height: 14),
            if (servicos.isEmpty)
              const Text(
                'Nenhum serviço encontrado nos lançamentos recentes.',
                style: TextStyle(
                  color: VitalisColors.cinzaMedio,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              ...servicos.map((servico) {
                final percentual = servico.value / maior;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              servico.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VitalisColors.azulMarinhoProfundo,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            servico.value.toString(),
                            style: const TextStyle(
                              color: VitalisColors.cobreQueimado,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 9,
                          color: VitalisColors.cinzaClaro,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: percentual.clamp(0.06, 1.0),
                              child: Container(
                                color: VitalisColors.cobreQueimado,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: VitalisColors.verdeEsmeralda.withOpacity(0.12),
          child: Icon(icon, color: VitalisColors.cobreQueimado, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitalisColors.azulMarinhoProfundo,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitalisColors.cinzaMedio,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HorizontalMetricBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String Function(double) formatarValor;

  const _HorizontalMetricBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.formatarValor,
  });

  @override
  Widget build(BuildContext context) {
    final percentual = maxValue <= 0 ? 0.0 : (value.abs() / maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VitalisColors.azulMarinhoProfundo,
                ),
              ),
            ),
            Text(
              formatarValor(value),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 10,
            color: VitalisColors.cinzaClaro,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: percentual.clamp(0.04, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VitalisColors.cinzaEscuro,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallInfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IndicatorLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _IndicatorLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: VitalisColors.cinzaEscuro,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? VitalisColors.azulMarinhoProfundo,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double pagas;
  final double pendentes;
  final double vencidas;

  const _DonutChartPainter({
    required this.pagas,
    required this.pendentes,
    required this.vencidas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 15.0;
    final rect = Offset.zero & size;

    final backgroundPaint = Paint()
      ..color = VitalisColors.cinzaClaro
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final pagasPaint = Paint()
      ..color = VitalisColors.sucesso
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final pendentesPaint = Paint()
      ..color = VitalisColors.alerta
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final vencidasPaint = Paint()
      ..color = VitalisColors.erro
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.5708,
      6.2831,
      false,
      backgroundPaint,
    );

    double start = -1.5708;

    final pagasSweep = pagas * 6.2831;
    final pendentesSweep = pendentes * 6.2831;
    final vencidasSweep = vencidas * 6.2831;

    if (pagasSweep > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        start,
        pagasSweep,
        false,
        pagasPaint,
      );
      start += pagasSweep;
    }

    if (pendentesSweep > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        start,
        pendentesSweep,
        false,
        pendentesPaint,
      );
      start += pendentesSweep;
    }

    if (vencidasSweep > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        start,
        vencidasSweep,
        false,
        vencidasPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.pagas != pagas ||
        oldDelegate.pendentes != pendentes ||
        oldDelegate.vencidas != vencidas;
  }
}
