import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../widgets/app_shell.dart';

class AniversariantesPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const AniversariantesPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'funcionario',
    this.embedded = false,
  });

  @override
  State<AniversariantesPage> createState() => _AniversariantesPageState();
}

class _AniversariantesPageState extends State<AniversariantesPage> {
  int _diasParaAniversario(DateTime nascimento) {
    final hoje = DateTime.now();

    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

    DateTime aniversario = DateTime(
      hoje.year,
      nascimento.month,
      nascimento.day,
    );

    if (aniversario.isBefore(hojeSemHora)) {
      aniversario = DateTime(hoje.year + 1, nascimento.month, nascimento.day);
    }

    return aniversario.difference(hojeSemHora).inDays;
  }

  int _idadeQueVaiFazer(DateTime nascimento) {
    final hoje = DateTime.now();

    int idade = hoje.year - nascimento.year;

    return idade + 1;
  }

  Future<String> _gerarMensagem({
    required String nomeCliente,
    required String nomeAniversariante,
    required int idade,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('aniversario')
        .get();

    final data = doc.data() ?? {};

    String template =
        (data['mensagemPadrao'] ??
                '🎉 Olá {nome}! Tudo bem?\n\n'
                    'Hoje é um dia especial!\n\n'
                    'Parabéns para {nome_aniversariante} pelos {idade} anos 🥳\n\n'
                    'Desejamos muita saúde e alegria 💙')
            .toString();

    return template
        .replaceAll('{nome}', nomeCliente)
        .replaceAll('{nome_aniversariante}', nomeAniversariante)
        .replaceAll('{idade}', idade.toString());
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

  String _statusTexto(int dias) {
    if (dias == 0) {
      return 'Hoje 🎉';
    }

    return 'Faltam $dias dias';
  }

  Color _corStatus(int dias) {
    if (dias == 0) {
      return VitalisColors.verdeEsmeralda;
    }

    return VitalisColors.alerta;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'Aniversariantes',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'aniversariantes',
      child: content,
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final filtrados = docs.where((doc) {
            final data = doc.data();

            final status = (data['status'] ?? '').toString().toLowerCase();

            if (status == 'inativo') {
              return false;
            }

            final receber = data['receberMensagemAniversario'] != false;

            if (!receber) {
              return false;
            }

            final natacao = data['clienteNatacao'] == true;

            Timestamp? timestamp;

            if (natacao) {
              timestamp = data['dataNascimentoCrianca'] as Timestamp?;
            } else {
              timestamp = data['dataNascimentoCliente'] as Timestamp?;
            }

            if (timestamp == null) {
              return false;
            }

            final dias = _diasParaAniversario(timestamp.toDate());

            return dias <= 30;
          }).toList();

          filtrados.sort((a, b) {
            final dataA = a.data();

            final dataB = b.data();

            final natA = dataA['clienteNatacao'] == true;

            final natB = dataB['clienteNatacao'] == true;

            final nascA = natA
                ? (dataA['dataNascimentoCrianca'] as Timestamp).toDate()
                : (dataA['dataNascimentoCliente'] as Timestamp).toDate();

            final nascB = natB
                ? (dataB['dataNascimentoCrianca'] as Timestamp).toDate()
                : (dataB['dataNascimentoCliente'] as Timestamp).toDate();

            return _diasParaAniversario(
              nascA,
            ).compareTo(_diasParaAniversario(nascB));
          });

          if (filtrados.isEmpty) {
            return const Center(child: Text('Nenhum aniversário próximo 🎂'));
          }

          return ListView.builder(
            itemCount: filtrados.length,
            itemBuilder: (_, i) {
              final data = filtrados[i].data();

              final nomeCliente = (data['nome'] ?? '').toString();

              final telefone = (data['telefone'] ?? '').toString();

              final natacao = data['clienteNatacao'] == true;

              final nomeAniversariante = natacao
                  ? (data['nomeCrianca'] ?? nomeCliente).toString()
                  : nomeCliente;

              final nascimento = natacao
                  ? (data['dataNascimentoCrianca'] as Timestamp).toDate()
                  : (data['dataNascimentoCliente'] as Timestamp).toDate();

              final dias = _diasParaAniversario(nascimento);

              final idade = _idadeQueVaiFazer(nascimento);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _corStatus(dias).withOpacity(0.12),
                        child: Icon(Icons.cake, color: _corStatus(dias)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeCliente,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              natacao
                                  ? 'Criança: $nomeAniversariante'
                                  : 'Cliente',
                            ),
                            Text('Vai fazer: $idade anos'),
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
                        icon: const Icon(Icons.chat, color: Colors.green),
                        onPressed: telefone.isEmpty
                            ? null
                            : () async {
                                final mensagem = await _gerarMensagem(
                                  nomeCliente: nomeCliente,
                                  nomeAniversariante: nomeAniversariante,
                                  idade: idade,
                                );

                                await _abrirWhatsApp(telefone, mensagem);
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
