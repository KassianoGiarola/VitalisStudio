import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../widgets/app_shell.dart';

class CobrancasPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const CobrancasPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'funcionario',
    this.embedded = false,
  });

  @override
  State<CobrancasPage> createState() => _CobrancasPageState();
}

class _CobrancasPageState extends State<CobrancasPage> {
  String filtro = 'todos';

  double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  String _formatarValor(double v) {
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  int _diasRestantesPorVencimento(Timestamp? vencimento) {
    if (vencimento == null) return 999999;

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    final data = vencimento.toDate();
    final vencSemHora = DateTime(data.year, data.month, data.day);

    return vencSemHora.difference(hojeSemHora).inDays;
  }

  bool _passaFiltro(int dias) {
    switch (filtro) {
      case 'hoje':
        return dias == 0;
      case 'proximos':
        return dias > 0;
      case 'atrasados':
        return dias < 0;
      default:
        return true;
    }
  }

  bool _clientePodeReceberCobranca(Map<String, dynamic> cliente) {
    final status = (cliente['status'] ?? '').toString().toLowerCase();
    final receber = cliente['receberMensagemCobranca'] != false;

    return status != 'inativo' && receber;
  }

  String _statusTexto(int dias) {
    if (dias == 0) return 'Vence hoje';
    if (dias > 0) return 'Faltam $dias dias';
    return 'Atrasado ${dias.abs()} dias';
  }

  Color _corStatus(int dias) {
    if (dias == 0) return VitalisColors.alerta;
    if (dias > 0) return VitalisColors.verdeEsmeralda;
    return VitalisColors.erro;
  }

  Future<String> _gerarMensagemDinamica({
    required String nome,
    required String servico,
    required double valor,
    required int dia,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('cobranca')
        .get();

    final data = doc.data() ?? {};

    String template =
        (data['mensagemPadrao'] ??
                'Olá {nome}! 😊\n\n'
                    'Sua mensalidade de {servico} no valor de {valor} vence no dia {dia}.\n\n'
                    'Qualquer dúvida estou à disposição!')
            .toString();

    return template
        .replaceAll('{nome}', nome)
        .replaceAll('{servico}', servico)
        .replaceAll('{valor}', _formatarValor(valor))
        .replaceAll('{dia}', dia.toString())
        .replaceAll('{dia_vencimento}', dia.toString());
  }

  Future<String> _gerarMensagemAtrasadoDinamica({
    required String nome,
    required String servico,
    required double valor,
    required int dia,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('cobranca')
        .get();

    final data = doc.data() ?? {};

    String template =
        (data['mensagemAtrasado'] ??
                data['mensagemPadrao'] ??
                'Olá {nome}! 😊\n\n'
                    'Sua mensalidade de {servico} no valor de {valor} está em atraso.\n\n'
                    'Poderia verificar para mim?')
            .toString();

    return template
        .replaceAll('{nome}', nome)
        .replaceAll('{servico}', servico)
        .replaceAll('{valor}', _formatarValor(valor))
        .replaceAll('{dia}', dia.toString())
        .replaceAll('{dia_vencimento}', dia.toString());
  }

  Future<void> _abrirWhatsApp(String telefone, String mensagem) async {
    final numero = telefone.replaceAll(RegExp(r'\D'), '');

    if (numero.isEmpty) return;

    final numeroFinal = numero.startsWith('55') ? numero : '55$numero';

    final uri = Uri.parse(
      'https://wa.me/$numeroFinal?text=${Uri.encodeComponent(mensagem)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cobrarTodosAtrasados(BuildContext context) async {
    try {
      final mensalidadesSnap = await FirebaseFirestore.instance
          .collection('mensalidades')
          .where('status', isEqualTo: 'pendente')
          .get();

      int cobrancasAbertas = 0;

      for (final doc in mensalidadesSnap.docs) {
        final data = doc.data();
        final vencimento = data['vencimento'] as Timestamp?;
        final dias = _diasRestantesPorVencimento(vencimento);

        if (dias >= 0) continue;

        final clienteId = (data['clienteId'] ?? '').toString();
        if (clienteId.isEmpty) continue;

        final clienteSnap = await FirebaseFirestore.instance
            .collection('clientes')
            .doc(clienteId)
            .get();

        final cliente = clienteSnap.data() ?? {};

        if (!_clientePodeReceberCobranca(cliente)) continue;

        final telefone = (cliente['telefone'] ?? '').toString();
        if (telefone.trim().isEmpty) continue;

        final nome = (data['nomeCliente'] ?? '').toString();
        final servico = (data['nomeServico'] ?? '').toString();
        final valor = _toDouble(data['valorFinal'] ?? data['valorBase']);
        final dia = (data['diaVencimento'] ?? 1) is num
            ? (data['diaVencimento'] as num).toInt()
            : 1;

        final mensagem = await _gerarMensagemAtrasadoDinamica(
          nome: nome,
          servico: servico,
          valor: valor,
          dia: dia,
        );

        await _abrirWhatsApp(telefone, mensagem);
        cobrancasAbertas++;

        await Future.delayed(const Duration(seconds: 2));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cobrancasAbertas > 0
                ? 'Cobranças abertas no WhatsApp: $cobrancasAbertas'
                : 'Nenhum cliente atrasado autorizado para cobrança encontrado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir cobranças em lote.')),
      );
    }
  }

  Widget _filtroBtn(String texto, String valor) {
    final selecionado = filtro == valor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: selecionado,
        onSelected: (_) {
          setState(() {
            filtro = valor;
          });
        },
      ),
    );
  }

