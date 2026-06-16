import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../widgets/app_shell.dart';

class ClientesPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const ClientesPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'funcionario',
    this.embedded = false,
  });

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _pesquisaController = TextEditingController();

  String _busca = '';
  bool _somenteCadastrosIncompletos = false;

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

  String _formatarData(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return formatarDataBrasileira(timestamp.toDate());
  }

  Future<void> _abrirWhatsApp(String telefone) async {
    final numero = telefone.replaceAll(RegExp(r'\D'), '');
    if (numero.isEmpty) return;

    final numeroFinal = numero.startsWith('55') ? numero : '55$numero';
    final uri = Uri.parse('https://wa.me/$numeroFinal');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return VitalisColors.sucesso;
      case 'vencendo':
        return VitalisColors.alerta;
      case 'vencido':
        return VitalisColors.erro;
      case 'inativo':
        return VitalisColors.cinzaMedio;
      default:
        return VitalisColors.cinzaMedio;
    }
  }

  String _montarEndereco(Map<String, dynamic> data) {
    final logradouro = (data['logradouro'] ?? '').toString();
    final numero = (data['numero'] ?? '').toString();
    final bairro = (data['bairro'] ?? '').toString();
    final cidade = (data['cidade'] ?? '').toString();
    final uf = (data['uf'] ?? '').toString();

    final partes = <String>[];

    if (logradouro.isNotEmpty) {
      partes.add(numero.isNotEmpty ? '$logradouro, $numero' : logradouro);
    }

    if (bairro.isNotEmpty) partes.add(bairro);

    final cidadeUf = [
      if (cidade.isNotEmpty) cidade,
      if (uf.isNotEmpty) uf,
    ].join(' - ');

    if (cidadeUf.isNotEmpty) partes.add(cidadeUf);

    return partes.isEmpty ? 'Endereço não informado' : partes.join(' • ');
  }

  bool _clientePassaFiltro(Map<String, dynamic> data) {
    if (_somenteCadastrosIncompletos && !_cadastroIncompleto(data)) {
      return false;
    }

    if (_busca.trim().isEmpty) return true;

    final busca = normalizarTexto(_busca);

    final nome = normalizarTexto((data['nome'] ?? '').toString());
    final telefone = normalizarTexto((data['telefone'] ?? '').toString());
    final cpf = normalizarTexto(formatarCpf((data['cpf'] ?? '').toString()));
    final cpfSemMascara = normalizarTexto((data['cpf'] ?? '').toString());
    final nomeCrianca = normalizarTexto((data['nomeCrianca'] ?? '').toString());
    final categoria = normalizarTexto((data['categoria'] ?? '').toString());
    final status = normalizarTexto((data['status'] ?? '').toString());

    return nome.contains(busca) ||
        telefone.contains(busca) ||
        cpf.contains(busca) ||
        cpfSemMascara.contains(busca) ||
        nomeCrianca.contains(busca) ||
        categoria.contains(busca) ||
        status.contains(busca);
  }

  bool _cadastroIncompleto(Map<String, dynamic> data) {
    final nome = (data['nome'] ?? '').toString().trim();
    final telefone = (data['telefone'] ?? '').toString().trim();
    final categoria = (data['categoria'] ?? '').toString().trim();
    final status = (data['status'] ?? '').toString().trim();
    final cpf = apenasDigitos((data['cpf'] ?? '').toString());

    final cep = (data['cep'] ?? '').toString().trim();
    final logradouro = (data['logradouro'] ?? '').toString().trim();
    final numero = (data['numero'] ?? '').toString().trim();
    final bairro = (data['bairro'] ?? '').toString().trim();
    final cidade = (data['cidade'] ?? '').toString().trim();
    final uf = (data['uf'] ?? '').toString().trim();

    final clienteNatacao = data['clienteNatacao'] == true;
    final nomeCrianca = (data['nomeCrianca'] ?? '').toString().trim();
    final nascimentoCrianca = data['dataNascimentoCrianca'];

    final dadosBasicosIncompletos =
        nome.isEmpty ||
        telefone.isEmpty ||
        categoria.isEmpty ||
        status.isEmpty ||
        cpf.isEmpty;

    final enderecoIncompleto =
        cep.isEmpty ||
        logradouro.isEmpty ||
        numero.isEmpty ||
        bairro.isEmpty ||
        cidade.isEmpty ||
        uf.isEmpty;

    final natacaoIncompleta =
        clienteNatacao &&
        (nomeCrianca.isEmpty || nascimentoCrianca is! Timestamp);

    return dadosBasicosIncompletos || enderecoIncompleto || natacaoIncompleta;
  }

  DateTime? _dataAniversarioConsiderada(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'inativo') return null;

    final clienteNatacao = data['clienteNatacao'] == true;

    if (clienteNatacao) {
      final crianca = data['dataNascimentoCrianca'];
      if (crianca is Timestamp) return crianca.toDate();
      return null;
    }

    final cliente = data['dataNascimentoCliente'];
    if (cliente is Timestamp) return cliente.toDate();

    return null;
  }

  String _nomeAniversariante(Map<String, dynamic> data) {
    final clienteNatacao = data['clienteNatacao'] == true;

    if (clienteNatacao) {
      final nomeCrianca = (data['nomeCrianca'] ?? '').toString().trim();
      if (nomeCrianca.isNotEmpty) return nomeCrianca;
    }

    return (data['nome'] ?? 'Cliente').toString();
  }

  Future<void> _abrirCadastroCliente() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CadastroClienteDialog(),
    );
  }

  Widget _resumoClienteCard({
    required String titulo,
    required String valor,
    required IconData icon,
    required Color cor,
  }) {
    return Container(
      width: 210,
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
                const SizedBox(height: 4),
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
              ],
            ),
          ),
        ],
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
      title: 'Clientes',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'clientes',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VitalisColors.verdeEsmeralda,
        foregroundColor: Colors.white,
        onPressed: _abrirCadastroCliente,
        icon: const Icon(Icons.add),
        label: const Text('Novo cliente'),
      ),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.embedded)
            Container(
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
                      Icons.people_alt_rounded,
                      color: VitalisColors.verdeEsmeralda,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestão de clientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: VitalisColors.azulMarinhoProfundo,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Cadastre, pesquise e acompanhe seus clientes.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: VitalisColors.cinzaMedio),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: VitalisColors.borda),
            ),
            child: TextField(
              controller: _pesquisaController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Pesquisar nome, telefone, CPF ou criança',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _pesquisaController.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              selected: _somenteCadastrosIncompletos,
              label: const Text('Cadastros incompletos'),
              avatar: Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: _somenteCadastrosIncompletos
                    ? VitalisColors.alerta
                    : VitalisColors.cinzaMedio,
              ),
              selectedColor: VitalisColors.alerta.withOpacity(0.14),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _somenteCadastrosIncompletos
                    ? VitalisColors.alerta
                    : VitalisColors.borda,
              ),
              labelStyle: TextStyle(
                color: _somenteCadastrosIncompletos
                    ? VitalisColors.alerta
                    : VitalisColors.cinzaEscuro,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (value) {
                setState(() {
                  _somenteCadastrosIncompletos = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ClienteService.listarClientes(),
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
                      'Erro ao carregar clientes.',
                      style: TextStyle(
                        color: VitalisColors.azulMarinhoProfundo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final ordenados = docs.toList()
                  ..sort((a, b) {
                    final nomeA = normalizarTexto(
                      (a.data()['nome'] ?? '').toString(),
                    );
                    final nomeB = normalizarTexto(
                      (b.data()['nome'] ?? '').toString(),
                    );
                    return nomeA.compareTo(nomeB);
                  });

                final filtrados = ordenados
                    .where((doc) => _clientePassaFiltro(doc.data()))
                    .toList();

                final ativos = docs.where((doc) {
                  final status = (doc.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  return status == 'ativo';
                }).length;

                final inativos = docs.where((doc) {
                  final status = (doc.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  return status == 'inativo';
                }).length;

                final natacao = docs.where((doc) {
                  return doc.data()['clienteNatacao'] == true;
                }).length;

                final incompletos = docs.where((doc) {
                  return _cadastroIncompleto(doc.data());
                }).length;

                final resumoCards = [
                  _resumoClienteCard(
                    titulo: 'Total',
                    valor: docs.length.toString(),
                    icon: Icons.people_alt_rounded,
                    cor: VitalisColors.azulMarinhoProfundo,
                  ),
                  _resumoClienteCard(
                    titulo: 'Encontrados',
                    valor: filtrados.length.toString(),
                    icon: Icons.search_rounded,
                    cor: VitalisColors.info,
                  ),
                  _resumoClienteCard(
                    titulo: 'Ativos',
                    valor: ativos.toString(),
                    icon: Icons.verified_rounded,
                    cor: VitalisColors.sucesso,
                  ),
                  _resumoClienteCard(
                    titulo: 'Natação',
                    valor: natacao.toString(),
                    icon: Icons.pool_rounded,
                    cor: VitalisColors.verdeEsmeralda,
                  ),
                  _resumoClienteCard(
                    titulo: 'Incompletos',
                    valor: incompletos.toString(),
                    icon: Icons.error_outline_rounded,
                    cor: VitalisColors.alerta,
                  ),
                  _resumoClienteCard(
                    titulo: 'Inativos',
                    valor: inativos.toString(),
                    icon: Icons.block_rounded,
                    cor: VitalisColors.cinzaMedio,
                  ),
                ];

                return Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: resumoCards.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, index) => resumoCards[index],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtrados.isEmpty
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
                                      'Nenhum cliente encontrado.',
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
                              itemCount: filtrados.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final doc = filtrados[i];
                                final data = doc.data();

                                final nome = (data['nome'] ?? 'Sem nome')
                                    .toString();
                                final telefone = (data['telefone'] ?? '')
                                    .toString();
                                final categoria = (data['categoria'] ?? '-')
                                    .toString();
                                final status = (data['status'] ?? '-')
                                    .toString();
                                final clienteNatacao =
                                    data['clienteNatacao'] == true;
                                final nomeCrianca = (data['nomeCrianca'] ?? '')
                                    .toString();
                                final dataNascimentoCliente =
                                    data['dataNascimentoCliente'] as Timestamp?;
                                final dataNascimentoCrianca =
                                    data['dataNascimentoCrianca'] as Timestamp?;
                                final cpf = formatarCpf(
                                  (data['cpf'] ?? '').toString(),
                                );

                                final dataAniversario =
                                    _dataAniversarioConsiderada(data);
                                final nomeAniversariante = _nomeAniversariante(
                                  data,
                                );

                                final aniversarioProximo =
                                    dataAniversario != null &&
                                    isAniversarioProximo(dataAniversario);

                                final receberAniversario =
                                    data['receberMensagemAniversario'] != false;

                                final receberCobranca =
                                    data['receberMensagemCobranca'] != false;

                                final corStatus = _corStatus(status);
                                final incompleto = _cadastroIncompleto(data);

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth >= 650;

                                        final infoCliente = Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 42,
                                                  height: 42,
                                                  decoration: BoxDecoration(
                                                    color: corStatus
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    clienteNatacao
                                                        ? Icons.pool_rounded
                                                        : Icons.person_rounded,
                                                    color: corStatus,
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        nome,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: VitalisColors
                                                              .azulMarinhoProfundo,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 6,
                                                        children: [
                                                          _ClienteChip(
                                                            texto: status,
                                                            cor: corStatus,
                                                          ),
                                                          _ClienteChip(
                                                            texto: categoria,
                                                            cor: VitalisColors
                                                                .info,
                                                          ),
                                                          if (clienteNatacao)
                                                            const _ClienteChip(
                                                              texto: 'Natação',
                                                              cor: VitalisColors
                                                                  .verdeEsmeralda,
                                                            ),
                                                          if (incompleto)
                                                            const _ClienteChip(
                                                              texto:
                                                                  'Cadastro incompleto',
                                                              cor: VitalisColors
                                                                  .alerta,
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _ClienteInfoChip(
                                                  icon: Icons.phone_outlined,
                                                  texto: telefone.isEmpty
                                                      ? 'Sem telefone'
                                                      : telefone,
                                                  cor: telefone.isEmpty
                                                      ? VitalisColors.alerta
                                                      : null,
                                                ),
                                                _ClienteInfoChip(
                                                  icon: Icons.badge_outlined,
                                                  texto: cpf.isEmpty
                                                      ? 'CPF não informado'
                                                      : cpf,
                                                  cor: cpf.isEmpty
                                                      ? VitalisColors.alerta
                                                      : null,
                                                ),
                                                _ClienteInfoChip(
                                                  icon: Icons.cake_outlined,
                                                  texto:
                                                      'Nasc.: ${_formatarData(dataNascimentoCliente)}',
                                                ),
                                                _ClienteInfoChip(
                                                  icon: receberAniversario
                                                      ? Icons.cake_rounded
                                                      : Icons.cake_outlined,
                                                  texto: receberAniversario
                                                      ? 'Recebe aniversário'
                                                      : 'Sem aniversário',
                                                  cor: receberAniversario
                                                      ? VitalisColors
                                                            .verdeEsmeralda
                                                      : VitalisColors
                                                            .cinzaMedio,
                                                ),
                                                _ClienteInfoChip(
                                                  icon: receberCobranca
                                                      ? Icons.chat_outlined
                                                      : Icons
                                                            .chat_bubble_outline,
                                                  texto: receberCobranca
                                                      ? 'Recebe cobrança'
                                                      : 'Sem cobrança',
                                                  cor: receberCobranca
                                                      ? VitalisColors
                                                            .verdeEsmeralda
                                                      : VitalisColors
                                                            .cinzaMedio,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _montarEndereco(data),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: VitalisColors.cinzaMedio,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            _InicioServicosCliente(
                                              clienteId: doc.id,
                                            ),
                                            if (clienteNatacao &&
                                                nomeCrianca
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: VitalisColors
                                                      .verdeEsmeralda
                                                      .withOpacity(0.07),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: VitalisColors
                                                        .verdeEsmeralda
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    _ClienteInfoChip(
                                                      icon: Icons
                                                          .child_care_outlined,
                                                      texto:
                                                          'Criança: $nomeCrianca',
                                                      cor: VitalisColors
                                                          .verdeEsmeralda,
                                                    ),
                                                    _ClienteInfoChip(
                                                      icon: Icons.cake_outlined,
                                                      texto:
                                                          'Nasc.: ${_formatarData(dataNascimentoCrianca)}',
                                                      cor: VitalisColors
                                                          .verdeEsmeralda,
                                                    ),
                                                    if (dataNascimentoCrianca !=
                                                        null)
                                                      _ClienteInfoChip(
                                                        icon: Icons
                                                            .numbers_outlined,
                                                        texto:
                                                            '${calcularIdade(dataNascimentoCrianca.toDate())} ano(s)',
                                                        cor: VitalisColors
                                                            .verdeEsmeralda,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            if (aniversarioProximo &&
                                                receberAniversario) ...[
                                              const SizedBox(height: 8),
                                              _ClienteChip(
                                                texto:
                                                    'Aniversário próximo: $nomeAniversariante 🎂',
                                                cor: VitalisColors.alerta,
                                              ),
                                            ],
                                          ],
                                        );

                                        final acoes = Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: isWide
                                              ? WrapAlignment.end
                                              : WrapAlignment.start,
                                          children: [
                                            _ClienteActionButton(
                                              tooltip: 'Editar cliente',
                                              icon: Icons.edit_outlined,
                                              color: VitalisColors.info,
                                              onTap: () async {
                                                await showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) =>
                                                      CadastroClienteDialog(
                                                        clienteId: doc.id,
                                                        dados: data,
                                                      ),
                                                );
                                              },
                                            ),
                                            _ClienteActionButton(
                                              tooltip: 'WhatsApp',
                                              icon: Icons.chat_rounded,
                                              color:
                                                  VitalisColors.verdeEsmeralda,
                                              onTap: telefone.trim().isEmpty
                                                  ? null
                                                  : () => _abrirWhatsApp(
                                                      telefone,
                                                    ),
                                            ),
                                          ],
                                        );

                                        if (isWide) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: infoCliente),
                                              const SizedBox(width: 14),
                                              SizedBox(
                                                width: 100,
                                                child: acoes,
                                              ),
                                            ],
                                          );
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            infoCliente,
                                            const SizedBox(height: 12),
                                            acoes,
                                          ],
                                        );
                                      },
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
          ),
        ],
      ),
    );
  }
}

