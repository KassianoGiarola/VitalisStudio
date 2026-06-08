import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../services/servico_service.dart';
import '../widgets/app_shell.dart';

class PdfsPage extends StatefulWidget {
  final String nome;
  final String email;
  final String role;
  final bool embedded;

  const PdfsPage({
    super.key,
    this.nome = '',
    this.email = '',
    this.role = 'funcionario',
    this.embedded = false,
  });

  @override
  State<PdfsPage> createState() => _PdfsPageState();
}

class _PdfsPageState extends State<PdfsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectValues = {};

  String _modeloId = _modelos.first.id;
  String? _clienteId;
  String? _servicoId;
  bool _gerando = false;

  _PdfModelo get _modeloSelecionado =>
      _modelos.firstWhere((modelo) => modelo.id == _modeloId);

  @override
  void initState() {
    super.initState();
    _garantirControllers(_modeloSelecionado);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _garantirControllers(_PdfModelo modelo) {
    for (final campo in modelo.campos) {
      if (campo.tipo == _TipoCampo.selecao) {
        _selectValues.putIfAbsent(campo.chave, () => campo.opcoes.first);
      } else {
        _controllers.putIfAbsent(campo.chave, () => TextEditingController());
      }
    }
  }

  void _trocarModelo(String id) {
    setState(() {
      _modeloId = id;
      _clienteId = null;
      _servicoId = null;
      _garantirControllers(_modeloSelecionado);
      _limparCampos();
    });
  }

  void _limparCampos() {
    for (final campo in _modeloSelecionado.campos) {
      _controllers[campo.chave]?.clear();
      if (campo.tipo == _TipoCampo.selecao) {
        _selectValues[campo.chave] = campo.opcoes.first;
      }
    }
  }

  void _preencherCliente(Map<String, dynamic> data) {
    final nascimento = _timestampParaData(data['dataNascimentoCliente']);
    final endereco = _montarEndereco(data);

    _preencherCampo('paciente', (data['nome'] ?? '').toString());
    _preencherCampo('cpf', _formatarCpf((data['cpf'] ?? '').toString()));
    _preencherCampo('telefone', (data['telefone'] ?? '').toString());
    _preencherCampo(
      'nascimento',
      nascimento == null ? '' : _formatarData(nascimento),
    );
    _preencherCampo(
      'idade',
      nascimento == null ? '' : _calcularIdade(nascimento).toString(),
    );
    _preencherCampo('endereco', endereco);
    _preencherCampo('cidade', (data['cidade'] ?? '').toString());
    _preencherCampo('observacoes', (data['observacoes'] ?? '').toString());
  }

  void _preencherServico(Map<String, dynamic> data) {
    final nomeServico = (data['nome'] ?? '').toString();
    final valor = _formatarMoeda(data['valor']);

    _preencherCampo('servico', nomeServico);
    _preencherCampo('valor_servico', valor);
  }

  void _preencherCampo(String chave, String valor) {
    final controller = _controllers[chave];
    if (controller == null) return;
    controller.text = valor;
  }

  String _valorCampo(_PdfCampo campo) {
    if (campo.tipo == _TipoCampo.selecao) {
      return _selectValues[campo.chave] ?? '';
    }

    return _controllers[campo.chave]?.text.trim() ?? '';
  }

  Future<void> _gerarPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _gerando = true);

    try {
      final modelo = _modeloSelecionado;
      final bytes = await _preencherPdf(modelo);
      final nomeArquivo = _nomeArquivo(modelo);

      await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nomeArquivo gerado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $error')));
    } finally {
      if (mounted) {
        setState(() => _gerando = false);
      }
    }
  }

  Future<Uint8List> _preencherPdf(_PdfModelo modelo) async {
    final data = await rootBundle.load(modelo.assetPath);
    final document = sfpdf.PdfDocument(inputBytes: data.buffer.asUint8List());

    try {
      for (final campo in modelo.campos) {
        final valor = _valorCampo(campo);
        if (valor.isEmpty || campo.posicao == null) continue;

        final pageIndex = campo.posicao!.pageIndex;
        if (pageIndex < 0 || pageIndex >= document.pages.count) continue;

        final page = document.pages[pageIndex];
        final font = sfpdf.PdfStandardFont(
          sfpdf.PdfFontFamily.helvetica,
          campo.posicao!.fontSize,
        );

        page.graphics.drawString(
          valor,
          font,
          brush: sfpdf.PdfSolidBrush(sfpdf.PdfColor(0, 43, 64)),
          bounds: campo.posicao!.bounds,
          format: sfpdf.PdfStringFormat(
            lineSpacing: 2,
            wordWrap: sfpdf.PdfWordWrapType.word,
          ),
        );
      }

      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  String _nomeArquivo(_PdfModelo modelo) {
    final paciente = _controllers['paciente']?.text.trim() ?? '';
    final sufixo = paciente.isEmpty ? 'sem-cliente' : _slugArquivo(paciente);
    return '${modelo.nomeArquivoBase}-$sufixo.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (widget.embedded) {
      return content;
    }

    return AppShell(
      title: 'PDFs',
      nome: widget.nome,
      email: widget.email,
      role: widget.role,
      currentPage: 'pdfs',
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final modelo = _modeloSelecionado;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          final modelos = _buildModelos(modelo);
          final formulario = _buildFormulario(modelo);

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 330, child: modelos),
                const SizedBox(width: 16),
                Expanded(child: formulario),
              ],
            );
          }

          return Column(
            children: [
              modelos,
              const SizedBox(height: 14),
              Expanded(child: formulario),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelos(_PdfModelo modeloSelecionado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    color: VitalisColors.cobreQueimado,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Modelos de PDF',
                    style: TextStyle(
                      color: VitalisColors.azulMarinhoProfundo,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ..._modelos.map(
                (modelo) => _ModeloButton(
                  modelo: modelo,
                  selected: modelo.id == modeloSelecionado.id,
                  onTap: () => _trocarModelo(modelo.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormulario(_PdfModelo modelo) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _Painel(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VitalisColors.verdeEsmeralda.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: VitalisColors.verdeEsmeralda,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelo.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VitalisColors.azulMarinhoProfundo,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${modelo.campos.length} campos configurados',
                        style: const TextStyle(
                          color: VitalisColors.cinzaMedio,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _gerando ? null : _gerarPdf,
                  icon: _gerando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_gerando ? 'Gerando...' : 'Gerar PDF'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SecaoTitulo(
                          icon: Icons.person_search_rounded,
                          titulo: 'Dados vinculados',
                        ),
                        const SizedBox(height: 12),
                        _buildClienteSelector(),
                        const SizedBox(height: 12),
                        _buildServicoSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SecaoTitulo(
                          icon: Icons.edit_note_rounded,
                          titulo: 'Campos do PDF',
                        ),
                        const SizedBox(height: 12),
                        ...modelo.campos.map(_buildCampo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ClienteService.listarClientes(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return DropdownButtonFormField<String>(
          key: ValueKey('cliente-$_clienteId-${docs.length}'),
          initialValue: _clienteId,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: docs
              .map(
                (doc) => DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text((doc.data()['nome'] ?? 'Sem nome').toString()),
                ),
              )
              .toList(),
          onChanged: docs.isEmpty
              ? null
              : (id) {
                  final doc = docs.firstWhere((item) => item.id == id);
                  setState(() {
                    _clienteId = id;
                    _preencherCliente(doc.data());
                  });
                },
        );
      },
    );
  }

  Widget _buildServicoSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ServicoService.listarServicos(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return DropdownButtonFormField<String>(
          key: ValueKey('servico-$_servicoId-${docs.length}'),
          initialValue: _servicoId,
          decoration: const InputDecoration(
            labelText: 'Servico',
            prefixIcon: Icon(Icons.design_services_outlined),
          ),
          items: docs
              .map(
                (doc) => DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text((doc.data()['nome'] ?? 'Sem nome').toString()),
                ),
              )
              .toList(),
          onChanged: docs.isEmpty
              ? null
              : (id) {
                  final doc = docs.firstWhere((item) => item.id == id);
                  setState(() {
                    _servicoId = id;
                    _preencherServico(doc.data());
                  });
                },
        );
      },
    );
  }

  Widget _buildCampo(_PdfCampo campo) {
    final bottomSpacing = SizedBox(height: campo.multilinha ? 14 : 12);

    if (campo.tipo == _TipoCampo.selecao) {
      return Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectValues[campo.chave] ?? campo.opcoes.first,
            decoration: InputDecoration(
              labelText: campo.rotulo,
              prefixIcon: Icon(campo.icon),
            ),
            items: campo.opcoes
                .map(
                  (opcao) => DropdownMenuItem<String>(
                    value: opcao,
                    child: Text(opcao),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectValues[campo.chave] = value);
            },
            validator: campo.obrigatorio
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Selecione ${campo.rotulo.toLowerCase()}.';
                    }
                    return null;
                  }
                : null,
          ),
          bottomSpacing,
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: _controllers[campo.chave],
          minLines: campo.multilinha ? 3 : 1,
          maxLines: campo.multilinha ? 5 : 1,
          keyboardType: campo.multilinha
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: campo.rotulo,
            prefixIcon: Icon(campo.icon),
            alignLabelWithHint: campo.multilinha,
          ),
          validator: campo.obrigatorio
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe ${campo.rotulo.toLowerCase()}.';
                  }
                  return null;
                }
              : null,
        ),
        bottomSpacing,
      ],
    );
  }
}