  Future<void> _cobrarIndividualmente({
    required String telefone,
    required String nome,
    required String servico,
    required double valor,
    required int dia,
    required int dias,
  }) async {
    final mensagem = dias < 0
        ? await _gerarMensagemAtrasadoDinamica(
            nome: nome,
            servico: servico,
            valor: valor,
            dia: dia,
          )
        : await _gerarMensagemDinamica(
            nome: nome,
            servico: servico,
            valor: valor,
            dia: dia,
          );

    await _abrirWhatsApp(telefone, mensagem);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Cobranças do Dia',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'cobrancas',
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Cobrar todos atrasados'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VitalisColors.erro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () async {
                await _cobrarTodosAtrasados(context);
              },
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filtroBtn('Todos', 'todos'),
                _filtroBtn('Hoje', 'hoje'),
                _filtroBtn('Próximos', 'proximos'),
                _filtroBtn('Atrasados', 'atrasados'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('mensalidades')
                  .where('status', isEqualTo: 'pendente')
                  .snapshots(),
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
                    child: Text('Erro ao carregar cobranças.'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
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
                            Icons.mark_chat_unread_outlined,
                            size: 54,
                            color: VitalisColors.cobreQueimado,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma cobrança pendente encontrada',
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
                  );
                }

                final docsFiltrados = docs.where((doc) {
                  final data = doc.data();
                  final vencimento = data['vencimento'] as Timestamp?;
                  final dias = _diasRestantesPorVencimento(vencimento);
                  return _passaFiltro(dias);
                }).toList();

                docsFiltrados.sort((a, b) {
                  final va = a.data()['vencimento'] as Timestamp?;
                  final vb = b.data()['vencimento'] as Timestamp?;

                  final ta = va?.toDate().millisecondsSinceEpoch ?? 0;
                  final tb = vb?.toDate().millisecondsSinceEpoch ?? 0;

                  return ta.compareTo(tb);
                });

                if (docsFiltrados.isEmpty) {
                  return Center(
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
                            'Nenhuma cobrança encontrada nesse filtro',
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
                  );
                }

                return ListView.separated(
                  itemCount: docsFiltrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final data = docsFiltrados[i].data();

                    final nome = (data['nomeCliente'] ?? '').toString();
                    final servico = (data['nomeServico'] ?? '').toString();
                    final valor = _toDouble(
                      data['valorFinal'] ?? data['valorBase'],
                    );
                    final dia = (data['diaVencimento'] ?? 1) is num
                        ? (data['diaVencimento'] as num).toInt()
                        : 1;
                    final clienteId = (data['clienteId'] ?? '').toString();
                    final vencimento = data['vencimento'] as Timestamp?;
                    final dias = _diasRestantesPorVencimento(vencimento);

                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: FirebaseFirestore.instance
                          .collection('clientes')
                          .doc(clienteId)
                          .get(),
                      builder: (context, clienteSnap) {
                        if (clienteSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: VitalisColors.verdeEsmeralda,
                                ),
                              ),
                            ),
                          );
                        }

                        final clienteData = clienteSnap.data?.data() ?? {};

                        if (!_clientePodeReceberCobranca(clienteData)) {
                          return const SizedBox.shrink();
                        }

                        final telefone = (clienteData['telefone'] ?? '')
                            .toString();

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _corStatus(
                                    dias,
                                  ).withOpacity(0.12),
                                  child: Icon(
                                    Icons.person,
                                    color: _corStatus(dias),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              VitalisColors.azulMarinhoProfundo,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(servico),
                                      const SizedBox(height: 4),
                                      Text(_formatarValor(valor)),
                                      const SizedBox(height: 6),
                                      Text(
                                        _statusTexto(dias),
                                        style: TextStyle(
                                          color: _corStatus(dias),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Enviar cobrança',
                                  icon: const Icon(
                                    Icons.chat,
                                    color: VitalisColors.verdeEsmeralda,
                                  ),
                                  onPressed: telefone.isEmpty
                                      ? null
                                      : () async {
                                          await _cobrarIndividualmente(
                                            telefone: telefone,
                                            nome: nome,
                                            servico: servico,
                                            valor: valor,
                                            dia: dia,
                                            dias: dias,
                                          );
                                        },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