class _ClienteChip extends StatelessWidget {
  final String texto;
  final Color cor;

  const _ClienteChip({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withOpacity(0.12)),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _ClienteInfoChip extends StatelessWidget {
  final String texto;
  final IconData icon;
  final Color? cor;

  const _ClienteInfoChip({required this.texto, required this.icon, this.cor});

  @override
  Widget build(BuildContext context) {
    final chipColor = cor ?? VitalisColors.cinzaMedio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InicioServicosCliente extends StatelessWidget {
  final String clienteId;

  const _InicioServicosCliente({required this.clienteId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mensalidades')
          .where('clienteId', isEqualTo: clienteId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final inicios = <String, _InicioServico>{};
        for (final doc in snapshot.data?.docs ?? const []) {
          final data = doc.data();
          final tipoCobranca = (data['tipoCobranca'] ?? 'mensalidade')
              .toString()
              .toLowerCase();
          final vencimento = data['vencimento'];
          if (tipoCobranca != 'mensalidade' || vencimento is! Timestamp) {
            continue;
          }

          final servicoId = (data['servicoId'] ?? '').toString().trim();
          final nomeServico = (data['nomeServico'] ?? 'Serviço').toString();
          final chave = servicoId.isNotEmpty
              ? servicoId
              : normalizarTexto(nomeServico);
          final dataVencimento = vencimento.toDate();
          final atual = inicios[chave];

          if (atual == null || dataVencimento.isBefore(atual.data)) {
            inicios[chave] = _InicioServico(
              nome: nomeServico,
              data: dataVencimento,
            );
          }
        }

        final servicos = inicios.values.toList()
          ..sort((a, b) => a.data.compareTo(b.data));

        if (servicos.isEmpty) {
          return const Text(
            'Início dos serviços: nenhuma mensalidade cadastrada',
            style: TextStyle(
              color: VitalisColors.cinzaMedio,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Início dos serviços',
              style: TextStyle(
                color: VitalisColors.azulMarinhoProfundo,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: servicos
                  .map(
                    (servico) => _ClienteInfoChip(
                      icon: Icons.event_available_outlined,
                      texto:
                          '${servico.nome}: ${formatarDataBrasileira(servico.data)}',
                      cor: VitalisColors.verdeEsmeralda,
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _InicioServico {
  final String nome;
  final DateTime data;

  const _InicioServico({required this.nome, required this.data});
}

class _ClienteActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ClienteActionButton({
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
        color: onTap == null
            ? VitalisColors.cinzaMedio.withOpacity(0.08)
            : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: onTap == null ? VitalisColors.cinzaMedio : color,
            ),
          ),
        ),
      ),
    );
  }
}

class CadastroClienteDialog extends StatefulWidget {
  final String? clienteId;
  final Map<String, dynamic>? dados;

  const CadastroClienteDialog({super.key, this.clienteId, this.dados});

  @override
  State<CadastroClienteDialog> createState() => _CadastroClienteDialogState();
}

class _CadastroClienteDialogState extends State<CadastroClienteDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _observacoesController = TextEditingController();

  final _dataNascimentoClienteController = TextEditingController();

  final _nomeCriancaController = TextEditingController();
  final _dataNascimentoCriancaController = TextEditingController();

  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();

  String _categoria = 'mensalista';
  String _status = 'ativo';

  bool _clienteNatacao = false;
  bool _receberMensagemAniversario = true;
  bool _receberMensagemCobranca = true;

  bool _loading = false;
  bool _buscandoCep = false;

  DateTime? _dataNascimentoCliente;
  DateTime? _dataNascimentoCrianca;

  String? _cpfErro;

  bool get isEdicao => widget.clienteId != null;

  bool get _cpfVisualmenteValido =>
      _cpfController.text.trim().isNotEmpty &&
      _cpfErro == null &&
      apenasDigitos(_cpfController.text).length == 11;

  final List<String> _categorias = const ['mensalista', 'paciente', 'avulso'];

  final List<String> _statusDisponiveis = const [
    'ativo',
    'vencendo',
    'vencido',
    'inativo',
  ];

  @override
  void initState() {
    super.initState();

    final d = widget.dados;
    if (d != null) {
      _nomeController.text = (d['nome'] ?? '').toString();
      _telefoneController.text = (d['telefone'] ?? '').toString();
      _cpfController.text = formatarCpf((d['cpf'] ?? '').toString());
      _observacoesController.text = (d['observacoes'] ?? '').toString();

      _categoria = (d['categoria'] ?? 'mensalista').toString();
      _status = (d['status'] ?? 'ativo').toString();

      _clienteNatacao = d['clienteNatacao'] == true;
      _receberMensagemAniversario = d['receberMensagemAniversario'] != false;
      _receberMensagemCobranca = d['receberMensagemCobranca'] != false;

      final nascimentoCliente = d['dataNascimentoCliente'];
      if (nascimentoCliente is Timestamp) {
        _dataNascimentoCliente = nascimentoCliente.toDate();
        _dataNascimentoClienteController.text = formatarDataBrasileira(
          _dataNascimentoCliente!,
        );
      }

      _nomeCriancaController.text = (d['nomeCrianca'] ?? '').toString();

      final nascimentoCrianca = d['dataNascimentoCrianca'];
      if (nascimentoCrianca is Timestamp) {
        _dataNascimentoCrianca = nascimentoCrianca.toDate();
        _dataNascimentoCriancaController.text = formatarDataBrasileira(
          _dataNascimentoCrianca!,
        );
      }

      _cepController.text = (d['cep'] ?? '').toString();
      _logradouroController.text = (d['logradouro'] ?? '').toString();
      _numeroController.text = (d['numero'] ?? '').toString();
      _complementoController.text = (d['complemento'] ?? '').toString();
      _bairroController.text = (d['bairro'] ?? '').toString();
      _cidadeController.text = (d['cidade'] ?? '').toString();
      _ufController.text = (d['uf'] ?? '').toString();

      _validarCpfEmTempoReal(_cpfController.text);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _observacoesController.dispose();

    _dataNascimentoClienteController.dispose();

    _nomeCriancaController.dispose();
    _dataNascimentoCriancaController.dispose();

    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();

    super.dispose();
  }

  void _validarCpfEmTempoReal(String valor) {
    final cpf = valor.trim();

    if (cpf.isEmpty) {
      setState(() => _cpfErro = null);
      return;
    }

    if (apenasDigitos(cpf).length < 11) {
      setState(() => _cpfErro = 'CPF incompleto');
      return;
    }

    if (!cpfValido(cpf)) {
      setState(() => _cpfErro = 'CPF inválido');
      return;
    }

    setState(() => _cpfErro = null);
  }

  OutlineInputBorder _cpfBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.6),
    );
  }

  Future<void> _buscarCep() async {
    final cepLimpo = _cepController.text.replaceAll(RegExp(r'\D'), '');

    if (cepLimpo.length != 8) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um CEP com 8 dígitos.')),
      );
      return;
    }

    setState(() => _buscandoCep = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Erro ao consultar CEP.');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['erro'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CEP não encontrado.')));
        return;
      }

      setState(() {
        _cepController.text = (data['cep'] ?? '').toString();
        _logradouroController.text = (data['logradouro'] ?? '').toString();
        _bairroController.text = (data['bairro'] ?? '').toString();
        _cidadeController.text = (data['localidade'] ?? '').toString();
        _ufController.text = (data['uf'] ?? '').toString();

        if (_complementoController.text.trim().isEmpty) {
          _complementoController.text = (data['complemento'] ?? '').toString();
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível buscar o CEP.')),
      );
    } finally {
      if (mounted) {
        setState(() => _buscandoCep = false);
      }
    }
  }

  Future<bool> _cpfJaCadastrado(String cpfLimpo) async {
    if (cpfLimpo.isEmpty) return false;

    final snap = await FirebaseFirestore.instance
        .collection('clientes')
        .where('cpf', isEqualTo: cpfLimpo)
        .get();

    if (snap.docs.isEmpty) return false;

    if (isEdicao) {
      return snap.docs.any((doc) => doc.id != widget.clienteId);
    }

    return true;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final cpfLimpo = apenasDigitos(_cpfController.text);

    setState(() => _loading = true);

    try {
      final cpfDuplicado = await _cpfJaCadastrado(cpfLimpo);

      if (cpfDuplicado) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Já existe um cliente com esse CPF.')),
        );
        setState(() => _loading = false);
        return;
      }

      final nascimentoCliente =
          _dataNascimentoClienteController.text.trim().isEmpty
          ? null
          : parseDataBrasileira(_dataNascimentoClienteController.text.trim());

      final nascimentoCrianca =
          !_clienteNatacao ||
              _dataNascimentoCriancaController.text.trim().isEmpty
          ? null
          : parseDataBrasileira(_dataNascimentoCriancaController.text.trim());

      if (isEdicao) {
        await ClienteService.atualizarCliente(
          id: widget.clienteId!,
          nome: _nomeController.text,
          telefone: _telefoneController.text,
          cpf: cpfLimpo,
          categoria: _categoria,
          status: _status,
          observacoes: _observacoesController.text,
          clienteNatacao: _clienteNatacao,
          receberMensagemAniversario: _receberMensagemAniversario,
          receberMensagemCobranca: _receberMensagemCobranca,
          dataNascimentoCliente: nascimentoCliente,
          nomeCrianca: _clienteNatacao ? _nomeCriancaController.text : null,
          dataNascimentoCrianca: nascimentoCrianca,
          cep: _cepController.text,
          logradouro: _logradouroController.text,
          numero: _numeroController.text,
          complemento: _complementoController.text,
          bairro: _bairroController.text,
          cidade: _cidadeController.text,
          uf: _ufController.text,
        );
      } else {
        await ClienteService.criarCliente(
          nome: _nomeController.text,
          telefone: _telefoneController.text,
          cpf: cpfLimpo,
          categoria: _categoria,
          status: _status,
          observacoes: _observacoesController.text,
          clienteNatacao: _clienteNatacao,
          receberMensagemAniversario: _receberMensagemAniversario,
          receberMensagemCobranca: _receberMensagemCobranca,
          dataNascimentoCliente: nascimentoCliente,
          nomeCrianca: _clienteNatacao ? _nomeCriancaController.text : null,
          dataNascimentoCrianca: nascimentoCrianca,
          cep: _cepController.text,
          logradouro: _logradouroController.text,
          numero: _numeroController.text,
          complemento: _complementoController.text,
          bairro: _bairroController.text,
          cidade: _cidadeController.text,
          uf: _ufController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdicao
                ? 'Cliente atualizado com sucesso.'
                : 'Cliente cadastrado com sucesso.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar cliente.')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final idadeCliente = _dataNascimentoCliente == null
        ? null
        : calcularIdade(_dataNascimentoCliente!);

    final idadeCrianca = _dataNascimentoCrianca == null
        ? null
        : calcularIdade(_dataNascimentoCrianca!);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 820),
          child: Material(
            color: VitalisColors.offWhite,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEdicao ? 'Editar cliente' : 'Novo cliente',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: VitalisColors.azulMarinhoProfundo,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _nomeController,
                              decoration: const InputDecoration(
                                labelText: 'Nome',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe o nome do cliente.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _telefoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _cpfController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CpfInputFormatter(),
                              ],
                              onChanged: _validarCpfEmTempoReal,
                              autovalidateMode: AutovalidateMode.always,
                              decoration: InputDecoration(
                                labelText: 'CPF (opcional)',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                errorText: _cpfErro,
                                suffixIcon: _cpfController.text.trim().isEmpty
                                    ? null
                                    : Icon(
                                        _cpfVisualmenteValido
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: _cpfVisualmenteValido
                                            ? VitalisColors.sucesso
                                            : VitalisColors.erro,
                                      ),
                                enabledBorder:
                                    _cpfController.text.trim().isEmpty
                                    ? null
                                    : _cpfBorder(
                                        _cpfVisualmenteValido
                                            ? VitalisColors.sucesso
                                            : VitalisColors.erro,
                                      ),
                                focusedBorder:
                                    _cpfController.text.trim().isEmpty
                                    ? null
                                    : _cpfBorder(
                                        _cpfVisualmenteValido
                                            ? VitalisColors.sucesso
                                            : VitalisColors.erro,
                                      ),
                              ),
                              validator: (value) {
                                final cpf = apenasDigitos(value ?? '');

                                if (cpf.isEmpty) return null;

                                if (!cpfValido(cpf)) {
                                  return 'CPF inválido';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _dataNascimentoClienteController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                DataInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Data de nascimento do cliente',
                                hintText: 'DD/MM/AAAA',
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _dataNascimentoCliente = parseDataBrasileira(
                                    value,
                                  );
                                });
                              },
                              validator: (value) {
                                final texto = value?.trim() ?? '';
                                if (texto.isEmpty) return null;

                                final data = parseDataBrasileira(texto);
                                if (data == null) return 'Data inválida';

                                return null;
                              },
                            ),
                            if (_dataNascimentoCliente != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Idade do cliente: ${idadeCliente ?? 0} ano(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: VitalisColors.azulMarinhoProfundo,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _categoria,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: _categorias
                                  .map(
                                    (categoria) => DropdownMenuItem<String>(
                                      value: categoria,
                                      child: Text(categoria),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _categoria = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                              items: _statusDisponiveis
                                  .map(
                                    (status) => DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _status = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _clienteNatacao,
                              onChanged: (value) {
                                setState(() {
                                  _clienteNatacao = value ?? false;
                                  if (!_clienteNatacao) {
                                    _nomeCriancaController.clear();
                                    _dataNascimentoCriancaController.clear();
                                    _dataNascimentoCrianca = null;
                                  }
                                });
                              },
                              title: const Text('Natação'),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: VitalisColors.verdeEsmeralda,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (_clienteNatacao) ...[
                              const SizedBox(height: 12),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Dados da criança',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: VitalisColors.azulMarinhoProfundo,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _nomeCriancaController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome da criança',
                                  prefixIcon: Icon(Icons.child_care_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _dataNascimentoCriancaController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  DataInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Data de nascimento da criança',
                                  hintText: 'DD/MM/AAAA',
                                  prefixIcon: Icon(Icons.cake_outlined),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _dataNascimentoCrianca =
                                        parseDataBrasileira(value);
                                  });
                                },
                                validator: (value) {
                                  final texto = value?.trim() ?? '';
                                  if (texto.isEmpty) return null;

                                  final data = parseDataBrasileira(texto);
                                  if (data == null) return 'Data inválida';

                                  return null;
                                },
                              ),
                              if (_dataNascimentoCrianca != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Idade da criança: ${idadeCrianca ?? 0} ano(s)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: VitalisColors.azulMarinhoProfundo,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _dataNascimentoCrianca = null;
                                        _dataNascimentoCriancaController
                                            .clear();
                                      });
                                    },
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Limpar data'),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _receberMensagemAniversario,
                              onChanged: (value) {
                                setState(() {
                                  _receberMensagemAniversario = value ?? true;
                                });
                              },
                              title: const Text(
                                'Receber mensagem de aniversário',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: VitalisColors.verdeEsmeralda,
                              contentPadding: EdgeInsets.zero,
                            ),
                            CheckboxListTile(
                              value: _receberMensagemCobranca,
                              onChanged: (value) {
                                setState(() {
                                  _receberMensagemCobranca = value ?? true;
                                });
                              },
                              title: const Text('Receber mensagem de cobrança'),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: VitalisColors.verdeEsmeralda,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Endereço',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: VitalisColors.azulMarinhoProfundo,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cepController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'CEP',
                                      prefixIcon: Icon(
                                        Icons.markunread_mailbox_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 140,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _buscandoCep ? null : _buscarCep,
                                    child: _buscandoCep
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Buscar CEP'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _logradouroController,
                              decoration: const InputDecoration(
                                labelText: 'Logradouro',
                                prefixIcon: Icon(Icons.home_work_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _numeroController,
                              decoration: const InputDecoration(
                                labelText: 'Número',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _complementoController,
                              decoration: const InputDecoration(
                                labelText: 'Complemento',
                                prefixIcon: Icon(Icons.add_home_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bairroController,
                              decoration: const InputDecoration(
                                labelText: 'Bairro',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _cidadeController,
                              decoration: const InputDecoration(
                                labelText: 'Cidade',
                                prefixIcon: Icon(Icons.apartment_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ufController,
                              decoration: const InputDecoration(
                                labelText: 'UF',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _observacoesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Observações',
                                prefixIcon: Icon(Icons.notes_outlined),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      } else if (i == 9) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String apenasDigitos(String valor) {
  return valor.replaceAll(RegExp(r'[^0-9]'), '');
}

String formatarCpf(String cpf) {
  final digits = apenasDigitos(cpf);

  if (digits.isEmpty) return '';

  final buffer = StringBuffer();

  for (int i = 0; i < digits.length && i < 11; i++) {
    if (i == 3 || i == 6) {
      buffer.write('.');
    } else if (i == 9) {
      buffer.write('-');
    }
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

bool cpfValido(String cpf) {
  final digits = apenasDigitos(cpf);

  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

  int calcularDigito(String base, int pesoInicial) {
    int soma = 0;
    int peso = pesoInicial;

    for (int i = 0; i < base.length; i++) {
      soma += int.parse(base[i]) * peso;
      peso--;
    }

    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  final digito1 = calcularDigito(digits.substring(0, 9), 10);
  final digito2 = calcularDigito(digits.substring(0, 10), 11);

  return digits == '${digits.substring(0, 9)}$digito1$digito2';
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

    if (data.day != dia || data.month != mes || data.year != ano) {
      return null;
    }

    return data;
  } catch (_) {
    return null;
  }
}

String formatarDataBrasileira(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

int calcularIdade(DateTime nascimento) {
  final hoje = DateTime.now();
  int idade = hoje.year - nascimento.year;

  if (hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
    idade--;
  }

  return idade;
}

bool isAniversarioProximo(DateTime nascimento, {int diasLimite = 30}) {
  final hoje = DateTime.now();
  final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

  DateTime proximoAniversario = DateTime(
    hoje.year,
    nascimento.month,
    nascimento.day,
  );

  if (proximoAniversario.isBefore(hojeSemHora)) {
    proximoAniversario = DateTime(
      hoje.year + 1,
      nascimento.month,
      nascimento.day,
    );
  }

  final diferenca = proximoAniversario.difference(hojeSemHora).inDays;

  return diferenca >= 0 && diferenca <= diasLimite;
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
