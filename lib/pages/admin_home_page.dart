import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../services/financeiro_service.dart';
import '../services/mensalidade_service.dart';
import '../widgets/app_shell.dart';
import 'aniversariantes_page.dart';
import 'caixa_page.dart';
import 'clientes_page.dart';
import 'cobrancas_page.dart';
import 'configuracoes_lembrete_page.dart';
import 'dashboard_page.dart';
import 'financeiro_page.dart';
import 'mensalidades_page.dart';
import 'pdfs_page.dart';
import 'servicos_page.dart';

class AdminHomePage extends StatefulWidget {
  final String nome;
  final String email;

  const AdminHomePage({super.key, required this.nome, required this.email});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _mostrarValores = false;
  String _currentPage = 'home';

  void _onNavigate(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  String get _tituloAtual {
    switch (_currentPage) {
      case 'dashboard':
        return 'Dashboard';
      case 'clientes':
        return 'Clientes';
      case 'servicos':
        return 'Serviços';
      case 'mensalidades':
        return 'Mensalidades';
      case 'financeiro':
        return 'Financeiro';
      case 'cobrancas':
        return 'Cobranças';
      case 'aniversariantes':
        return 'Aniversariantes';
      case 'pdfs':
        return 'PDFs';
      case 'caixa':
        return 'Caixa';
      case 'lembretes':
      case 'configuracoes':
        return 'Configurações de Lembrete';
      case 'home':
      default:
        return 'Painel administrativo';
    }
  }

  List<Widget>? _actionsAtual() {
    if (_currentPage != 'home') return null;

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

  Widget? _floatingActionButtonAtual() {
    switch (_currentPage) {
      case 'clientes':
        return FloatingActionButton.extended(
          backgroundColor: VitalisColors.verdeEsmeralda,
          foregroundColor: Colors.white,
          onPressed: () async {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const CadastroClienteDialog(),
            );
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Novo cliente'),
        );

      case 'servicos':
        return FloatingActionButton.extended(
          backgroundColor: VitalisColors.verdeEsmeralda,
          foregroundColor: Colors.white,
          onPressed: () async {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const CadastroServicoDialog(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Novo serviço'),
        );

      case 'mensalidades':
        return FloatingActionButton.extended(
          backgroundColor: VitalisColors.verdeEsmeralda,
          foregroundColor: Colors.white,
          onPressed: () async {
            await showDialog(
              context: context,
              barrierDismissible: false,
              useRootNavigator: true,
              builder: (_) => const CadastroMensalidadeDialog(role: 'admin'),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Novo lançamento'),
        );

      case 'financeiro':
        return FloatingActionButton.extended(
          backgroundColor: VitalisColors.verdeEsmeralda,
          foregroundColor: Colors.white,
          onPressed: () async {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const NovaMovimentacaoDialog(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Nova movimentação'),
        );

      default:
        return null;
    }
  }

  Widget _conteudoAtual() {
    final nome = widget.nome;
    final email = widget.email;

    switch (_currentPage) {
      case 'dashboard':
        return DashboardPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'clientes':
        return ClientesPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'servicos':
        return ServicosPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'mensalidades':
        return MensalidadesPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'financeiro':
        return FinanceiroPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'cobrancas':
        return CobrancasPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'aniversariantes':
        return AniversariantesPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'pdfs':
        return PdfsPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'caixa':
        return CaixaPage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'lembretes':
      case 'configuracoes':
        return ConfiguracoesLembretePage(
          nome: nome,
          email: email,
          role: 'admin',
          embedded: true,
        );

      case 'home':
      default:
        return _buildHomeContent();
    }
  }

  String _saudacao() {
    final hora = DateTime.now().hour;

    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _mesAtualTexto() {
    final agora = DateTime.now();

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

    return '${meses[agora.month - 1]} de ${agora.year}';
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

  bool _isMesAtual(dynamic timestamp) {
    if (timestamp is! Timestamp) return false;

    final data = timestamp.toDate();
    final agora = DateTime.now();

    return data.month == agora.month && data.year == agora.year;
  }

  bool _clienteIncompleto(Map<String, dynamic> data) {
    bool vazio(String campo) {
      return (data[campo] ?? '').toString().trim().isEmpty;
    }

    final camposObrigatorios = [
      'nome',
      'telefone',
      'cpf',
      'categoria',
      'status',
      'cep',
      'logradouro',
      'numero',
      'bairro',
      'cidade',
      'uf',
    ];

    for (final campo in camposObrigatorios) {
      if (vazio(campo)) return true;
    }

    final clienteNatacao = data['clienteNatacao'] == true;

    if (clienteNatacao) {
      if (vazio('nomeCrianca')) return true;
      if (data['dataNascimentoCrianca'] is! Timestamp) return true;
    }

    return false;
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

  bool _estaEmAbertoAteMesAtual(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'pago') return false;

    final referencia = data['vencimento'] is Timestamp
        ? data['vencimento'] as Timestamp
        : data['dataServico'] is Timestamp
        ? data['dataServico'] as Timestamp
        : null;

    if (referencia == null) return true;

    final agora = DateTime.now();
    final inicioProximoMes = DateTime(agora.year, agora.month + 1, 1);
    return referencia.toDate().isBefore(inicioProximoMes);
  }

  String _formatarDataCurta(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Sem data';

    final data = timestamp.toDate();
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _tituloAtual,
      nome: widget.nome,
      email: widget.email,
      role: 'admin',
      currentPage: _currentPage,
      onNavigate: _onNavigate,
      actions: _actionsAtual(),
      floatingActionButton: _floatingActionButtonAtual(),
      child: _conteudoAtual(),
    );
  }

  Widget _buildHomeContent() {
    final nome = widget.nome;
    final nomeExibicao = nome.trim().isEmpty ? 'Administrador' : nome;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ClienteService.listarClientes(),
      builder: (context, clientesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: MensalidadeService.listarMensalidades(),
          builder: (context, mensalidadesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FinanceiroService.listarMovimentacoes(),
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

                final clientesDocs = clientesSnapshot.data?.docs ?? [];
                final mensalidadesDocs = mensalidadesSnapshot.data?.docs ?? [];
                final financeiroDocs = financeiroSnapshot.data?.docs ?? [];

                final totalClientes = clientesDocs.length;

                final clientesAtivos = clientesDocs.where((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  return status == 'ativo';
                }).length;

                final clientesIncompletos = clientesDocs.where((doc) {
                  return _clienteIncompleto(doc.data());
                }).length;

                final mensalidadesPagas = mensalidadesDocs.where((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  return status == 'pago';
                }).length;

                final mensalidadesPendentes = mensalidadesDocs.where((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? '')
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

                for (final doc in mensalidadesDocs) {
                  final data = doc.data();

                  if (_estaEmAbertoAteMesAtual(data)) {
                    totalEmAberto += _toDouble(
                      data['valorFinal'] ?? data['valorBase'],
                    );
                    quantidadeEmAberto++;
                  }
                }

                double entradasMes = 0.0;
                double saidasMes = 0.0;

                for (final doc in financeiroDocs) {
                  final data = doc.data();

                  if (!_isMesAtual(data['createdAt'])) continue;

                  final tipo = (data['tipo'] ?? '').toString();
                  final valor = _toDouble(data['valor']);

                  if (tipo == 'entrada') {
                    entradasMes += valor;
                  } else if (tipo == 'saida') {
                    saidasMes += valor;
                  }
                }

                final saldoMes = entradasMes - saidasMes;

                final recentes = financeiroDocs.take(5).toList();

                final alertas = <_AlertItem>[
                  if (clientesIncompletos > 0)
                    _AlertItem(
                      icon: Icons.assignment_late_rounded,
                      color: VitalisColors.alerta,
                      title: '$clientesIncompletos cadastro(s) incompleto(s)',
                      subtitle: 'Revise os dados dos clientes cadastrados.',
                      onTap: () => _onNavigate('clientes'),
                    ),
                  if (mensalidadesVencidas > 0)
                    _AlertItem(
                      icon: Icons.warning_amber_rounded,
                      color: VitalisColors.erro,
                      title: '$mensalidadesVencidas mensalidade(s) vencida(s)',
                      subtitle: 'Acesse cobranças ou mensalidades para agir.',
                      onTap: () => _onNavigate('cobrancas'),
                    ),
                  if (mensalidadesVencendo > 0)
                    _AlertItem(
                      icon: Icons.schedule_rounded,
                      color: VitalisColors.cobreQueimado,
                      title: '$mensalidadesVencendo vencendo em até 3 dias',
                      subtitle: 'Acompanhe os próximos vencimentos.',
                      onTap: () => _onNavigate('mensalidades'),
                    ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    final quickColumns = width >= 1400
                        ? 5
                        : width >= 1100
                        ? 4
                        : width >= 760
                        ? 3
                        : width >= 520
                        ? 2
                        : 1;

                    final isWide = width >= 980;

                    final resumoCards = [
                      _CompactMetricCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Clientes ativos',
                        value: clientesAtivos.toString(),
                        subtitle: '$totalClientes no total',
                        color: VitalisColors.verdeEsmeralda,
                        onTap: () => _onNavigate('clientes'),
                      ),
                      _CompactMetricCard(
                        icon: Icons.assignment_late_rounded,
                        title: 'Incompletos',
                        value: clientesIncompletos.toString(),
                        subtitle: 'Cadastros para revisar',
                        color: clientesIncompletos > 0
                            ? VitalisColors.alerta
                            : VitalisColors.sucesso,
                        onTap: () => _onNavigate('clientes'),
                      ),
                      _CompactMetricCard(
                        icon: Icons.event_note_rounded,
                        title: 'Pendentes',
                        value: mensalidadesPendentes.toString(),
                        subtitle: '$mensalidadesVencidas vencida(s)',
                        color: mensalidadesVencidas > 0
                            ? VitalisColors.erro
                            : VitalisColors.alerta,
                        onTap: () => _onNavigate('mensalidades'),
                      ),
                      _CompactMetricCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Em aberto',
                        value: _valorOuOculto(totalEmAberto),
                        subtitle: '$quantidadeEmAberto até o mês atual',
                        color: VitalisColors.cobreQueimado,
                        onTap: () => _onNavigate('mensalidades'),
                      ),
                      _CompactMetricCard(
                        icon: Icons.show_chart_rounded,
                        title: 'Saldo do mês',
                        value: _valorOuOculto(saldoMes),
                        subtitle: _mesAtualTexto(),
                        color: saldoMes >= 0
                            ? VitalisColors.sucesso
                            : VitalisColors.erro,
                        onTap: () => _onNavigate('financeiro'),
                      ),
                    ];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExecutiveHeaderCompact(
                            saudacao: _saudacao(),
                            nome: nomeExibicao,
                            mesAtual: _mesAtualTexto(),
                            saldoMes: _valorOuOculto(saldoMes),
                            saldoPositivo: saldoMes >= 0,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 78,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: resumoCards.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, index) => resumoCards[index],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _SectionHeaderCompact(
                            title: 'Acesso rápido',
                            subtitle: 'Abra rapidamente os módulos principais.',
                          ),
                          const SizedBox(height: 12),
                          GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: quickColumns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 108,
                                ),
                            children: [
                              _ModuleCardCompact(
                                icon: Icons.dashboard_rounded,
                                title: 'Dashboard',
                                subtitle: 'Indicadores gerais',
                                onTap: () => _onNavigate('dashboard'),
                              ),
                              _ModuleCardCompact(
                                icon: Icons.people_alt_rounded,
                                title: 'Clientes',
                                subtitle: 'Cadastros e histórico',
                                onTap: () => _onNavigate('clientes'),
                              ),
                              _ModuleCardCompact(
                                icon: Icons.event_note_rounded,
                                title: 'Mensalidades',
                                subtitle: 'Cobranças e vencimentos',
                                onTap: () => _onNavigate('mensalidades'),
                              ),
                              _ModuleCardCompact(
                                icon: Icons.attach_money_rounded,
                                title: 'Financeiro',
                                subtitle: 'Entradas e saídas',
                                onTap: () => _onNavigate('financeiro'),
                              ),
                              _ModuleCardCompact(
                                icon: Icons.design_services_rounded,
                                title: 'Serviços',
                                subtitle: 'Planos e valores',
                                onTap: () => _onNavigate('servicos'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _FinancialChartCardCompact(
                                    entradas: entradasMes,
                                    saidas: saidasMes,
                                    aberto: totalEmAberto,
                                    formatarValor: _valorOuOculto,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 5,
                                  child: _StatusAndAlertsColumn(
                                    pagas: mensalidadesPagas,
                                    pendentes: mensalidadesPendentes,
                                    vencidas: mensalidadesVencidas,
                                    vencendo: mensalidadesVencendo,
                                    alertas: alertas,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _FinancialChartCardCompact(
                                  entradas: entradasMes,
                                  saidas: saidasMes,
                                  aberto: totalEmAberto,
                                  formatarValor: _valorOuOculto,
                                ),
                                const SizedBox(height: 14),
                                _StatusAndAlertsColumn(
                                  pagas: mensalidadesPagas,
                                  pendentes: mensalidadesPendentes,
                                  vencidas: mensalidadesVencidas,
                                  vencendo: mensalidadesVencendo,
                                  alertas: alertas,
                                ),
                              ],
                            ),
                          const SizedBox(height: 14),
                          _RecentMovementsCard(
                            movimentos: recentes,
                            formatarValor: _valorOuOculto,
                            formatarData: _formatarDataCurta,
                            toDouble: _toDouble,
                            onTapVerTodos: () => _onNavigate('financeiro'),
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
    );
  }
}

class _ExecutiveHeaderCompact extends StatelessWidget {
  final String saudacao;
  final String nome;
  final String mesAtual;
  final String saldoMes;
  final bool saldoPositivo;

  const _ExecutiveHeaderCompact({
    required this.saudacao,
    required this.nome,
    required this.mesAtual,
    required this.saldoMes,
    required this.saldoPositivo,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          final title = Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$saudacao, $nome',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Visão rápida da operação em tempo real.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          );

          final saldoCard = Container(
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
                  saldoPositivo
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: saldoPositivo
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultado do mês',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      saldoMes,
                      style: TextStyle(
                        color: saldoPositivo
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFECACA),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mesAtual,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                saldoCard,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), saldoCard],
          );
        },
      ),
    );
  }
}

class _CompactMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CompactMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}

class _SectionHeaderCompact extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeaderCompact({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: VitalisColors.azulMarinhoProfundo,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: VitalisColors.cinzaMedio)),
      ],
    );
  }
}

class _ModuleCardCompact extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCardCompact({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VitalisColors.borda),
            boxShadow: const [
              BoxShadow(
                color: VitalisColors.sombra,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VitalisColors.verdeEsmeralda.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: VitalisColors.cobreQueimado),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: VitalisColors.cinzaMedio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialChartCardCompact extends StatelessWidget {
  final double entradas;
  final double saidas;
  final double aberto;
  final String Function(double) formatarValor;

  const _FinancialChartCardCompact({
    required this.entradas,
    required this.saidas,
    required this.aberto,
    required this.formatarValor,
  });

  @override
  Widget build(BuildContext context) {
    final maior = [
      entradas.abs(),
      saidas.abs(),
      aberto.abs(),
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ChartHeaderCompact(
              icon: Icons.bar_chart_rounded,
              title: 'Resumo financeiro',
              subtitle: 'Entradas, saídas e valores em aberto.',
            ),
            const SizedBox(height: 16),
            _HorizontalBarCompact(
              label: 'Entradas',
              value: entradas,
              maxValue: maior,
              color: VitalisColors.sucesso,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalBarCompact(
              label: 'Saídas',
              value: saidas,
              maxValue: maior,
              color: VitalisColors.erro,
              formatarValor: formatarValor,
            ),
            const SizedBox(height: 12),
            _HorizontalBarCompact(
              label: 'Em aberto',
              value: aberto,
              maxValue: maior,
              color: VitalisColors.cobreQueimado,
              formatarValor: formatarValor,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusAndAlertsColumn extends StatelessWidget {
  final int pagas;
  final int pendentes;
  final int vencidas;
  final int vencendo;
  final List<_AlertItem> alertas;

  const _StatusAndAlertsColumn({
    required this.pagas,
    required this.pendentes,
    required this.vencidas,
    required this.vencendo,
    required this.alertas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusChartCardCompact(
          pagas: pagas,
          pendentes: pendentes,
          vencidas: vencidas,
          vencendo: vencendo,
        ),
        const SizedBox(height: 14),
        _AlertsCard(alertas: alertas),
      ],
    );
  }
}

class _StatusChartCardCompact extends StatelessWidget {
  final int pagas;
  final int pendentes;
  final int vencidas;
  final int vencendo;

  const _StatusChartCardCompact({
    required this.pagas,
    required this.pendentes,
    required this.vencidas,
    required this.vencendo,
  });

  @override
  Widget build(BuildContext context) {
    final total = pagas + pendentes;
    final totalSeguro = total == 0 ? 1 : total;

    final percentualPagas = pagas / totalSeguro;
    final percentualPendentes = pendentes / totalSeguro;
    final percentualVencidas = vencidas / totalSeguro;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ChartHeaderCompact(
              icon: Icons.pie_chart_rounded,
              title: 'Status das mensalidades',
              subtitle: 'Distribuição resumida dos pagamentos.',
            ),
            const SizedBox(height: 14),
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
                        '$total',
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
                      _LegendLineCompact(
                        color: VitalisColors.sucesso,
                        label: 'Pagas',
                        value: pagas.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLineCompact(
                        color: VitalisColors.alerta,
                        label: 'Pendentes',
                        value: pendentes.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLineCompact(
                        color: VitalisColors.erro,
                        label: 'Vencidas',
                        value: vencidas.toString(),
                      ),
                      const SizedBox(height: 8),
                      _LegendLineCompact(
                        color: VitalisColors.cobreQueimado,
                        label: 'Vencendo',
                        value: vencendo.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<_AlertItem> alertas;

  const _AlertsCard({required this.alertas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ChartHeaderCompact(
              icon: Icons.notifications_active_rounded,
              title: 'Alertas rápidos',
              subtitle: 'Pontos que merecem atenção.',
            ),
            const SizedBox(height: 12),
            if (alertas.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VitalisColors.sucesso.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Tudo certo por aqui. Nenhum alerta importante no momento.',
                  style: TextStyle(
                    color: VitalisColors.sucesso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...alertas.map(
                (alerta) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlertTile(alerta: alerta),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _AlertTile extends StatelessWidget {
  final _AlertItem alerta;

  const _AlertTile({required this.alerta});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alerta.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: alerta.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(alerta.icon, color: alerta.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alerta.title,
                      style: TextStyle(
                        color: alerta.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alerta.subtitle,
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
              const Icon(
                Icons.chevron_right_rounded,
                color: VitalisColors.cinzaMedio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMovementsCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> movimentos;
  final String Function(double) formatarValor;
  final String Function(dynamic) formatarData;
  final double Function(dynamic) toDouble;
  final VoidCallback onTapVerTodos;

  const _RecentMovementsCard({
    required this.movimentos,
    required this.formatarValor,
    required this.formatarData,
    required this.toDouble,
    required this.onTapVerTodos,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _ChartHeaderCompact(
                    icon: Icons.receipt_long_rounded,
                    title: 'Movimentações recentes',
                    subtitle: 'Últimos lançamentos financeiros.',
                  ),
                ),
                TextButton(
                  onPressed: onTapVerTodos,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (movimentos.isEmpty)
              const Text(
                'Nenhuma movimentação recente.',
                style: TextStyle(
                  color: VitalisColors.cinzaMedio,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              ...movimentos.map((doc) {
                final data = doc.data();
                final tipo = (data['tipo'] ?? '').toString();
                final descricao = (data['descricao'] ?? 'Sem descrição')
                    .toString();
                final valor = toDouble(data['valor']);
                final isEntrada = tipo == 'entrada';
                final cor = isEntrada
                    ? VitalisColors.sucesso
                    : VitalisColors.erro;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEntrada
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: cor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              descricao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VitalisColors.azulMarinhoProfundo,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatarData(data['createdAt']),
                              style: const TextStyle(
                                color: VitalisColors.cinzaMedio,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatarValor(valor),
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w900,
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

class _ChartHeaderCompact extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ChartHeaderCompact({
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

class _HorizontalBarCompact extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String Function(double) formatarValor;

  const _HorizontalBarCompact({
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

class _LegendLineCompact extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendLineCompact({
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
