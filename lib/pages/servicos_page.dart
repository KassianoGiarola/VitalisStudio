import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/servico_service.dart';
import '../widgets/app_shell.dart';

class ServicosPage extends StatelessWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const ServicosPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'funcionario',
    this.embedded = false,
  });

  String _formatarValor(dynamic valor) {
    if (valor == null) return 'R\$ 0,00';

    if (valor is int) {
      return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    if (valor is double) {
      return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    final convertido = double.tryParse(valor.toString()) ?? 0;
    return 'R\$ ${convertido.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatarTipo(String tipo) {
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

  Color _corTipo(String tipo) {
    switch (tipo) {
      case 'mensalidade':
        return VitalisColors.verdeEsmeralda;
      case 'sessao':
        return VitalisColors.cobreQueimado;
      case 'aula_experimental':
        return VitalisColors.info;
      case 'avulso':
        return VitalisColors.alerta;
      default:
        return VitalisColors.cinzaMedio;
    }
  }

  Widget _buildFloatingActionButton(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (embedded) {
      return content;
    }

    return AppShell(
      title: 'Serviços',
      nome: nome,
      email: email,
      role: role,
      currentPage: 'servicos',
      floatingActionButton: _buildFloatingActionButton(context),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ServicoService.listarServicos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: VitalisColors.verdeEsmeralda,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 54,
                      color: VitalisColors.erro,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Erro ao carregar serviços.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VitalisColors.cinzaEscuro),
                    ),
                  ],
                ),
              ),
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
                      Icons.design_services_outlined,
                      size: 54,
                      color: VitalisColors.cobreQueimado,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum serviço cadastrado ainda.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Clique em "Novo serviço" para começar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VitalisColors.cinzaEscuro),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data();

              final nomeServico = (data['nome'] ?? 'Sem nome').toString();
              final valor = data['valor'];
              final ativo = data['ativo'] == true;
              final tipoCobranca = (data['tipoCobranca'] ?? 'mensalidade')
                  .toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _corTipo(
                          tipoCobranca,
                        ).withOpacity(0.12),
                        child: Icon(
                          Icons.design_services_rounded,
                          color: _corTipo(tipoCobranca),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeServico,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: VitalisColors.azulMarinhoProfundo,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatarValor(valor),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: VitalisColors.verdeEsmeralda,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ServicoChip(
                                  texto: _formatarTipo(tipoCobranca),
                                  cor: _corTipo(tipoCobranca),
                                ),
                                _ServicoChip(
                                  texto: ativo ? 'Ativo' : 'Inativo',
                                  cor: ativo
                                      ? VitalisColors.cobreQueimado
                                      : VitalisColors.cinzaMedio,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar serviço',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => CadastroServicoDialog(
                              servicoId: doc.id,
                              dados: data,
                            ),
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
      ),
    );
  }
}

class _ServicoChip extends StatelessWidget {
  final String texto;
  final Color cor;

  const _ServicoChip({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class CadastroServicoDialog extends StatefulWidget {
  final String? servicoId;
  final Map<String, dynamic>? dados;

  const CadastroServicoDialog({super.key, this.servicoId, this.dados});

  @override
  State<CadastroServicoDialog> createState() => _CadastroServicoDialogState();
}

class _CadastroServicoDialogState extends State<CadastroServicoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();

  String _tipoCobranca = 'mensalidade';

  bool _ativo = true;
  bool _loading = false;

  bool get isEdicao => widget.servicoId != null;

  final List<DropdownMenuItem<String>> _tipos = const [
    DropdownMenuItem(value: 'mensalidade', child: Text('Mensalidade')),
    DropdownMenuItem(value: 'avulso', child: Text('Avulso')),
    DropdownMenuItem(value: 'sessao', child: Text('Sessão')),
    DropdownMenuItem(
      value: 'aula_experimental',
      child: Text('Aula experimental'),
    ),
    DropdownMenuItem(value: 'outro', child: Text('Outro')),
  ];

  @override
  void initState() {
    super.initState();

    final d = widget.dados;
    if (d != null) {
      _nomeController.text = (d['nome'] ?? '').toString();

      final valor = d['valor'];
      if (valor is num) {
        _valorController.text = valor.toStringAsFixed(2).replaceAll('.', ',');
      } else {
        _valorController.text = valor.toString();
      }

      _ativo = d['ativo'] == true;
      _tipoCobranca = (d['tipoCobranca'] ?? 'mensalidade').toString();

      if (![
        'mensalidade',
        'avulso',
        'sessao',
        'aula_experimental',
        'outro',
      ].contains(_tipoCobranca)) {
        _tipoCobranca = 'mensalidade';
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
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
      if (isEdicao) {
        await ServicoService.atualizarServico(
          id: widget.servicoId!,
          nome: _nomeController.text,
          valor: valor,
          ativo: _ativo,
          tipoCobranca: _tipoCobranca,
        );
      } else {
        await ServicoService.criarServico(
          nome: _nomeController.text,
          valor: valor,
          tipoCobranca: _tipoCobranca,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdicao
                ? 'Serviço atualizado com sucesso.'
                : 'Serviço cadastrado com sucesso.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar serviço.')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VitalisColors.offWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEdicao ? 'Editar serviço' : 'Novo serviço',
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
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do serviço',
                    prefixIcon: Icon(Icons.design_services_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do serviço.';
                    }
                    return null;
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
                  initialValue: _tipoCobranca,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cobrança',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  items: _tipos,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tipoCobranca = value);
                    }
                  },
                ),
                if (isEdicao) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _ativo,
                    onChanged: (value) {
                      setState(() => _ativo = value);
                    },
                    activeThumbColor: VitalisColors.verdeEsmeralda,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Serviço ativo'),
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
