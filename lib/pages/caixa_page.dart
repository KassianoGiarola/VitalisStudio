import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/caixa_service.dart';
import '../widgets/app_shell.dart';

class CaixaPage extends StatelessWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const CaixaPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'admin',
    this.embedded = false,
  });

  String _formatar(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _abrirDialogoAbrir(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abrir caixa'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Valor inicial'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valor =
                  double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

              try {
                await CaixaService.abrirCaixa(valor);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDialogoFechar(BuildContext context) async {
    final contadoController = TextEditingController();
    final trocoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fechar caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contadoController,
              decoration: const InputDecoration(
                labelText: 'Valor contado no caixa',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trocoController,
              decoration: const InputDecoration(
                labelText: 'Troco para deixar separado',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valorContado =
                  double.tryParse(
                    contadoController.text.replaceAll(',', '.'),
                  ) ??
                  0.0;

              final troco =
                  double.tryParse(trocoController.text.replaceAll(',', '.')) ??
                  0.0;

              try {
                await CaixaService.fecharCaixa(
                  valorContado: valorContado,
                  trocoParaProximoDia: troco,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (embedded) {
      return content;
    }

    return AppShell(
      title: 'Caixa',
      nome: nome,
      email: email,
      role: role,
      currentPage: 'caixa',
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CaixaService.ouvirHistorico(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: VitalisColors.verdeEsmeralda,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          DocumentSnapshot<Map<String, dynamic>>? caixaAberto;

          for (final doc in docs) {
            final data = doc.data();
            if (data['aberto'] == true) {
              caixaAberto = doc;
              break;
            }
          }

          final bool aberto = caixaAberto != null;
          final double saldo = aberto
              ? _toDouble(caixaAberto.data()?['saldo'])
              : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: aberto ? VitalisColors.sucesso : VitalisColors.erro,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      aberto
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      aberto ? 'CAIXA ABERTO' : 'CAIXA FECHADO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: VitalisColors.verdeEsmeralda
                            .withOpacity(0.12),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: VitalisColors.verdeEsmeralda,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo atual',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatar(saldo),
                              style: const TextStyle(
                                fontSize: 26,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: aberto
                          ? null
                          : () => _abrirDialogoAbrir(context),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Abrir Caixa'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: aberto
                          ? () => _abrirDialogoFechar(context)
                          : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Fechar Caixa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Histórico',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: VitalisColors.azulMarinhoProfundo,
                ),
              ),
              const SizedBox(height: 10),
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
                                Icons.point_of_sale_rounded,
                                size: 54,
                                color: VitalisColors.cobreQueimado,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Nenhum histórico de caixa encontrado.',
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
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final data = docs[i].data();

                          final abertoItem = data['aberto'] == true;
                          final saldoSistema = _toDouble(data['saldoSistema']);
                          final saldoFinalContado = _toDouble(
                            data['saldoFinalContado'],
                          );
                          final diferenca = _toDouble(data['diferenca']);
                          final trocoSeparado = _toDouble(
                            data['trocoSeparado'],
                          );
                          final saldoAtual = _toDouble(data['saldo']);
                          final saldoInicial = _toDouble(data['saldoInicial']);

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: abertoItem
                                        ? VitalisColors.sucesso.withOpacity(
                                            0.12,
                                          )
                                        : VitalisColors.erro.withOpacity(0.12),
                                    child: Icon(
                                      abertoItem
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_outline_rounded,
                                      color: abertoItem
                                          ? VitalisColors.sucesso
                                          : VitalisColors.erro,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          abertoItem
                                              ? 'Caixa aberto'
                                              : 'Caixa fechado',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: VitalisColors
                                                .azulMarinhoProfundo,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (abertoItem) ...[
                                          Text(
                                            'Saldo inicial: ${_formatar(saldoInicial)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Saldo atual: ${_formatar(saldoAtual)}',
                                          ),
                                        ] else ...[
                                          Text(
                                            'Saldo sistema: ${_formatar(saldoSistema)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Valor contado: ${_formatar(saldoFinalContado)}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Diferença: ${_formatar(diferenca)}',
                                            style: TextStyle(
                                              color: diferenca == 0
                                                  ? VitalisColors.sucesso
                                                  : VitalisColors.erro,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Troco separado: ${_formatar(trocoSeparado)}',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
