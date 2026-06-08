import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/configuracao_service.dart';
import '../widgets/app_shell.dart';

class ConfiguracoesLembretePage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const ConfiguracoesLembretePage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'admin',
    this.embedded = false,
  });

  @override
  State<ConfiguracoesLembretePage> createState() =>
      _ConfiguracoesLembretePageState();
}

class _ConfiguracoesLembretePageState extends State<ConfiguracoesLembretePage> {
  final _formKey = GlobalKey<FormState>();

  final _diasAntesLembrete1Controller = TextEditingController();
  final _mensagemLembrete1Controller = TextEditingController();
  final _diasAntesLembrete2Controller = TextEditingController();
  final _mensagemLembrete2Controller = TextEditingController();

  bool _lembrete1Ativo = true;
  bool _lembrete2Ativo = true;
  bool _loading = false;
  bool _dadosCarregados = false;

  @override
  void dispose() {
    _diasAntesLembrete1Controller.dispose();
    _mensagemLembrete1Controller.dispose();
    _diasAntesLembrete2Controller.dispose();
    _mensagemLembrete2Controller.dispose();
    super.dispose();
  }

  void _preencherCampos(Map<String, dynamic>? data) {
    if (_dadosCarregados) return;

    _lembrete1Ativo = data?['lembrete1Ativo'] == true;
    _lembrete2Ativo = data?['lembrete2Ativo'] == true;

    _diasAntesLembrete1Controller.text =
        ((data?['diasAntesLembrete1'] ?? 3) as num).toInt().toString();

    _diasAntesLembrete2Controller.text =
        ((data?['diasAntesLembrete2'] ?? 1) as num).toInt().toString();

    _mensagemLembrete1Controller.text =
        (data?['mensagemLembrete1'] ??
                'Olá, {nome}. Sua mensalidade de {servico} no valor de {valor} vence no dia {dia_vencimento}.')
            .toString();

    _mensagemLembrete2Controller.text =
        (data?['mensagemLembrete2'] ??
                'Olá, {nome}. Identificamos que sua mensalidade de {servico} vence em breve e ainda não consta pagamento.')
            .toString();

    _dadosCarregados = true;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dias1 = int.tryParse(_diasAntesLembrete1Controller.text.trim());
    final dias2 = int.tryParse(_diasAntesLembrete2Controller.text.trim());

    if (dias1 == null || dias1 < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido para os dias do lembrete 1.'),
        ),
      );
      return;
    }

    if (dias2 == null || dias2 < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido para os dias do lembrete 2.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ConfiguracaoService.salvarConfiguracaoCobranca(
        lembrete1Ativo: _lembrete1Ativo,
        diasAntesLembrete1: dias1,
        mensagemLembrete1: _mensagemLembrete1Controller.text,
        lembrete2Ativo: _lembrete2Ativo,
        diasAntesLembrete2: dias2,
        mensagemLembrete2: _mensagemLembrete2Controller.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar configurações.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildVariavelChip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VitalisColors.offWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: VitalisColors.azulMarinhoProfundo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Configurações de Lembrete',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'lembretes',
      child: content,
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ConfiguracaoService.ouvirCobranca(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_dadosCarregados) {
            return const Center(
              child: CircularProgressIndicator(
                color: VitalisColors.verdeEsmeralda,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar configurações.',
                style: TextStyle(
                  color: VitalisColors.azulMarinhoProfundo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final data = snapshot.data?.data();
          _preencherCampos(data);

          return Form(
            key: _formKey,
            child: ListView(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuração dos lembretes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Defina quantos dias antes do vencimento as mensagens serão enviadas e personalize o texto diretamente no app.',
                        style: TextStyle(color: VitalisColors.cinzaEscuro),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lembrete 1',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _lembrete1Ativo,
                        onChanged: (value) {
                          setState(() => _lembrete1Ativo = value);
                        },
                        activeThumbColor: VitalisColors.verdeEsmeralda,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativar lembrete 1'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _diasAntesLembrete1Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dias antes do vencimento',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe os dias do lembrete 1.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mensagemLembrete1Controller,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Mensagem do lembrete 1',
                          prefixIcon: Icon(Icons.message_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe a mensagem do lembrete 1.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lembrete 2',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _lembrete2Ativo,
                        onChanged: (value) {
                          setState(() => _lembrete2Ativo = value);
                        },
                        activeThumbColor: VitalisColors.verdeEsmeralda,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativar lembrete 2'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _diasAntesLembrete2Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dias antes do vencimento',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe os dias do lembrete 2.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mensagemLembrete2Controller,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Mensagem do lembrete 2',
                          prefixIcon: Icon(Icons.message_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe a mensagem do lembrete 2.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Variáveis disponíveis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: VitalisColors.azulMarinhoProfundo,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Você pode usar estas variáveis nas mensagens. O sistema substituirá automaticamente na hora do envio.',
                        style: TextStyle(color: VitalisColors.cinzaEscuro),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildVariavelChip('{nome}'),
                          _buildVariavelChip('{servico}'),
                          _buildVariavelChip('{valor}'),
                          _buildVariavelChip('{dia_vencimento}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _salvar,
                  icon: const Icon(Icons.save_outlined),
                  label: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar configurações'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