class _ModeloButton extends StatelessWidget {
  final _PdfModelo modelo;
  final bool selected;
  final VoidCallback onTap;

  const _ModeloButton({
    required this.modelo,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? VitalisColors.verdeEsmeralda.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? VitalisColors.verdeEsmeralda : VitalisColors.borda,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: selected
              ? VitalisColors.verdeEsmeralda
              : VitalisColors.cobreQueimado.withValues(alpha: 0.12),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: selected ? Colors.white : VitalisColors.cobreQueimado,
          ),
        ),
        title: Text(
          modelo.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            modelo.subtitulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VitalisColors.cinzaMedio),
          ),
        ),
        trailing: selected
            ? const Icon(
                Icons.check_circle_rounded,
                color: VitalisColors.verdeEsmeralda,
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  final Widget child;

  const _Painel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitalisColors.borda),
      ),
      child: child,
    );
  }
}

class _SecaoTitulo extends StatelessWidget {
  final IconData icon;
  final String titulo;

  const _SecaoTitulo({required this.icon, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: VitalisColors.cobreQueimado, size: 21),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

enum _TipoCampo { texto, selecao }

class _PdfModelo {
  final String id;
  final String titulo;
  final String subtitulo;
  final String assetPath;
  final String nomeArquivoBase;
  final List<_PdfCampo> campos;

  const _PdfModelo({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.assetPath,
    required this.nomeArquivoBase,
    required this.campos,
  });
}

class _PdfCampo {
  final String chave;
  final String rotulo;
  final IconData icon;
  final _TipoCampo tipo;
  final bool obrigatorio;
  final bool multilinha;
  final List<String> opcoes;
  final _PdfPosicao? posicao;

  const _PdfCampo.texto({
    required this.chave,
    required this.rotulo,
    required this.icon,
    this.obrigatorio = false,
    this.multilinha = false,
    this.posicao,
  }) : tipo = _TipoCampo.texto,
       opcoes = const [];

  const _PdfCampo.selecao({
    required this.chave,
    required this.rotulo,
    required this.icon,
    required this.opcoes,
    this.obrigatorio = false,
    this.posicao,
  }) : tipo = _TipoCampo.selecao,
       multilinha = false;
}

class _PdfPosicao {
  final int pageIndex;
  final Rect bounds;
  final double fontSize;

  const _PdfPosicao({
    required this.pageIndex,
    required this.bounds,
    this.fontSize = 10,
  });
}

final List<_PdfModelo> _modelos = [
  _PdfModelo(
    id: 'ficha_pilates',
    titulo: 'Ficha de Avaliacao de Pilates',
    subtitulo: 'assets/pdfs/Ficha de Avaliacao de Pilates.pdf',
    assetPath: 'assets/pdfs/Ficha de Avaliação de Pilates.pdf',
    nomeArquivoBase: 'ficha-avaliacao-pilates',
    campos: [
      _PdfCampo.texto(
        chave: 'paciente',
        rotulo: 'Paciente',
        icon: Icons.person_outline_rounded,
        obrigatorio: true,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(96, 104, 260, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'cpf',
        rotulo: 'CPF',
        icon: Icons.badge_outlined,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(410, 104, 120, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'telefone',
        rotulo: 'Telefone',
        icon: Icons.phone_outlined,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(96, 130, 150, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'nascimento',
        rotulo: 'Nascimento',
        icon: Icons.cake_outlined,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(300, 130, 92, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'idade',
        rotulo: 'Idade',
        icon: Icons.hourglass_empty_rounded,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(455, 130, 55, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.selecao(
        chave: 'sexo',
        rotulo: 'Sexo',
        icon: Icons.wc_outlined,
        obrigatorio: true,
        opcoes: ['Feminino', 'Masculino', 'Outro'],
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(96, 156, 120, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'servico',
        rotulo: 'Servico',
        icon: Icons.design_services_outlined,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(300, 156, 190, 18),
          fontSize: 10.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'endereco',
        rotulo: 'Endereco',
        icon: Icons.home_outlined,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(96, 182, 430, 20),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'objetivo',
        rotulo: 'Objetivo do paciente',
        icon: Icons.flag_outlined,
        obrigatorio: true,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(72, 246, 470, 56),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'queixa',
        rotulo: 'Queixa principal',
        icon: Icons.healing_outlined,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(72, 326, 470, 56),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'historico',
        rotulo: 'Historico clinico',
        icon: Icons.assignment_outlined,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(72, 406, 470, 64),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'amplitude_movimento',
        rotulo: 'Amplitude de movimento',
        icon: Icons.open_in_full_rounded,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 2,
          bounds: Rect.fromLTWH(72, 612, 470, 72),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'flexibilidade',
        rotulo: 'Flexibilidade',
        icon: Icons.self_improvement_rounded,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 3,
          bounds: Rect.fromLTWH(72, 92, 470, 92),
          fontSize: 9.5,
        ),
      ),
      _PdfCampo.texto(
        chave: 'observacoes',
        rotulo: 'Observacoes',
        icon: Icons.notes_outlined,
        multilinha: true,
        posicao: _PdfPosicao(
          pageIndex: 3,
          bounds: Rect.fromLTWH(72, 650, 470, 82),
          fontSize: 9.5,
        ),
      ),
    ],
  ),
];

Timestamp? _asTimestamp(dynamic value) {
  return value is Timestamp ? value : null;
}

DateTime? _timestampParaData(dynamic value) {
  return _asTimestamp(value)?.toDate();
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

  return partes.join(' - ');
}

String _apenasDigitos(String valor) {
  return valor.replaceAll(RegExp(r'[^0-9]'), '');
}

String _formatarCpf(String cpf) {
  final digits = _apenasDigitos(cpf);
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

String _formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

int _calcularIdade(DateTime nascimento) {
  final hoje = DateTime.now();
  int idade = hoje.year - nascimento.year;

  if (hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
    idade--;
  }

  return idade;
}

String _formatarMoeda(dynamic valor) {
  final numero = valor is num ? valor : num.tryParse(valor?.toString() ?? '');
  if (numero == null) return '';
  return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
}

String _slugArquivo(String texto) {
  final normalizado = texto
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return normalizado.isEmpty ? 'sem-cliente' : normalizado;
}
