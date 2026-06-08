import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../services/mensalidade_service.dart';
import '../widgets/app_shell.dart';
import 'clientes_page.dart';

class MensalidadesPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const MensalidadesPage({
    super.key,
    this.nome = '',
    this.email = '',
    required this.role,
    this.embedded = false,
  });

  @override
  State<MensalidadesPage> createState() => _MensalidadesPageState();
}

class _MensalidadesPageState extends State<MensalidadesPage> {
  final TextEditingController _pesquisaController = TextEditingController();
  String _busca = '';
  String _statusFiltro = 'todos';

  bool get isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _pesquisaController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final valor = _pesquisaController.text;
    if (valor == _busca) return;
    setState(() => _busca = valor);
  }

  @override
  void dispose() {
    _pesquisaController.removeListener(_onSearchChanged);
    _pesquisaController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  int _toInt(dynamic valor, {int padrao = 0}) {
    if (valor == null) return padrao;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString()) ?? padrao;
  }

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatarData(Timestamp? timestamp) {
    if (timestamp == null) return '--/--/----';
    final data = timestamp.toDate();
    return formatarDataBrasileira(data);
  }

  String _formatarCompetencia(String competencia) {
    final partes = competencia.split('-');
    if (partes.length != 2) return competencia;

    const nomesMeses = {
      '01': 'jan',
      '02': 'fev',
      '03': 'mar',
      '04': 'abr',
      '05': 'mai',
      '06': 'jun',
      '07': 'jul',
      '08': 'ago',
      '09': 'set',
      '10': 'out',
      '11': 'nov',
      '12': 'dez',
    };

    return '${nomesMeses[partes[1]] ?? partes[1]}/${partes[0]}';
  }

  String _formatarFormaPagamento(String forma) {
    switch (forma.toLowerCase()) {
      case 'pix':
        return 'Pix';
      case 'dinheiro':
        return 'Dinheiro';
      case 'cartao':
        return 'Cartão';
      case 'transferencia':
        return 'Transferência';
      default:
        return forma.isEmpty ? '-' : forma;
    }
  }

  String _formatarTipoCobranca(String tipo) {
    switch (tipo) {
      case 'mensalidade':
        return 'Mensalidade';
      case 'avulso':
        return 'Avulso';
      case 'sessao':
        return 'Sessão';
      case 'aula_experimental':
        return 'Aula experimental';
      case 'outro':
        return 'Outro';
      default:
        return 'Mensalidade';
    }
  }

  bool _isMensalidade(Map<String, dynamic> data) {
    final tipo = (data['tipoCobranca'] ?? 'mensalidade').toString();
    return tipo == 'mensalidade';
  }

  bool _passaFiltro(Map<String, dynamic> data) {
    if (_busca.trim().isEmpty) return true;

    final busca = normalizarTexto(_busca);

    final nomeCliente = normalizarTexto((data['nomeCliente'] ?? '').toString());
    final nomeServico = normalizarTexto((data['nomeServico'] ?? '').toString());
    final competencia = normalizarTexto((data['competencia'] ?? '').toString());
    final status = normalizarTexto((data['status'] ?? '').toString());
    final tipo = normalizarTexto(
      _formatarTipoCobranca((data['tipoCobranca'] ?? 'mensalidade').toString()),
    );

    return nomeCliente.contains(busca) ||
        nomeServico.contains(busca) ||
        competencia.contains(busca) ||
        status.contains(busca) ||
        tipo.contains(busca);
  }

  bool _passaFiltroStatus(Map<String, dynamic> data) {
    if (_statusFiltro == 'todos') return true;
    return _statusVisual(data) == _statusFiltro;
  }

  String _tituloStatus(String status) {
    switch (status) {
      case 'pago':
        return 'Pagos';
      case 'pendente':
        return 'Pendentes';
      case 'vencendo':
        return 'Vencendo';
      case 'vencido':
        return 'Vencidos';
      default:
        return 'Todos';
    }
  }

  Widget _filtroStatusChip(String status, int quantidade) {
    final selecionado = _statusFiltro == status;
    final cor = status == 'todos'
        ? VitalisColors.azulMarinhoProfundo
        : _corStatus(status);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selecionado,
        label: Text('${_tituloStatus(status)} ($quantidade)'),
        selectedColor: cor.withOpacity(0.14),
        backgroundColor: Colors.white,
        side: BorderSide(color: selecionado ? cor : VitalisColors.borda),
        labelStyle: TextStyle(
          color: selecionado ? cor : VitalisColors.cinzaEscuro,
          fontWeight: FontWeight.w800,
        ),
        onSelected: (_) {
          setState(() {
            _statusFiltro = status;
          });
        },
      ),
    );
  }

  Widget _resumoStatusCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icon,
    required Color cor,
  }) {
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
              color: cor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cor, size: 21),
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
                    color: VitalisColors.azulMarinhoProfundo,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
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

  String _statusVisual(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pendente').toString().toLowerCase();
    if (status == 'pago') return 'pago';

    if (!_isMensalidade(data)) return 'pendente';

    final vencimento = data['vencimento'] as Timestamp?;
    if (vencimento == null) return 'pendente';

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    final dataVenc = vencimento.toDate();
    final vencSemHora = DateTime(dataVenc.year, dataVenc.month, dataVenc.day);

    if (hojeSemHora.isAfter(vencSemHora)) return 'vencido';

    final dias = vencSemHora.difference(hojeSemHora).inDays;
    if (dias <= 3) return 'vencendo';
    return 'pendente';
  }

  String _textoPrazo(Map<String, dynamic> data) {
    final status = _statusVisual(data);

    if (status == 'pago') return 'pagamento realizado';

    if (!_isMensalidade(data)) {
      final dataServico = data['dataServico'] as Timestamp?;
      if (dataServico == null) return 'data do serviço não informada';
      return 'serviço em ${_formatarData(dataServico)}';
    }

    final vencimento = data['vencimento'] as Timestamp?;
    if (vencimento == null) return 'vencimento não informado';

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    final dataVenc = vencimento.toDate();
    final vencSemHora = DateTime(dataVenc.year, dataVenc.month, dataVenc.day);

    final dias = vencSemHora.difference(hojeSemHora).inDays;

    if (dias == 0) return 'vence hoje';
    if (dias > 0) return 'faltam $dias dias';
    return 'atrasado há ${dias.abs()} dias';
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pago':
        return VitalisColors.sucesso;
      case 'vencendo':
        return VitalisColors.alerta;
      case 'vencido':
        return VitalisColors.erro;
      default:
        return VitalisColors.cobreQueimado;
    }
  }

  Future<void> _confirmarExclusao({
    required String mensalidadeId,
    required String nomeCliente,
    required String nomeServico,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text(
          'Deseja excluir o lançamento de $nomeCliente - $nomeServico?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VitalisColors.erro,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await MensalidadeService.excluirMensalidade(mensalidadeId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento excluído com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir lançamento: $e')));
    }
  }

  Future<void> _abrirNovaMensalidade({
    String? clienteIdInicial,
    String? nomeClienteInicial,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => CadastroMensalidadeDialog(
        role: widget.role,
        clienteIdInicial: clienteIdInicial,
        nomeClienteInicial: nomeClienteInicial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Mensalidades',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'mensalidades',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirNovaMensalidade(),
        icon: const Icon(Icons.add),
        label: const Text('Novo lançamento'),
      ),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VitalisColors.verdeEsmeralda.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: VitalisColors.verdeEsmeralda,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Controle de mensalidades',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: VitalisColors.azulMarinhoProfundo,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Acompanhe clientes, serviços, vencimentos e pagamentos por status.',
                            style: TextStyle(color: VitalisColors.cinzaMedio),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pesquisaController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText:
                        'Pesquisar cliente, serviço, tipo ou competência',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busca.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _pesquisaController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: MensalidadeService.listarMensalidades(),
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
                    child: Text('Erro ao carregar lançamentos.'),
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
                            Icons.event_note_rounded,
                            size: 54,
                            color: VitalisColors.cobreQueimado,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum lançamento cadastrado.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: VitalisColors.azulMarinhoProfundo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final filtradosPorTexto = docs
                    .where((doc) => _passaFiltro(doc.data()))
                    .toList();

                int totalPagos = 0;
                int totalPendentes = 0;
                int totalVencendo = 0;
                int totalVencidos = 0;
                double totalEmAberto = 0.0;

                for (final doc in filtradosPorTexto) {
                  final data = doc.data();
                  final status = _statusVisual(data);

                  if (status == 'pago') {
                    totalPagos++;
                  } else if (status == 'vencendo') {
                    totalVencendo++;
                    totalEmAberto += _toDouble(data['valorFinal']);
                  } else if (status == 'vencido') {
                    totalVencidos++;
                    totalEmAberto += _toDouble(data['valorFinal']);
                  } else {
                    totalPendentes++;
                    totalEmAberto += _toDouble(data['valorFinal']);
                  }
                }

                final filtrados = filtradosPorTexto
                    .where((doc) => _passaFiltroStatus(doc.data()))
                    .toList();

                final Map<
                  String,
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                >
                agrupadoPorCliente = {};

                for (final doc in filtrados) {
                  final data = doc.data();
                  final clienteId = (data['clienteId'] ?? 'sem_cliente')
                      .toString();
                  agrupadoPorCliente.putIfAbsent(clienteId, () => []);
                  agrupadoPorCliente[clienteId]!.add(doc);
                }

                final clientesAgrupados = agrupadoPorCliente.entries.toList()
                  ..sort((a, b) {
                    final nomeA = normalizarTexto(
                      (a.value.first.data()['nomeCliente'] ?? '').toString(),
                    );
                    final nomeB = normalizarTexto(
                      (b.value.first.data()['nomeCliente'] ?? '').toString(),
                    );
                    return nomeA.compareTo(nomeB);
                  });

                final resumoCards = [
                  _resumoStatusCard(
                    titulo: 'Total filtrado',
                    valor: filtradosPorTexto.length.toString(),
                    subtitulo:
                        '${clientesAgrupados.length} cliente(s) visíveis',
                    icon: Icons.list_alt_rounded,
                    cor: VitalisColors.azulMarinhoProfundo,
                  ),
                  _resumoStatusCard(
                    titulo: 'Em aberto',
                    valor: _formatarValor(totalEmAberto),
                    subtitulo: 'Pendentes, vencendo e vencidos',
                    icon: Icons.account_balance_wallet_rounded,
                    cor: VitalisColors.cobreQueimado,
                  ),
                  _resumoStatusCard(
                    titulo: 'Vencendo',
                    valor: totalVencendo.toString(),
                    subtitulo: 'Até 3 dias',
                    icon: Icons.schedule_rounded,
                    cor: VitalisColors.alerta,
                  ),
                  _resumoStatusCard(
                    titulo: 'Vencidos',
                    valor: totalVencidos.toString(),
                    subtitulo: 'Ação necessária',
                    icon: Icons.warning_amber_rounded,
                    cor: VitalisColors.erro,
                  ),
                ];

                return Column(
                  children: [
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: resumoCards.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, index) => resumoCards[index],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filtroStatusChip('todos', filtradosPorTexto.length),
                          _filtroStatusChip('pago', totalPagos),
                          _filtroStatusChip('pendente', totalPendentes),
                          _filtroStatusChip('vencendo', totalVencendo),
                          _filtroStatusChip('vencido', totalVencidos),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: clientesAgrupados.isEmpty
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
                                      Icons.search_off_rounded,
                                      size: 54,
                                      color: VitalisColors.cobreQueimado,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Nenhum lançamento encontrado.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            VitalisColors.azulMarinhoProfundo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: clientesAgrupados.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final entry = clientesAgrupados[index];
                                final lista = entry.value;

                                lista.sort((a, b) {
                                  final da = a.data();
                                  final db = b.data();

                                  final statusA = _statusVisual(da);
                                  final statusB = _statusVisual(db);
                                  const prioridade = {
                                    'vencido': 0,
                                    'vencendo': 1,
                                    'pendente': 2,
                                    'pago': 3,
                                  };

                                  final cmpStatus = (prioridade[statusA] ?? 9)
                                      .compareTo(prioridade[statusB] ?? 9);
                                  if (cmpStatus != 0) return cmpStatus;

                                  final servA = normalizarTexto(
                                    (da['nomeServico'] ?? '').toString(),
                                  );
                                  final servB = normalizarTexto(
                                    (db['nomeServico'] ?? '').toString(),
                                  );
                                  final cmpServico = servA.compareTo(servB);
                                  if (cmpServico != 0) return cmpServico;

                                  final compA = (da['competencia'] ?? '')
                                      .toString();
                                  final compB = (db['competencia'] ?? '')
                                      .toString();
                                  return compA.compareTo(compB);
                                });

                                final primeiro = lista.first.data();
                                final nomeCliente =
                                    (primeiro['nomeCliente'] ?? 'Sem cliente')
                                        .toString();
                                final clienteId = (primeiro['clienteId'] ?? '')
                                    .toString();

                                return _ClienteMensalidadesCard(
                                  clienteId: clienteId,
                                  nomeCliente: nomeCliente,
                                  mensalidades: lista,
                                  isAdmin: isAdmin,
                                  role: widget.role,
                                  formatarValor: _formatarValor,
                                  formatarData: _formatarData,
                                  formatarCompetencia: _formatarCompetencia,
                                  formatarFormaPagamento:
                                      _formatarFormaPagamento,
                                  formatarTipoCobranca: _formatarTipoCobranca,
                                  toDouble: _toDouble,
                                  toInt: _toInt,
                                  statusVisual: _statusVisual,
                                  textoPrazo: _textoPrazo,
                                  corStatus: _corStatus,
                                  onExcluir: _confirmarExclusao,
                                  onAdicionarServico: _abrirNovaMensalidade,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClienteMensalidadesCard extends StatefulWidget {
  final String clienteId;
  final String nomeCliente;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> mensalidades;
  final bool isAdmin;
  final String role;
  final String Function(double) formatarValor;
  final String Function(Timestamp?) formatarData;
  final String Function(String) formatarCompetencia;
  final String Function(String) formatarFormaPagamento;
  final String Function(String) formatarTipoCobranca;
  final double Function(dynamic) toDouble;
  final int Function(dynamic, {int padrao}) toInt;
  final String Function(Map<String, dynamic>) statusVisual;
  final String Function(Map<String, dynamic>) textoPrazo;
  final Color Function(String) corStatus;
  final Future<void> Function({
    required String mensalidadeId,
    required String nomeCliente,
    required String nomeServico,
  })
  onExcluir;
  final Future<void> Function({
    String? clienteIdInicial,
    String? nomeClienteInicial,
  })
  onAdicionarServico;

  const _ClienteMensalidadesCard({
    required this.clienteId,
    required this.nomeCliente,
    required this.mensalidades,
    required this.isAdmin,
    required this.role,
    required this.formatarValor,
    required this.formatarData,
    required this.formatarCompetencia,
    required this.formatarFormaPagamento,
    required this.formatarTipoCobranca,
    required this.toDouble,
    required this.toInt,
    required this.statusVisual,
    required this.textoPrazo,
    required this.corStatus,
    required this.onExcluir,
    required this.onAdicionarServico,
  });

  @override
  State<_ClienteMensalidadesCard> createState() =>
      _ClienteMensalidadesCardState();
}

class _ClienteMensalidadesCardState extends State<_ClienteMensalidadesCard> {
  bool _expandido = false;

  String _statusTitulo(String status) {
    switch (status) {
      case 'pago':
        return 'Pago';
      case 'vencendo':
        return 'Vencendo';
      case 'vencido':
        return 'Vencido';
      default:
        return 'Pendente';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pago':
        return Icons.check_circle_rounded;
      case 'vencendo':
        return Icons.schedule_rounded;
      case 'vencido':
        return Icons.warning_amber_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    int pagos = 0;
    int pendentes = 0;
    int vencendo = 0;
    int vencidos = 0;
    double totalAberto = 0.0;

    for (final doc in widget.mensalidades) {
      final data = doc.data();
      final status = widget.statusVisual(data);

      if (status == 'pago') {
        pagos++;
      } else {
        totalAberto += widget.toDouble(data['valorFinal']);

        if (status == 'vencendo') {
          vencendo++;
        } else if (status == 'vencido') {
          vencidos++;
        } else {
          pendentes++;
        }
      }
    }

    final statusGeral = vencidos > 0
        ? 'vencido'
        : vencendo > 0
        ? 'vencendo'
        : pendentes > 0
        ? 'pendente'
        : 'pago';

    final corGeral = widget.corStatus(statusGeral);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expandido = !_expandido),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: corGeral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_statusIcon(statusGeral), color: corGeral),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nomeCliente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: VitalisColors.azulMarinhoProfundo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusMiniChip(
                              label:
                                  '${widget.mensalidades.length} lançamento(s)',
                              color: VitalisColors.cinzaMedio,
                            ),
                            if (pagos > 0)
                              _StatusMiniChip(
                                label: '$pagos pago(s)',
                                color: VitalisColors.sucesso,
                              ),
                            if (pendentes > 0)
                              _StatusMiniChip(
                                label: '$pendentes pendente(s)',
                                color: VitalisColors.cobreQueimado,
                              ),
                            if (vencendo > 0)
                              _StatusMiniChip(
                                label: '$vencendo vencendo',
                                color: VitalisColors.alerta,
                              ),
                            if (vencidos > 0)
                              _StatusMiniChip(
                                label: '$vencidos vencido(s)',
                                color: VitalisColors.erro,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Em aberto',
                        style: TextStyle(
                          color: VitalisColors.cinzaMedio,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.formatarValor(totalAberto),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: corGeral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: VitalisColors.azulMarinhoProfundo,
                  ),
                ],
              ),
            ),
            if (_expandido) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: VitalisColors.borda),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => widget.onAdicionarServico(
                      clienteIdInicial: widget.clienteId,
                      nomeClienteInicial: widget.nomeCliente,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Adicionar serviço'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...List.generate(widget.mensalidades.length, (index) {
                final doc = widget.mensalidades[index];
                final data = doc.data();

                final tipoCobranca = (data['tipoCobranca'] ?? 'mensalidade')
                    .toString();
                final isMensalidade = tipoCobranca == 'mensalidade';
                final nomeServico = (data['nomeServico'] ?? 'Sem serviço')
                    .toString();
                final competencia = (data['competencia'] ?? '').toString();
                final quantidade = widget.toInt(data['quantidade'], padrao: 1);
                final valorUnitario = widget.toDouble(data['valorUnitario']);
                final valorBase = widget.toDouble(data['valorBase']);
                final desconto = widget.toDouble(data['desconto']);
                final juros = widget.toDouble(data['juros']);
                final valorFinal = widget.toDouble(data['valorFinal']);
                final diaVencimento = widget.toInt(
                  data['diaVencimento'],
                  padrao: 0,
                );
                final vencimento = data['vencimento'] as Timestamp?;
                final dataServico = data['dataServico'] as Timestamp?;
                final clienteId = (data['clienteId'] ?? '').toString();
                final formaPagamento = (data['formaPagamento'] ?? '')
                    .toString();
                final status = widget.statusVisual(data);
                final textoPrazo = widget.textoPrazo(data);
                final corStatus = widget.corStatus(status);

                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == widget.mensalidades.length - 1 ? 0 : 12,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: VitalisColors.borda),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;

                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: corStatus.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isMensalidade
                                      ? Icons.calendar_month_rounded
                                      : Icons.event_available_rounded,
                                  color: corStatus,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nomeServico,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            VitalisColors.azulMarinhoProfundo,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      textoPrazo,
                                      style: TextStyle(
                                        color: corStatus,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusBadge(
                                label: _statusTitulo(status),
                                color: corStatus,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(
                                label:
                                    'Tipo: ${widget.formatarTipoCobranca(tipoCobranca)}',
                              ),
                              if (isMensalidade) ...[
                                _InfoChip(
                                  label:
                                      'Competência: ${widget.formatarCompetencia(competencia)}',
                                ),
                                _InfoChip(
                                  label:
                                      'Vencimento: ${widget.formatarData(vencimento)}',
                                ),
                                if (diaVencimento > 0)
                                  _InfoChip(label: 'Dia: $diaVencimento'),
                              ] else ...[
                                _InfoChip(
                                  label:
                                      'Data do serviço: ${widget.formatarData(dataServico)}',
                                ),
                              ],
                              _InfoChip(label: 'Quantidade: $quantidade'),
                              if (formaPagamento.trim().isNotEmpty)
                                _InfoChip(
                                  label:
                                      'Forma: ${widget.formatarFormaPagamento(formaPagamento)}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _ValorLinha(
                                label: 'Unitário',
                                value: widget.formatarValor(valorUnitario),
                              ),
                              _ValorLinha(
                                label: 'Base',
                                value: widget.formatarValor(valorBase),
                              ),
                              _ValorLinha(
                                label: 'Desconto',
                                value: widget.formatarValor(desconto),
                              ),
                              _ValorLinha(
                                label: 'Juros',
                                value: widget.formatarValor(juros),
                              ),
                              _ValorLinha(
                                label: 'Final',
                                value: widget.formatarValor(valorFinal),
                                color: VitalisColors.verdeEsmeralda,
                              ),
                            ],
                          ),
                        ],
                      );

                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: isWide
                            ? WrapAlignment.end
                            : WrapAlignment.start,
                        children: [
                          _ActionButton(
                            tooltip: 'Editar lançamento',
                            icon: Icons.edit_outlined,
                            color: VitalisColors.info,
                            onTap: () async {
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                useRootNavigator: true,
                                builder: (_) => CadastroMensalidadeDialog(
                                  role: widget.role,
                                  mensalidadeId: doc.id,
                                  dados: data,
                                ),
                              );
                            },
                          ),
                          if (status != 'pago')
                            _ActionButton(
                              tooltip: 'Registrar pagamento',
                              icon: Icons.check_circle_rounded,
                              color: VitalisColors.verdeEsmeralda,
                              onTap: () async {
                                await showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => RegistrarPagamentoDialog(
                                    mensalidadeId: doc.id,
                                    clienteId: clienteId,
                                    nomeCliente: widget.nomeCliente,
                                    nomeServico: nomeServico,
                                    valor: valorBase,
                                  ),
                                );
                              },
                            ),
                          if (widget.isAdmin)
                            _ActionButton(
                              tooltip: 'Excluir lançamento',
                              icon: Icons.delete_outline,
                              color: VitalisColors.erro,
                              onTap: () => widget.onExcluir(
                                mensalidadeId: doc.id,
                                nomeCliente: widget.nomeCliente,
                                nomeServico: nomeServico,
                              ),
                            ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: details),
                            const SizedBox(width: 14),
                            SizedBox(width: 150, child: actions),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      );
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusMiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusMiniChip({required this.label, required this.color});

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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ValorLinha extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ValorLinha({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VitalisColors.cinzaMedio,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ClienteOpcao {
  final String id;
  final String nome;
  final String telefone;
  final String cpf;

  const _ClienteOpcao({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.cpf,
  });

  @override
  String toString() => nome;
}

class _ServicoSelecionado {
  final String servicoId;
  final String nome;
  final double valorUnitario;
  final String tipoCobranca;
  int quantidade;

  _ServicoSelecionado({
    required this.servicoId,
    required this.nome,
    required this.valorUnitario,
    required this.tipoCobranca,
    this.quantidade = 1,
  });

  double get valorBase => valorUnitario * quantidade;
  bool get isMensalidade => tipoCobranca == 'mensalidade';
}

class CadastroMensalidadeDialog extends StatefulWidget {
  final String role;
  final String? mensalidadeId;
  final Map<String, dynamic>? dados;
  final String? clienteIdInicial;
  final String? nomeClienteInicial;

  const CadastroMensalidadeDialog({
    super.key,
    required this.role,
    this.mensalidadeId,
    this.dados,
    this.clienteIdInicial,
    this.nomeClienteInicial,
  });

  @override
  State<CadastroMensalidadeDialog> createState() =>
      _CadastroMensalidadeDialogState();
}

class _CadastroMensalidadeDialogState extends State<CadastroMensalidadeDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _competenciaController = TextEditingController();
  final TextEditingController _vencimentoController = TextEditingController();
  final TextEditingController _dataServicoController = TextEditingController();

  String? _clienteIdSelecionado;
  String? _nomeClienteSelecionado;

  String? _servicoIdSelecionado;
  String? _nomeServicoSelecionado;
  String _tipoCobrancaSelecionado = 'mensalidade';
  double _valorServicoSelecionado = 0.0;

  final List<_ServicoSelecionado> _servicos = [];

  int _quantidadeEdicao = 1;
  bool _ativa = true;

  bool _registrarPagamentoAgora = false;
  String _formaPagamento = 'pix';

  final _descontoController = TextEditingController(text: '0');
  final _jurosController = TextEditingController(text: '0');

  bool _loading = false;

  bool get isEdicao => widget.mensalidadeId != null;

  bool get _mensalidadePaga {
    final status = (widget.dados?['status'] ?? '').toString().toLowerCase();
    return status == 'pago';
  }

  bool get _selecaoAtualEhMensalidade =>
      _tipoCobrancaSelecionado == 'mensalidade';
  bool get _temMensalidadeNaLista => _servicos.any((s) => s.isMensalidade);
  bool get _temServicoAvulsoNaLista => _servicos.any((s) => !s.isMensalidade);

  bool get _mostrarCompetenciaEVencimento {
    if (isEdicao) return _selecaoAtualEhMensalidade;
    if (_servicos.isEmpty) return _selecaoAtualEhMensalidade;
    return _temMensalidadeNaLista;
  }

  bool get _mostrarDataServico {
    if (isEdicao) return !_selecaoAtualEhMensalidade;
    if (_servicos.isEmpty) return !_selecaoAtualEhMensalidade;
    return _temServicoAvulsoNaLista;
  }

  final List<String> _formasPagamento = const [
    'pix',
    'dinheiro',
    'cartao',
    'transferencia',
  ];

  @override
  void initState() {
    super.initState();

    final agora = DateTime.now();
    final vencimentoPadrao = DateTime(agora.year, agora.month, 10);

    _competenciaController.text = formatarCompetenciaParaCampo(
      MensalidadeService.gerarCompetencia(vencimentoPadrao),
    );
    _vencimentoController.text = formatarDataBrasileira(vencimentoPadrao);
    _dataServicoController.text = formatarDataBrasileira(agora);

    if (widget.clienteIdInicial != null &&
        widget.nomeClienteInicial != null &&
        !isEdicao) {
      _clienteIdSelecionado = widget.clienteIdInicial;
      _nomeClienteSelecionado = widget.nomeClienteInicial;
      _clienteController.text = widget.nomeClienteInicial!;
    }

    final d = widget.dados;
    if (d != null) {
      _clienteIdSelecionado = (d['clienteId'] ?? '').toString();
      _nomeClienteSelecionado = (d['nomeCliente'] ?? '').toString();
      _clienteController.text = _nomeClienteSelecionado ?? '';

      _servicoIdSelecionado = (d['servicoId'] ?? '').toString();
      _nomeServicoSelecionado = (d['nomeServico'] ?? '').toString();
      _tipoCobrancaSelecionado = (d['tipoCobranca'] ?? 'mensalidade')
          .toString();
      _valorServicoSelecionado = d['valorUnitario'] is num
          ? (d['valorUnitario'] as num).toDouble()
          : 0.0;

      _quantidadeEdicao = d['quantidade'] is num
          ? (d['quantidade'] as num).toInt()
          : 1;
      _ativa = d['ativa'] == true;

      final competencia = (d['competencia'] ?? '').toString();
      if (competencia.isNotEmpty) {
        _competenciaController.text = formatarCompetenciaParaCampo(competencia);
      }

      final vencimento = d['vencimento'];
      if (vencimento is Timestamp) {
        _vencimentoController.text = formatarDataBrasileira(
          vencimento.toDate(),
        );
      }

      final dataServico = d['dataServico'];
      if (dataServico is Timestamp) {
        _dataServicoController.text = formatarDataBrasileira(
          dataServico.toDate(),
        );
      }

      _formaPagamento = (d['formaPagamento'] ?? 'pix').toString();
      if (!_formasPagamento.contains(_formaPagamento)) {
        _formaPagamento = 'pix';
      }

      _descontoController.text = ((d['desconto'] ?? 0).toString()).replaceAll(
        '.',
        ',',
      );
      _jurosController.text = ((d['juros'] ?? 0).toString()).replaceAll(
        '.',
        ',',
      );
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _competenciaController.dispose();
    _vencimentoController.dispose();
    _dataServicoController.dispose();
    _descontoController.dispose();
    _jurosController.dispose();
    super.dispose();
  }

  double _parseValor(String texto) {
    final limpo = texto.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(limpo) ?? 0.0;
  }

  double get _desconto => _parseValor(_descontoController.text);
  double get _juros => _parseValor(_jurosController.text);

  double get _valorBase {
    if (isEdicao) return _valorServicoSelecionado * _quantidadeEdicao;
    return _servicos.fold(0.0, (soma, item) => soma + item.valorBase);
  }

  double get _valorFinalPreview {
    final total = _valorBase - _desconto + _juros;
    return total < 0 ? 0 : total;
  }

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatarTipoCobranca(String tipo) {
    switch (tipo) {
      case 'mensalidade':
        return 'Mensalidade';
      case 'avulso':
        return 'Avulso';
      case 'sessao':
        return 'Sessão';
      case 'aula_experimental':
        return 'Aula experimental';
      case 'outro':
        return 'Outro';
      default:
        return 'Mensalidade';
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _ordenarServicos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    docs.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final ativoA = dataA['ativo'] == true;
      final ativoB = dataB['ativo'] == true;

      if (ativoA != ativoB) return ativoA ? -1 : 1;

      final nomeA = normalizarTexto((dataA['nome'] ?? '').toString());
      final nomeB = normalizarTexto((dataB['nome'] ?? '').toString());

      return nomeA.compareTo(nomeB);
    });

    return docs;
  }

  void _adicionarServicoSelecionado() {
    if (_servicoIdSelecionado == null ||
        _nomeServicoSelecionado == null ||
        _valorServicoSelecionado <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um serviço válido.')),
      );
      return;
    }

    final indiceExistente = _servicos.indexWhere(
      (s) => s.servicoId == _servicoIdSelecionado,
    );

    setState(() {
      if (indiceExistente >= 0) {
        _servicos[indiceExistente].quantidade++;
      } else {
        _servicos.add(
          _ServicoSelecionado(
            servicoId: _servicoIdSelecionado!,
            nome: _nomeServicoSelecionado!,
            valorUnitario: _valorServicoSelecionado,
            tipoCobranca: _tipoCobrancaSelecionado,
            quantidade: 1,
          ),
        );
      }

      _servicoIdSelecionado = null;
      _nomeServicoSelecionado = null;
      _valorServicoSelecionado = 0.0;
      _tipoCobrancaSelecionado = 'mensalidade';
    });
  }

  Future<void> _abrirNovoCliente() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const CadastroClienteDialog(),
    );

    final ultimo = await FirebaseFirestore.instance
        .collection('clientes')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (ultimo.docs.isNotEmpty && mounted) {
      final doc = ultimo.docs.first;
      final data = doc.data();

      setState(() {
        _clienteIdSelecionado = doc.id;
        _nomeClienteSelecionado = (data['nome'] ?? 'Sem nome').toString();
        _clienteController.text = _nomeClienteSelecionado!;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clienteIdSelecionado == null || _nomeClienteSelecionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um cliente.')));
      return;
    }

    final precisaMensalidade = isEdicao
        ? _selecaoAtualEhMensalidade
        : _servicos.any((s) => s.isMensalidade);
    final precisaDataServico = isEdicao
        ? !_selecaoAtualEhMensalidade
        : _servicos.any((s) => !s.isMensalidade);

    final competencia = precisaMensalidade
        ? parseCompetenciaCampo(_competenciaController.text.trim())
        : null;
    final vencimento = precisaMensalidade
        ? parseDataBrasileira(_vencimentoController.text.trim())
        : null;
    final dataServico = precisaDataServico
        ? parseDataBrasileira(_dataServicoController.text.trim())
        : null;

    if (precisaMensalidade && competencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma competência válida.')),
      );
      return;
    }

    if (precisaMensalidade && vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um vencimento válido.')),
      );
      return;
    }

    if (precisaDataServico && dataServico == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma data do serviço válida.')),
      );
      return;
    }

    if (isEdicao) {
      if (_servicoIdSelecionado == null || _nomeServicoSelecionado == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selecione um serviço.')));
        return;
      }
    } else {
      if (_servicos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione pelo menos um serviço.')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    try {
      if (isEdicao) {
        final dataBaseServico = _selecaoAtualEhMensalidade
            ? vencimento!
            : dataServico!;
        final competenciaFinal = _selecaoAtualEhMensalidade
            ? competencia!
            : MensalidadeService.gerarCompetencia(dataBaseServico);

        await MensalidadeService.atualizarMensalidade(
          id: widget.mensalidadeId!,
          clienteId: _clienteIdSelecionado!,
          nomeCliente: _nomeClienteSelecionado!,
          servicoId: _servicoIdSelecionado!,
          nomeServico: _nomeServicoSelecionado!,
          valorUnitario: _valorServicoSelecionado,
          quantidade: _quantidadeEdicao,
          tipoCobranca: _tipoCobrancaSelecionado,
          competencia: competenciaFinal,
          dataServico: dataBaseServico,
          vencimento: _selecaoAtualEhMensalidade ? vencimento : null,
          ativa: _ativa,
          formaPagamento: _mensalidadePaga ? _formaPagamento : null,
          desconto: _mensalidadePaga ? _desconto : null,
          juros: _mensalidadePaga ? _juros : null,
        );
      } else {
        for (final servico in _servicos) {
          final isMensalidade = servico.isMensalidade;
          final dataBaseServico = isMensalidade ? vencimento! : dataServico!;
          final competenciaFinal = isMensalidade
              ? competencia!
              : MensalidadeService.gerarCompetencia(dataBaseServico);

          await MensalidadeService.criarMensalidade(
            clienteId: _clienteIdSelecionado!,
            nomeCliente: _nomeClienteSelecionado!,
            servicoId: servico.servicoId,
            nomeServico: servico.nome,
            valorUnitario: servico.valorUnitario,
            quantidade: servico.quantidade,
            tipoCobranca: servico.tipoCobranca,
            competenciaInicial: competenciaFinal,
            dataServico: dataBaseServico,
            vencimentoInicial: isMensalidade ? vencimento : null,
            registrarPagamentoAgora: _registrarPagamentoAgora,
            formaPagamento: _registrarPagamentoAgora ? _formaPagamento : null,
            descontoCadastro: _registrarPagamentoAgora ? _desconto : 0,
            jurosCadastro: _registrarPagamentoAgora ? _juros : 0,
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdicao
                ? 'Lançamento atualizado com sucesso.'
                : 'Lançamento(s) criado(s) com sucesso.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar lançamento: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdicao ? 'Editar lançamento' : 'Novo lançamento'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: MensalidadeService.listarClientes(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];

                    final clientes =
                        docs.map((doc) {
                          final data = doc.data();
                          return _ClienteOpcao(
                            id: doc.id,
                            nome: (data['nome'] ?? 'Sem nome').toString(),
                            telefone: (data['telefone'] ?? '').toString(),
                            cpf: (data['cpf'] ?? '').toString(),
                          );
                        }).toList()..sort(
                          (a, b) => normalizarTexto(
                            a.nome,
                          ).compareTo(normalizarTexto(b.nome)),
                        );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Autocomplete<_ClienteOpcao>(
                            initialValue: TextEditingValue(
                              text: _clienteController.text,
                            ),
                            optionsBuilder: (textEditingValue) {
                              final busca = normalizarTexto(
                                textEditingValue.text,
                              );
                              if (busca.isEmpty) return clientes;

                              return clientes.where((cliente) {
                                return normalizarTexto(
                                      cliente.nome,
                                    ).contains(busca) ||
                                    normalizarTexto(
                                      cliente.telefone,
                                    ).contains(busca) ||
                                    normalizarTexto(
                                      cliente.cpf,
                                    ).contains(busca);
                              });
                            },
                            displayStringForOption: (option) => option.nome,
                            onSelected: (option) {
                              setState(() {
                                _clienteIdSelecionado = option.id;
                                _nomeClienteSelecionado = option.nome;
                                _clienteController.text = option.nome;
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  if (_clienteController.text.isNotEmpty &&
                                      textEditingController.text !=
                                          _clienteController.text) {
                                    textEditingController.text =
                                        _clienteController.text;
                                  }

                                  textEditingController.addListener(() {
                                    _clienteController.text =
                                        textEditingController.text;
                                    if (textEditingController.text
                                        .trim()
                                        .isEmpty) {
                                      _clienteIdSelecionado = null;
                                      _nomeClienteSelecionado = null;
                                    }
                                  });

                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Cliente',
                                      hintText: 'Digite para pesquisar cliente',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    validator: (_) {
                                      if (_clienteIdSelecionado == null ||
                                          _nomeClienteSelecionado == null) {
                                        return 'Selecione um cliente.';
                                      }
                                      return null;
                                    },
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              final lista = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(14),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 340,
                                      maxHeight: 250,
                                    ),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shrinkWrap: true,
                                      itemCount: lista.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final item = lista[index];
                                        return ListTile(
                                          title: Text(item.nome),
                                          subtitle: Text(
                                            [
                                              if (item.telefone.isNotEmpty)
                                                item.telefone,
                                              if (item.cpf.isNotEmpty) item.cpf,
                                            ].join(' • '),
                                          ),
                                          onTap: () => onSelected(item),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _abrirNovoCliente,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Novo'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: MensalidadeService.listarServicos(),
                  builder: (context, snapshot) {
                    final docs =
                        _ordenarServicos((snapshot.data?.docs ?? []).toList())
                            .where(
                              (doc) =>
                                  doc.data()['ativo'] == true ||
                                  (isEdicao && doc.id == _servicoIdSelecionado),
                            )
                            .toList();

                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _servicoIdSelecionado,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isEdicao
                                ? 'Serviço'
                                : 'Serviço para adicionar',
                            prefixIcon: const Icon(
                              Icons.design_services_outlined,
                            ),
                          ),
                          items: docs.map((doc) {
                            final data = doc.data();
                            final nome = (data['nome'] ?? 'Sem nome')
                                .toString();
                            final valor = data['valor'] is num
                                ? (data['valor'] as num).toDouble()
                                : 0.0;
                            final tipo = (data['tipoCobranca'] ?? 'mensalidade')
                                .toString();

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                '$nome - ${_formatarValor(valor)} - ${_formatarTipoCobranca(tipo)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final doc = docs.firstWhere((d) => d.id == value);
                            final data = doc.data();

                            setState(() {
                              _servicoIdSelecionado = value;
                              _nomeServicoSelecionado =
                                  (data['nome'] ?? 'Sem nome').toString();
                              _valorServicoSelecionado = data['valor'] is num
                                  ? (data['valor'] as num).toDouble()
                                  : 0.0;
                              _tipoCobrancaSelecionado =
                                  (data['tipoCobranca'] ?? 'mensalidade')
                                      .toString();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _InfoChip(
                            label:
                                'Tipo selecionado: ${_formatarTipoCobranca(_tipoCobrancaSelecionado)}',
                          ),
                        ),
                        if (!isEdicao) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _adicionarServicoSelecionado,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar serviço'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_servicos.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Serviços adicionados',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: VitalisColors.azulMarinhoProfundo,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(_servicos.length, (index) {
                                    final servico = _servicos[index];

                                    return Container(
                                      margin: EdgeInsets.only(
                                        bottom: index == _servicos.length - 1
                                            ? 0
                                            : 8,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  servico.nome,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: VitalisColors
                                                        .azulMarinhoProfundo,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tipo: ${_formatarTipoCobranca(servico.tipoCobranca)}',
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Unitário: ${_formatarValor(servico.valorUnitario)}',
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Total: ${_formatarValor(servico.valorBase)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    if (servico.quantidade >
                                                        1) {
                                                      servico.quantidade--;
                                                    }
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                              ),
                                              Text(
                                                '${servico.quantidade}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () => setState(
                                                  () => servico.quantidade++,
                                                ),
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () => setState(
                                                  () =>
                                                      _servicos.removeAt(index),
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_mostrarCompetenciaEVencimento) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _competenciaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CompetenciaInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Competência',
                            hintText: 'MM/AAAA',
                            prefixIcon: Icon(Icons.date_range_outlined),
                          ),
                          validator: (value) {
                            if (_mostrarCompetenciaEVencimento &&
                                parseCompetenciaCampo(value ?? '') == null) {
                              return 'Competência inválida.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _vencimentoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            DataInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Vencimento',
                            hintText: 'DD/MM/AAAA',
                            prefixIcon: Icon(Icons.event_available_outlined),
                          ),
                          validator: (value) {
                            if (_mostrarCompetenciaEVencimento &&
                                parseDataBrasileira(value ?? '') == null) {
                              return 'Data inválida.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_mostrarDataServico) ...[
                  TextFormField(
                    controller: _dataServicoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      DataInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Data do serviço',
                      hintText: 'DD/MM/AAAA',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (value) {
                      if (_mostrarDataServico &&
                          parseDataBrasileira(value ?? '') == null) {
                        return 'Data inválida.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (isEdicao) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Quantidade: $_quantidadeEdicao',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: VitalisColors.azulMarinhoProfundo,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (_quantidadeEdicao > 1) _quantidadeEdicao--;
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantidadeEdicao++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isEdicao
                        ? 'Valor base: ${_formatarValor(_valorBase)}'
                        : 'Valor base total: ${_formatarValor(_valorBase)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: VitalisColors.azulMarinhoProfundo,
                    ),
                  ),
                ),
                if (isEdicao) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _ativa,
                    onChanged: (value) => setState(() => _ativa = value),
                    activeThumbColor: VitalisColors.verdeEsmeralda,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lançamento ativo'),
                  ),
                ],
                if (!isEdicao) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _registrarPagamentoAgora,
                    onChanged: (value) =>
                        setState(() => _registrarPagamentoAgora = value),
                    activeThumbColor: VitalisColors.verdeEsmeralda,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Registrar pagamento agora'),
                  ),
                ],
                if (_registrarPagamentoAgora || _mensalidadePaga) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descontoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Desconto',
                      prefixIcon: Icon(Icons.remove_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _jurosController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Juros',
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _formaPagamento,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    items: _formasPagamento
                        .map(
                          (forma) => DropdownMenuItem<String>(
                            value: forma,
                            child: Text(forma),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _formaPagamento = value);
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
                    child: Text(
                      'Valor final: ${_formatarValor(_valorFinalPreview)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.verdeEsmeralda,
                      ),
                    ),
                  ),
                ],
                if (isEdicao &&
                    !_mensalidadePaga &&
                    _selecaoAtualEhMensalidade) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Alterações feitas aqui também serão aplicadas às próximas mensalidades pendentes deste cliente e serviço.',
                    style: TextStyle(
                      color: VitalisColors.cinzaMedio,
                      fontSize: 12.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
              : Text(isEdicao ? 'Salvar alterações' : 'Salvar'),
        ),
      ],
    );
  }
}

class RegistrarPagamentoDialog extends StatefulWidget {
  final String mensalidadeId;
  final String clienteId;
  final String nomeCliente;
  final String nomeServico;
  final double valor;

  const RegistrarPagamentoDialog({
    super.key,
    required this.mensalidadeId,
    required this.clienteId,
    required this.nomeCliente,
    required this.nomeServico,
    required this.valor,
  });

  @override
  State<RegistrarPagamentoDialog> createState() =>
      _RegistrarPagamentoDialogState();
}

class _RegistrarPagamentoDialogState extends State<RegistrarPagamentoDialog> {
  String _formaPagamento = 'pix';
  bool _loading = false;

  final _descontoController = TextEditingController(text: '0');
  final _jurosController = TextEditingController(text: '0');

  final List<String> _formas = const [
    'pix',
    'dinheiro',
    'cartao',
    'transferencia',
  ];

  @override
  void dispose() {
    _descontoController.dispose();
    _jurosController.dispose();
    super.dispose();
  }

  double _parseValor(String texto) {
    final limpo = texto.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(limpo) ?? 0.0;
  }

  double get _desconto => _parseValor(_descontoController.text);
  double get _juros => _parseValor(_jurosController.text);

  double get _valorFinal {
    final total = widget.valor - _desconto + _juros;
    return total < 0 ? 0 : total;
  }

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _confirmarPagamento() async {
    setState(() => _loading = true);

    try {
      await MensalidadeService.registrarPagamento(
        mensalidadeId: widget.mensalidadeId,
        clienteId: widget.clienteId,
        nomeCliente: widget.nomeCliente,
        nomeServico: widget.nomeServico,
        valorOriginal: widget.valor,
        formaPagamento: _formaPagamento,
        desconto: _desconto,
        juros: _juros,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento registrado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar pagamento: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pagamento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nomeCliente,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.nomeServico),
                    const SizedBox(height: 8),
                    Text(
                      'Valor base: ${_formatarValor(widget.valor)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: VitalisColors.verdeEsmeralda,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descontoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Desconto',
                  prefixIcon: Icon(Icons.remove_circle_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jurosController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Juros',
                  prefixIcon: Icon(Icons.add_circle_outline),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _formaPagamento,
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
                  if (value != null) setState(() => _formaPagamento = value);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desconto: ${_formatarValor(_desconto)}'),
                    const SizedBox(height: 4),
                    Text('Juros: ${_formatarValor(_juros)}'),
                    const SizedBox(height: 8),
                    Text(
                      'Valor final: ${_formatarValor(_valorFinal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _confirmarPagamento,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}

class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CompetenciaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 6) digits = digits.substring(0, 6);

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

DateTime? parseDataBrasileira(String texto) {
  final partes = texto.split('/');
  if (partes.length != 3) return null;

  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final ano = int.tryParse(partes[2]);

  if (dia == null || mes == null || ano == null) return null;
  if (ano < 1900 || ano > 2100) return null;

  try {
    final data = DateTime(ano, mes, dia);
    if (data.day != dia || data.month != mes || data.year != ano) return null;
    return data;
  } catch (_) {
    return null;
  }
}

String? parseCompetenciaCampo(String texto) {
  final partes = texto.split('/');
  if (partes.length != 2) return null;

  final mes = int.tryParse(partes[0]);
  final ano = int.tryParse(partes[1]);

  if (mes == null || ano == null) return null;
  if (mes < 1 || mes > 12) return null;
  if (ano < 1900 || ano > 2100) return null;

  return '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}';
}

String formatarCompetenciaParaCampo(String competencia) {
  final partes = competencia.split('-');
  if (partes.length != 2) return competencia;
  return '${partes[1]}/${partes[0]}';
}

String formatarDataBrasileira(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

String normalizarTexto(String texto) {
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
