import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/home_menu_card.dart';
import 'aniversariantes_page.dart';
import 'clientes_page.dart';
import 'cobrancas_page.dart';
import 'financeiro_page.dart';
import 'mensalidades_page.dart';
import 'pdfs_page.dart';
import 'servicos_page.dart';

class FuncionarioHomePage extends StatefulWidget {
  final String nome;
  final String email;

  const FuncionarioHomePage({
    super.key,
    required this.nome,
    required this.email,
  });

  @override
  State<FuncionarioHomePage> createState() => _FuncionarioHomePageState();
}

class _FuncionarioHomePageState extends State<FuncionarioHomePage> {
  String _currentPage = 'home';

  void _onNavigate(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  int _contarClientesComStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String status,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      return (data['status'] ?? '').toString().toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  int _contarPlanosAtivos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) => doc.data()['temPlanoAtivo'] == true).length;
  }

  String get _tituloAtual {
    switch (_currentPage) {
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
      case 'home':
      default:
        return 'Vitalis Studio';
    }
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
              builder: (_) =>
                  const CadastroMensalidadeDialog(role: 'funcionario'),
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
      case 'clientes':
        return ClientesPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'servicos':
        return ServicosPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'mensalidades':
        return MensalidadesPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'financeiro':
        return FinanceiroPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'cobrancas':
        return CobrancasPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'aniversariantes':
        return AniversariantesPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'pdfs':
        return PdfsPage(
          nome: nome,
          email: email,
          role: 'funcionario',
          embedded: true,
        );

      case 'home':
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _tituloAtual,
      nome: widget.nome,
      email: widget.email,
      role: 'funcionario',
      currentPage: _currentPage,
      onNavigate: _onNavigate,
      floatingActionButton: _floatingActionButtonAtual(),
      child: _conteudoAtual(),
    );
  }

  Widget _buildHomeContent() {
    final nomeExibicao = widget.nome.trim().isEmpty
        ? 'Funcionário'
        : widget.nome;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final gridCount = constraints.maxWidth > 1200
              ? 4
              : constraints.maxWidth > 800
              ? 3
              : 2;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $nomeExibicao',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acompanhe seus atendimentos e atividades do dia.',
                  style: TextStyle(color: VitalisColors.cinzaMedio),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Painel operacional',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gerencie clientes, mensalidades e atendimentos com rapidez.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ClienteService.listarClientes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: VitalisColors.verdeEsmeralda,
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final totalClientes = docs.length;
                    final ativos = _contarClientesComStatus(docs, 'ativo');
                    final vencendo = _contarClientesComStatus(docs, 'vencendo');
                    final vencidos = _contarClientesComStatus(docs, 'vencido');
                    final planosAtivos = _contarPlanosAtivos(docs);

                    final kpis = [
                      _KpiData(
                        titulo: 'Clientes ativos',
                        valor: ativos.toString(),
                        subtitulo: '$totalClientes no total',
                        cor: VitalisColors.verdeEsmeralda,
                        icone: Icons.people_alt_rounded,
                      ),
                      _KpiData(
                        titulo: 'Planos ativos',
                        valor: planosAtivos.toString(),
                        subtitulo: 'Em andamento',
                        cor: VitalisColors.info,
                        icone: Icons.verified_rounded,
                      ),
                      _KpiData(
                        titulo: 'Vencendo',
                        valor: vencendo.toString(),
                        subtitulo: 'Atenção próxima',
                        cor: VitalisColors.alerta,
                        icone: Icons.schedule_rounded,
                      ),
                      _KpiData(
                        titulo: 'Vencidos',
                        valor: vencidos.toString(),
                        subtitulo: 'Ação necessária',
                        cor: VitalisColors.erro,
                        icone: Icons.warning_amber_rounded,
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: List.generate(kpis.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == kpis.length - 1 ? 0 : 12,
                              ),
                              child: _KpiCard(data: kpis[index]),
                            ),
                          );
                        }),
                      );
                    }

                    return Column(
                      children: kpis
                          .map(
                            (kpi) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _KpiCard(data: kpi),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  'Módulos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acesso rápido às funções operacionais.',
                  style: TextStyle(color: VitalisColors.cinzaMedio),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: gridCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.5,
                  children: [
                    _buildCard(
                      Icons.people_alt_rounded,
                      'Clientes',
                      'Cadastro e histórico',
                      'clientes',
                    ),
                    _buildCard(
                      Icons.design_services_rounded,
                      'Serviços',
                      'Planos e valores',
                      'servicos',
                    ),
                    _buildCard(
                      Icons.event_note_rounded,
                      'Mensalidades',
                      'Cobranças mensais',
                      'mensalidades',
                    ),
                    _buildCard(
                      Icons.chat_bubble_outline_rounded,
                      'Cobranças',
                      'Mensagens e pendências',
                      'cobrancas',
                    ),
                    _buildCard(
                      Icons.cake_rounded,
                      'Aniversariantes',
                      'Próximos aniversários',
                      'aniversariantes',
                    ),
                    _buildCard(
                      Icons.attach_money_rounded,
                      'Financeiro',
                      'Lançamentos e histórico',
                      'financeiro',
                    ),
                    _buildCard(
                      Icons.picture_as_pdf_rounded,
                      'PDFs',
                      'Documentos e modelos',
                      'pdfs',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    IconData icon,
    String title,
    String subtitle,
    String pageKey,
  ) {
    return HomeMenuCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _onNavigate(pageKey),
    );
  }
}

class _KpiData {
  final String titulo;
  final String valor;
  final String subtitulo;
  final Color cor;
  final IconData icone;

  const _KpiData({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.cor,
    required this.icone,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: data.cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icone, color: data.cor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: VitalisColors.azulMarinhoProfundo,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.valor,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: data.cor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitulo,
                    style: const TextStyle(
                      color: VitalisColors.cinzaMedio,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
