import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../core/app_colors.dart';
import '../services/cliente_service.dart';
import '../services/pdf_exporter.dart';
import '../widgets/app_shell.dart';

const _pdfFontAssetPath = 'assets/fonts/arial-mt-pro.otf';
const _pdfFontFamily = 'ArialMTPro';
const _pdfFontSize = 14.0;
const _pdfTextScale = 4.0;
const _evolucaoTextOffsetY = 6.0;
const _evolucaoCheckboxOffsetY = 9.0;
const _avaliacaoTextOffsetY = 6.0;
const _avaliacaoCheckboxOffsetY = 9.0;

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
  final Map<String, Set<String>> _multiSelectValues = {};

  String _modeloId = _modelos.first.id;
  String? _clienteId;
  bool _gerando = false;
  bool _fontePdfCarregada = false;

  _PdfModelo get _modeloSelecionado =>
      _modelos.firstWhere((modelo) => modelo.id == _modeloId);

  @override
  void initState() {
    super.initState();
    _garantirControllers(_modeloSelecionado);
    _preencherPadroes();
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
      if (campo.tipo == _TipoCampo.multiplaEscolha) {
        _multiSelectValues.putIfAbsent(campo.chave, () => <String>{});
      } else {
        _controllers.putIfAbsent(campo.chave, () => TextEditingController());
      }
    }
  }

  void _preencherPadroes() {
    _preencherCampoSeVazio('data_termo', _formatarData(DateTime.now()));
    _preencherCampoSeVazio('data_evolucao_1', _formatarData(DateTime.now()));
    _preencherCampoSeVazio('avaliacao_data', _formatarData(DateTime.now()));
    _preencherCampoSeVazio(
      'data_consentimento_fisioterapia',
      _formatarData(DateTime.now()),
    );
  }

  void _trocarModelo(String id) {
    setState(() {
      _modeloId = id;
      _clienteId = null;
      _garantirControllers(_modeloSelecionado);
      _limparCampos();
      _preencherPadroes();
    });
  }

  void _limparCampos() {
    for (final campo in _modeloSelecionado.campos) {
      _controllers[campo.chave]?.clear();
      _multiSelectValues[campo.chave]?.clear();
    }
  }

  void _preencherCliente(Map<String, dynamic> data) {
    final nomeCliente = (data['nome'] ?? '').toString();
    final cidade = (data['cidade'] ?? '').toString();

    _preencherCampo('declarante', nomeCliente);
    _preencherCampo('nome_paciente', nomeCliente);
    _preencherCampo('paciente_evolucao', nomeCliente);
    _preencherCampo('avaliacao_nome', nomeCliente);
    _preencherCampo('paciente_consentimento_fisioterapia', nomeCliente);
    _preencherCampo(
      'avaliacao_endereco',
      [
        (data['logradouro'] ?? '').toString(),
        (data['numero'] ?? '').toString(),
        (data['bairro'] ?? '').toString(),
        cidade,
      ].where((parte) => parte.trim().isNotEmpty).join(', '),
    );
    _preencherCampo('avaliacao_telefone', (data['telefone'] ?? '').toString());
    _preencherCampo('avaliacao_email', (data['email'] ?? '').toString());
    _preencherCampo(
      'avaliacao_profissao',
      (data['profissao'] ?? '').toString(),
    );
    final nascimento = data['dataNascimentoCliente'];
    if (nascimento is Timestamp) {
      final dataNascimento = nascimento.toDate();
      _preencherCampo('avaliacao_nascimento', _formatarData(dataNascimento));
      _preencherCampo(
        'avaliacao_idade',
        _calcularIdade(dataNascimento).toString(),
      );
    }
    _preencherCampoSeVazio('local', cidade);
    _preencherCampoSeVazio('data_termo', _formatarData(DateTime.now()));
    _preencherCampoSeVazio('data_evolucao_1', _formatarData(DateTime.now()));
    _preencherCampoSeVazio('avaliacao_data', _formatarData(DateTime.now()));
    _preencherCampoSeVazio(
      'data_consentimento_fisioterapia',
      _formatarData(DateTime.now()),
    );
  }

  void _preencherCampo(String chave, String valor) {
    final controller = _controllers[chave];
    if (controller == null) return;
    controller.text = valor;
  }

  void _preencherCampoSeVazio(String chave, String valor) {
    final controller = _controllers[chave];
    if (controller == null || controller.text.trim().isNotEmpty) return;
    controller.text = valor.trim();
  }

  String _valorCampo(_PdfCampo campo) {
    return _controllers[campo.chave]?.text.trim() ?? '';
  }

  bool _opcaoSelecionada(_PdfCampo campo, String chaveOpcao) {
    return _multiSelectValues[campo.chave]?.contains(chaveOpcao) ?? false;
  }

  void _alternarOpcao(_PdfCampo campo, String chaveOpcao, bool selected) {
    setState(() {
      final values = _multiSelectValues.putIfAbsent(
        campo.chave,
        () => <String>{},
      );

      if (selected) {
        if (campo.selecaoUnica) values.clear();
        values.add(chaveOpcao);
      } else {
        values.remove(chaveOpcao);
      }
    });
  }

  Future<void> _gerarPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _gerando = true);

    try {
      final modelo = _modeloSelecionado;
      final bytes = await _preencherPdf(modelo);
      final nomeArquivo = _nomeArquivo(modelo);

      final exportado = await exportarPdf(bytes: bytes, filename: nomeArquivo);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportado
                ? '$nomeArquivo gerado. Download iniciado.'
                : 'Nao foi possivel exportar o PDF.',
          ),
        ),
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
    await _garantirFontePdfCarregada();

    final data = await rootBundle.load(modelo.assetPath);
    final document = sfpdf.PdfDocument(inputBytes: data.buffer.asUint8List());
    document.form.fields.clear();

    try {
      for (final campo in modelo.campos) {
        if (campo.tipo == _TipoCampo.multiplaEscolha) {
          await _preencherMultiplaEscolha(document, campo);
          continue;
        }

        final valor = _valorCampo(campo);
        final posicao = campo.posicao;
        if (valor.isEmpty) continue;

        if (campo.linhasPdf.isNotEmpty) {
          await _preencherLinhasPdf(document, campo, valor);
          continue;
        }

        if (posicao == null) continue;
        if (posicao.pageIndex < 0 ||
            posicao.pageIndex >= document.pages.count) {
          continue;
        }

        final page = document.pages[posicao.pageIndex];
        final imagemTexto = await _renderizarTextoPdf(
          valor,
          posicao.bounds.size,
          multiline: campo.multilinha,
          maxLines: campo.maxLinesPdf,
          centralizadoVertical: campo.centralizadoVertical,
        );

        page.graphics.drawImage(sfpdf.PdfBitmap(imagemTexto), posicao.bounds);
      }

      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  Future<void> _preencherMultiplaEscolha(
    sfpdf.PdfDocument document,
    _PdfCampo campo,
  ) async {
    final selecionadas = _multiSelectValues[campo.chave] ?? const <String>{};
    if (selecionadas.isEmpty) return;

    for (final opcao in campo.opcoes) {
      if (!selecionadas.contains(opcao.chave)) continue;

      final posicao = opcao.posicao;
      if (posicao.pageIndex < 0 || posicao.pageIndex >= document.pages.count) {
        continue;
      }

      final page = document.pages[posicao.pageIndex];
      final imagemTexto = await _renderizarTextoPdf(
        'X',
        posicao.bounds.size,
        multiline: false,
        centralizado: true,
      );

      page.graphics.drawImage(sfpdf.PdfBitmap(imagemTexto), posicao.bounds);
    }
  }

  Future<void> _preencherLinhasPdf(
    sfpdf.PdfDocument document,
    _PdfCampo campo,
    String valor,
  ) async {
    final linhas = _quebrarTextoPdf(
      valor,
      campo.linhasPdf.map((linha) => linha.bounds.width).toList(),
    );

    for (var index = 0; index < linhas.length; index++) {
      final texto = linhas[index];
      final posicao = campo.linhasPdf[index];
      if (texto.isEmpty ||
          posicao.pageIndex < 0 ||
          posicao.pageIndex >= document.pages.count) {
        continue;
      }

      final imagemTexto = await _renderizarTextoPdf(
        texto,
        posicao.bounds.size,
        multiline: false,
        centralizadoVertical: true,
      );
      document.pages[posicao.pageIndex].graphics.drawImage(
        sfpdf.PdfBitmap(imagemTexto),
        posicao.bounds,
      );
    }
  }

  List<String> _quebrarTextoPdf(String texto, List<double> larguras) {
    var restante = texto.trim();
    final linhas = <String>[];

    for (var index = 0; index < larguras.length; index++) {
      if (restante.isEmpty) {
        linhas.add('');
        continue;
      }

      if (index == larguras.length - 1) {
        linhas.add(restante);
        break;
      }

      var inicio = 1;
      var fim = restante.length;
      var melhor = 1;
      while (inicio <= fim) {
        final meio = (inicio + fim) ~/ 2;
        final painter = TextPainter(
          text: TextSpan(
            text: restante.substring(0, meio),
            style: const TextStyle(
              fontFamily: _pdfFontFamily,
              fontSize: _pdfFontSize,
            ),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        if (painter.width <= larguras[index]) {
          melhor = meio;
          inicio = meio + 1;
        } else {
          fim = meio - 1;
        }
      }

      var corte = melhor;
      final espaco = restante.substring(0, melhor).lastIndexOf(' ');
      if (espaco > 0) corte = espaco;
      linhas.add(restante.substring(0, corte).trim());
      restante = restante.substring(corte).trim();
    }

    return linhas;
  }

  Future<void> _garantirFontePdfCarregada() async {
    if (_fontePdfCarregada) return;

    final loader = FontLoader(_pdfFontFamily)
      ..addFont(rootBundle.load(_pdfFontAssetPath));
    await loader.load();
    _fontePdfCarregada = true;
  }

  Future<Uint8List> _renderizarTextoPdf(
    String texto,
    Size size, {
    required bool multiline,
    bool centralizado = false,
    int? maxLines,
    bool centralizadoVertical = false,
  }) async {
    final width = (size.width * _pdfTextScale).ceil().clamp(1, 4096);
    final height = (size.height * _pdfTextScale).ceil().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.scale(_pdfTextScale);

    final textPainter = TextPainter(
      text: TextSpan(
        text: texto,
        style: const TextStyle(
          color: Colors.black,
          fontFamily: _pdfFontFamily,
          fontSize: _pdfFontSize,
        ),
      ),
      maxLines: maxLines ?? (multiline ? 4 : 1),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final offset = centralizado
        ? Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          )
        : Offset(
            0,
            centralizadoVertical ? (size.height - textPainter.height) / 2 : 0,
          );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Nao foi possivel renderizar o texto do PDF.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  String _nomeArquivo(_PdfModelo modelo) {
    final chaveNome = switch (modelo.id) {
      'termo_consentimento_imagem' => 'declarante',
      'consentimento_assistencia_fisioterapeutica' =>
        'paciente_consentimento_fisioterapia',
      'ficha_avaliacao_pilates' => 'avaliacao_nome',
      'evolucao_diaria_pilates' => 'paciente_evolucao',
      _ => 'nome_paciente',
    };
    final nome = _controllers[chaveNome]?.text.trim() ?? '';
    final sufixo = nome.isEmpty ? 'sem-cliente' : _slugArquivo(nome);
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
    return _Painel(
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
    );
  }

  Widget _buildFormulario(_PdfModelo modelo) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: _Painel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecaoTitulo(
                icon: Icons.edit_note_rounded,
                titulo: 'Dados do PDF',
              ),
              const SizedBox(height: 12),
              _buildClienteSelector(),
              const SizedBox(height: 12),
              ..._buildCamposModelo(modelo),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCamposModelo(_PdfModelo modelo) {
    if (modelo.id == 'ficha_avaliacao_pilates') {
      final secoes = <String>[];
      for (final campo in modelo.campos) {
        final secao = campo.secao ?? 'Dados';
        if (!secoes.contains(secao)) secoes.add(secao);
      }

      return secoes.map((secao) {
        final campos = modelo.campos
            .where((campo) => (campo.secao ?? 'Dados') == secao)
            .toList();
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: secao == secoes.first,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text(
              secao,
              style: const TextStyle(
                color: VitalisColors.azulMarinhoProfundo,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            children: _buildCamposAvaliacao(campos),
          ),
        );
      }).toList();
    }

    if (modelo.id != 'evolucao_diaria_pilates') {
      return modelo.campos.map(_buildCampo).toList();
    }

    final gerais = modelo.campos.where((campo) => campo.dia == null);

    return [
      ...gerais.map(_buildCampo),
      ...List.generate(10, (index) {
        final dia = index + 1;
        final camposDia = modelo.campos.where((campo) => campo.dia == dia);

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: dia == 1,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: VitalisColors.verdeEsmeralda.withValues(
                alpha: 0.12,
              ),
              child: Text(
                '$dia',
                style: const TextStyle(
                  color: VitalisColors.verdeEsmeralda,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
              'Dia $dia',
              style: const TextStyle(
                color: VitalisColors.azulMarinhoProfundo,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            children: camposDia.map(_buildCampo).toList(),
          ),
        );
      }),
    ];
  }

  Widget _buildClienteSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ClienteService.listarClientes(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final selectedId = docs.any((doc) => doc.id == _clienteId)
            ? _clienteId
            : null;

        return DropdownButtonFormField<String>(
          key: ValueKey('cliente-$selectedId-${docs.length}'),
          initialValue: selectedId,
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

  Widget _buildCampo(_PdfCampo campo) {
    if (campo.tipo == _TipoCampo.multiplaEscolha) {
      return _buildCampoMultiplaEscolha(campo);
    }

    return Column(
      children: [
        TextFormField(
          controller: _controllers[campo.chave],
          maxLength: campo.maxCaracteres,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          minLines: campo.multilinha ? 3 : 1,
          maxLines: campo.multilinha ? 5 : 1,
          keyboardType: campo.multilinha
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: campo.rotulo,
            alignLabelWithHint: campo.multilinha,
          ),
          validator: (value) {
            final texto = value?.trim() ?? '';
            if (campo.obrigatorio && texto.isEmpty) {
              return 'Informe ${campo.rotulo.toLowerCase()}.';
            }
            if (campo.maxCaracteres != null &&
                texto.length > campo.maxCaracteres!) {
              return 'Use no maximo ${campo.maxCaracteres} caracteres.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _buildCamposAvaliacao(List<_PdfCampo> campos) {
    final widgets = <Widget>[];

    for (var index = 0; index < campos.length; index++) {
      final campo = campos[index];
      if (!campo.chave.endsWith('_d') || index + 1 >= campos.length) {
        widgets.add(_buildCampo(campo));
        continue;
      }

      final esquerdo = campos[index + 1];
      final base = campo.chave.substring(0, campo.chave.length - 2);
      if (esquerdo.chave != '${base}_e') {
        widgets.add(_buildCampo(campo));
        continue;
      }

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCampoMultiplaEscolha(esquerdo, compacto: true),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildCampoMultiplaEscolha(campo, compacto: true)),
          ],
        ),
      );
      index++;
    }

    return widgets;
  }

  Widget _buildCampoMultiplaEscolha(_PdfCampo campo, {bool compacto = false}) {
    final valores = _multiSelectValues[campo.chave];
    final selecionada = valores != null && valores.isNotEmpty
        ? valores.first
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: campo.rotulo,
          contentPadding: compacto
              ? const EdgeInsets.fromLTRB(8, 14, 8, 8)
              : const EdgeInsets.fromLTRB(12, 14, 12, 10),
        ),
        child: Column(
          children: campo.opcoes.map((opcao) {
            if (campo.selecaoUnica) {
              final selected = selecionada == opcao.chave;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? VitalisColors.verdeEsmeralda : null,
                  size: compacto ? 22 : 24,
                ),
                title: Text(
                  opcao.rotulo,
                  style: compacto ? const TextStyle(fontSize: 13) : null,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                horizontalTitleGap: compacto ? 6 : 16,
                visualDensity: VisualDensity.compact,
                onTap: () => _alternarOpcao(campo, opcao.chave, true),
              );
            }

            return CheckboxListTile(
              value: _opcaoSelecionada(campo, opcao.chave),
              onChanged: (selected) =>
                  _alternarOpcao(campo, opcao.chave, selected ?? false),
              title: Text(opcao.rotulo),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ),
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

enum _TipoCampo { texto, multiplaEscolha }

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
  final int? dia;
  final String? secao;
  final _TipoCampo tipo;
  final bool obrigatorio;
  final bool multilinha;
  final int? maxLinesPdf;
  final bool centralizadoVertical;
  final int? maxCaracteres;
  final bool selecaoUnica;
  final List<_PdfPosicao> linhasPdf;
  final List<_PdfOpcao> opcoes;
  final _PdfPosicao? posicao;

  const _PdfCampo({
    required this.chave,
    required this.rotulo,
    required this.icon,
    this.dia,
    this.secao,
    this.obrigatorio = false,
    this.multilinha = false,
    this.maxLinesPdf,
    this.centralizadoVertical = false,
    this.maxCaracteres,
    this.linhasPdf = const [],
    this.posicao,
  }) : tipo = _TipoCampo.texto,
       selecaoUnica = false,
       opcoes = const [];

  const _PdfCampo.multiplaEscolha({
    required this.chave,
    required this.rotulo,
    required this.icon,
    this.dia,
    this.secao,
    required this.opcoes,
    this.selecaoUnica = false,
  }) : tipo = _TipoCampo.multiplaEscolha,
       obrigatorio = false,
       multilinha = false,
       maxLinesPdf = null,
       centralizadoVertical = false,
       maxCaracteres = null,
       linhasPdf = const [],
       posicao = null;
}

class _PdfOpcao {
  final String chave;
  final String rotulo;
  final _PdfPosicao posicao;

  const _PdfOpcao({
    required this.chave,
    required this.rotulo,
    required this.posicao,
  });
}

class _PdfPosicao {
  final int pageIndex;
  final Rect bounds;

  const _PdfPosicao({required this.pageIndex, required this.bounds});
}

final List<_PdfModelo> _modelos = [
  _PdfModelo(
    id: 'termo_consentimento_imagem',
    titulo: 'Termo de Consentimento de Imagem',
    subtitulo: 'TERMO DE CONSENTIMENTO DE IMAGEM.pdf',
    assetPath: 'assets/pdfs/TERMO DE CONSENTIMENTO DE IMAGEM.pdf',
    nomeArquivoBase: 'termo-consentimento-imagem',
    campos: [
      _PdfCampo(
        chave: 'declarante',
        rotulo: 'Nome do declarante',
        icon: Icons.person_outline_rounded,
        obrigatorio: true,
        maxCaracteres: 48,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(65, 170.9, 373.5, 28.8),
        ),
      ),
      _PdfCampo(
        chave: 'local',
        rotulo: 'Local',
        icon: Icons.location_on_outlined,
        obrigatorio: true,
        maxCaracteres: 24,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(85.3, 225.1, 186.9, 28.8),
        ),
      ),
      _PdfCampo(
        chave: 'data_termo',
        rotulo: 'Data',
        icon: Icons.event_outlined,
        obrigatorio: true,
        maxCaracteres: 10,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(313.3, 225.1, 194.7, 28.8),
        ),
      ),
      _PdfCampo(
        chave: 'nome_paciente',
        rotulo: 'Nome do paciente',
        icon: Icons.badge_outlined,
        obrigatorio: true,
        maxCaracteres: 28,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(167, 323.2, 218, 18.3),
        ),
      ),
      _PdfCampo(
        chave: 'testemunha_1_nome',
        rotulo: 'Nome da testemunha 1',
        icon: Icons.person_add_alt_1_outlined,
        maxCaracteres: 25,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(89.2, 459.2, 194.6, 28.8),
        ),
      ),
      _PdfCampo(
        chave: 'testemunha_2_nome',
        rotulo: 'Nome da testemunha 2',
        icon: Icons.person_add_alt_1_outlined,
        maxCaracteres: 25,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(89.2, 654.3, 194.6, 28.8),
        ),
      ),
    ],
  ),
  _PdfModelo(
    id: 'consentimento_assistencia_fisioterapeutica',
    titulo: 'Consentimento para Assistencia Fisioterapeutica',
    subtitulo:
        'Termo de consentimento esclarecido para assistência fisioterapêutica.pdf',
    assetPath:
        'assets/pdfs/Termo de consentimento esclarecido para assistência fisioterapêutica.pdf',
    nomeArquivoBase: 'consentimento-assistencia-fisioterapeutica',
    campos: [
      _PdfCampo(
        chave: 'paciente_consentimento_fisioterapia',
        rotulo: 'Nome do paciente',
        icon: Icons.person_outline_rounded,
        obrigatorio: true,
        maxCaracteres: 54,
        posicao: _PdfPosicao(
          pageIndex: 0,
          bounds: Rect.fromLTWH(62.2, 135.2, 419.7, 28.8),
        ),
      ),
      _PdfCampo(
        chave: 'data_consentimento_fisioterapia',
        rotulo: 'Data',
        icon: Icons.event_outlined,
        obrigatorio: true,
        maxCaracteres: 10,
        posicao: _PdfPosicao(
          pageIndex: 1,
          bounds: Rect.fromLTWH(76.1, 436.4, 173.6, 15.3),
        ),
      ),
    ],
  ),
  _PdfModelo(
    id: 'ficha_avaliacao_pilates',
    titulo: 'Ficha de Avaliacao - Pilates',
    subtitulo: 'Ficha de Avaliação de Pilates.pdf',
    assetPath: 'assets/pdfs/Ficha de Avaliação de Pilates.pdf',
    nomeArquivoBase: 'ficha-avaliacao-pilates',
    campos: _avaliacaoPilatesCampos(),
  ),
  _PdfModelo(
    id: 'evolucao_diaria_pilates',
    titulo: 'Evolucao diaria - Pilates',
    subtitulo: 'Evolução diária - Pilates.pdf',
    assetPath: 'assets/pdfs/Evolução diária - Pilates.pdf',
    nomeArquivoBase: 'evolucao-diaria-pilates',
    campos: _evolucaoDiariaCampos(),
  ),
];

List<_PdfCampo> _avaliacaoPilatesCampos() {
  const identificacao = 'Identificacao e historia clinica';
  const exameFisico = 'Exame fisico';
  const vistaAnterior = 'Postural - Vista anterior';
  const vistaLateral = 'Postural - Vista lateral';
  const vistaPosterior = 'Postural - Vista posterior';
  const avaliacaoFuncional = 'Avaliacao funcional';

  return [
    _avTexto(
      'avaliacao_matricula',
      'Matricula',
      identificacao,
      0,
      const Rect.fromLTWH(106.42, 111.39, 90.36, 22),
      12,
    ),
    _avTexto(
      'avaliacao_data',
      'Data da avaliacao',
      identificacao,
      0,
      const Rect.fromLTWH(469.72, 111.82, 90.36, 22),
      10,
      obrigatorio: true,
    ),
    _avTextoLinhas(
      'avaliacao_nome',
      'Nome',
      identificacao,
      [
        _avPos(0, 89.31, 172.52, 462.89, 22),
        _avPos(0, 42.10, 190.76, 252.42, 22),
      ],
      72,
      obrigatorio: true,
    ),
    _avTexto(
      'avaliacao_idade',
      'Idade',
      identificacao,
      0,
      const Rect.fromLTWH(340.75, 190.70, 90.36, 22),
      3,
    ),
    _avTexto(
      'avaliacao_nascimento',
      'Data de nascimento',
      identificacao,
      0,
      const Rect.fromLTWH(470.57, 190.70, 80.99, 22),
      10,
    ),
    _avTextoLinhas('avaliacao_endereco', 'Endereco', identificacao, [
      _avPos(0, 112.53, 209.70, 439.78, 22),
      _avPos(0, 41.85, 227.67, 510.23, 22),
    ], 115),
    _avTexto(
      'avaliacao_profissao',
      'Profissao',
      identificacao,
      0,
      const Rect.fromLTWH(108.89, 246.66, 228.38, 22),
      29,
    ),
    _avTexto(
      'avaliacao_telefone',
      'Telefone',
      identificacao,
      0,
      const Rect.fromLTWH(401.53, 246.09, 150.94, 22),
      19,
    ),
    _avTexto(
      'avaliacao_email',
      'E-mail',
      identificacao,
      0,
      const Rect.fromLTWH(90.20, 264.96, 461.64, 22),
      59,
    ),
    _avSelecao(
      'avaliacao_praticou_pilates',
      'Ja praticou Pilates?',
      identificacao,
      [
        _avOp('sim', 'Sim', 0, 263.13, 287.41, 14.25, 15.19),
        _avOp('nao', 'Nao', 0, 316.78, 287.47, 14.25, 15.19),
      ],
    ),
    _avTexto(
      'avaliacao_tempo_pilates',
      'Quanto tempo?',
      identificacao,
      0,
      const Rect.fromLTWH(477.35, 284.37, 74.72, 22),
      9,
    ),
    _avTexto(
      'avaliacao_queixa',
      'Queixa principal',
      identificacao,
      0,
      const Rect.fromLTWH(152.65, 341.71, 399.79, 22),
      51,
    ),
    _avTextoLinhas('avaliacao_hda', 'HDA', identificacao, [
      _avPos(0, 82.24, 360.26, 469.73, 22.32),
      _avPos(0, 42.08, 378.92, 509.59, 22.32),
      _avPos(0, 41.71, 396.92, 508.72, 22.32),
    ], 185),
    _avTextoLinhas('avaliacao_hpp', 'HPP', identificacao, [
      _avPos(0, 82.30, 415.93, 469.15, 23.78),
      _avPos(0, 41.57, 433.74, 508.13, 23.77),
      _avPos(0, 41.31, 451.95, 508.97, 23.78),
    ], 185),
    _avTextoLinhas('avaliacao_hf', 'HF', identificacao, [
      _avPos(0, 74.11, 471.45, 478.17, 22.68),
      _avPos(0, 42.11, 490.05, 509.30, 22.68),
    ], 125),
    _avTextoLinhas('avaliacao_medicamentos', 'Medicamentos', identificacao, [
      _avPos(0, 135.56, 508.25, 414.72, 22.68),
      _avPos(0, 42.35, 526.83, 508.39, 22.68),
    ], 116),
    _avTextoLinhas('avaliacao_exames', 'Exames complementares', identificacao, [
      _avPos(0, 213.45, 544.90, 337.13, 24.07),
      _avPos(0, 42.05, 563.41, 509.35, 24.07),
      _avPos(0, 42.05, 583.19, 509.05, 24.07),
    ], 172),
    _avSelecao(
      'avaliacao_atividade_fisica',
      'Pratica atividade fisica?',
      identificacao,
      [
        _avOp('sim', 'Sim', 0, 258.41, 605.59, 14.25, 15.19),
        _avOp('nao', 'Nao', 0, 317.66, 605.87, 14.25, 15.19),
      ],
    ),
    _avTextoLinhas(
      'avaliacao_atividade_qual',
      'Qual atividade?',
      identificacao,
      [
        _avPos(0, 409.35, 601.52, 142.80, 24.07),
        _avPos(0, 41.76, 619.97, 508.76, 24.07),
      ],
      84,
    ),
    _PdfCampo.multiplaEscolha(
      chave: 'avaliacao_objetivos',
      rotulo: 'Objetivos',
      icon: Icons.flag_outlined,
      secao: identificacao,
      opcoes: [
        _avOp('postural', 'Melhora postural', 0, 47.29, 684.36, 14.25, 15.19),
        _avOp('stress', 'Alivio do stress', 0, 189.80, 684.14, 14.25, 15.19),
        _avOp('alongamento', 'Alongamento', 0, 326.82, 684.14, 14.25, 15.19),
        _avOp('dor', 'Alivio da dor', 0, 449.87, 684.14, 14.25, 15.19),
        _avOp(
          'condicionamento',
          'Melhora do condicionamento fisico',
          0,
          47.16,
          703.10,
          14.25,
          15.19,
        ),
        _avOp(
          'fortalecimento',
          'Fortalecimento muscular',
          0,
          373.66,
          703.92,
          14.25,
          15.19,
        ),
        _avOp('outros', 'Outros', 0, 47.16, 722.74, 14.25, 15.19),
      ],
    ),
    _avTexto(
      'avaliacao_objetivo_outro',
      'Outro objetivo',
      identificacao,
      0,
      const Rect.fromLTWH(117.05, 718.49, 142.80, 24.07),
      18,
    ),
    _avTexto(
      'avaliacao_pa',
      'PA',
      exameFisico,
      1,
      const Rect.fromLTWH(70.04, 89.82, 88.78, 24.07),
      11,
    ),
    _avTexto(
      'avaliacao_fc',
      'FC',
      exameFisico,
      1,
      const Rect.fromLTWH(278.87, 90.05, 66.61, 24.07),
      8,
    ),
    _avTexto(
      'avaliacao_peso',
      'Peso',
      exameFisico,
      1,
      const Rect.fromLTWH(465.16, 90.86, 78.79, 24.07),
      10,
    ),
    _avTexto(
      'avaliacao_altura',
      'Altura',
      exameFisico,
      1,
      const Rect.fromLTWH(90.92, 110.60, 73.48, 24.07),
      9,
    ),
    _avTexto(
      'avaliacao_imc',
      'IMC',
      exameFisico,
      1,
      const Rect.fromLTWH(285.14, 109.98, 58.18, 24.07),
      7,
    ),
    _avTexto(
      'avaliacao_eva',
      'EVA',
      exameFisico,
      1,
      const Rect.fromLTWH(463.07, 110.16, 88.15, 24.07),
      11,
    ),
    _avSelecao('avaliacao_respiracao', 'Padrao respiratorio', exameFisico, [
      _avOp('apical', 'Apical', 1, 188.85, 154.79, 12.25, 13.84),
      _avOp('diafragmatico', 'Diafragmatico', 1, 251.98, 154.79, 12.25, 13.84),
      _avOp('misto', 'Misto', 1, 363.11, 154.79, 12.25, 13.84),
      _avOp('paradoxal', 'Paradoxal', 1, 421.44, 154.79, 12.25, 13.84),
    ]),
    ..._avaliacaoVistaAnterior(vistaAnterior),
    ..._avaliacaoVistaLateral(vistaLateral),
    ..._avaliacaoVistaPosterior(vistaPosterior),
    _avTextoLinhas(
      'avaliacao_amplitude',
      'Amplitude de movimento',
      avaliacaoFuncional,
      [
        _avPos(2, 36.84, 741.16, 508.77, 24.07),
        _avPos(2, 36.84, 760.36, 508.77, 24.07),
        _avPos(2, 36.84, 777.81, 508.77, 24.07),
      ],
      195,
    ),
    ..._avaliacaoTextosFinais(avaliacaoFuncional),
  ];
}

List<_PdfCampo> _avaliacaoVistaAnterior(String secao) {
  return [
    _avSelecao('av_cabeca', 'Cabeca', secao, [
      _avOp('media', 'Linha media', 1, 198.25, 249.61),
      _avOp('rodada_d', 'Rodada para direita', 1, 198.25, 263.90),
      _avOp('rodada_e', 'Rodada para esquerda', 1, 302.69, 263.90),
      _avOp('fletida_d', 'Fletida para direita', 1, 198.25, 278.52),
      _avOp('fletida_e', 'Fletida para esquerda', 1, 302.69, 278.52),
    ]),
    ..._avSelecaoDE(
      'av_ombros',
      'Ombros',
      secao,
      1,
      198.25,
      234.47,
      [296.30, 310.59, 325.21],
      ['Alinhado', 'Elevado', 'Deprimido'],
    ),
    ..._avSelecaoDE(
      'av_claviculas',
      'Claviculas',
      secao,
      1,
      198.25,
      234.47,
      [343.43, 357.72, 372.34],
      ['Alinhada', 'Verticalizada (>20 graus)', 'Horizontalizada (<20 graus)'],
    ),
    _avSelecao('av_torax', 'Torax', secao, [
      _avOp('normal', 'Normal', 1, 198.25, 389.39),
      _avOp('peito_pombo', 'Peito de pombo', 1, 267.93, 389.39),
      _avOp('tonel', 'Tonel', 1, 387.78, 389.39),
    ]),
    ..._avSelecaoDE(
      'av_bracos',
      'Bracos',
      secao,
      1,
      198.25,
      234.47,
      [407.58, 421.87, 436.48],
      ['Neutro', 'Pronado', 'Supinado'],
    ),
    _avSelecao('av_triangulo_tales', 'Triangulo de Tales', secao, [
      _avOp('simetrico', 'Simetrico', 1, 198.25, 454.08),
      _avOp('diminuido_d', 'Diminuido D', 1, 267.93, 454.08),
      _avOp('diminuido_e', 'Diminuido E', 1, 365.67, 454.08),
    ]),
    _avSelecao('av_pelve', 'Pelve', secao, [
      _avOp('alinhada', 'Alinhada', 1, 198.25, 471.98),
      _avOp('rodada_anterior', 'Rodada anterior', 1, 267.93, 471.98),
    ]),
    _avSelecao('av_eias', 'EIAS', secao, [
      _avOp('alinhado', 'Alinhado', 1, 198.25, 490.34),
      _avOp('elevada_d', 'Elevada D', 1, 198.25, 504.63),
      _avOp('elevada_e', 'Elevada E', 1, 198.25, 519.25),
    ]),
    _avSelecao('av_massa_quadriceps', 'Massa de quadriceps', secao, [
      _avOp('simetrico', 'Simetrico', 1, 198.25, 536.01),
      _avOp('assimetrico', 'Assimetrico', 1, 268.07, 536.01),
    ]),
    ..._avSelecaoDE(
      'av_patelas',
      'Patelas',
      secao,
      1,
      198.25,
      234.47,
      [554.48, 568.78, 583.39],
      ['Simetrica', 'Elevada', 'Lateralizada'],
    ),
    ..._avSelecaoDE(
      'av_joelhos',
      'Joelhos',
      secao,
      1,
      198.25,
      234.47,
      [600.74, 615.03, 629.65],
      ['Normal', 'Valgo', 'Varo'],
    ),
    ..._avSelecaoDE(
      'av_halux',
      'Halux',
      secao,
      1,
      198.25,
      234.47,
      [647.28, 661.58, 676.19],
      ['Normal', 'Valgo', 'Varo'],
    ),
    ..._avSelecaoDE(
      'av_pes_posicao',
      'Pes - posicao',
      secao,
      1,
      198.25,
      234.47,
      [694.27, 708.56, 723.18],
      ['Normal', 'Pronado', 'Supinado'],
    ),
    ..._avSelecaoDE(
      'av_pes_arco',
      'Pes - arco',
      secao,
      1,
      198.25,
      234.47,
      [751.28, 765.58, 780.19],
      ['Arco normal', 'Arco cavo', 'Arco plano'],
    ),
  ];
}

List<_PdfCampo> _avaliacaoVistaLateral(String secao) {
  return [
    _avSelecao('al_cabeca', 'Cabeca', secao, [
      _avOp('alinhada', 'Alinhada', 2, 198.44, 117.83),
      _avOp('protusa', 'Protusa', 2, 268.98, 117.83),
      _avOp('retraida', 'Retraida', 2, 335.02, 117.83),
    ]),
    ..._avSelecaoDE(
      'al_cervical',
      'Cervical',
      secao,
      2,
      198.44,
      235.53,
      [136.01, 150.30, 164.92],
      ['Normal', 'Hiperlordose', 'Retificada'],
    ),
    ..._avSelecaoDE(
      'al_ombros',
      'Ombros',
      secao,
      2,
      198.44,
      235.53,
      [182.27, 196.56, 211.18],
      ['Normal', 'Protuso', 'Retruso'],
    ),
    _avSelecao('al_toracica', 'Toracica', secao, [
      _avOp('normal', 'Normal', 2, 198.44, 228.23),
      _avOp('hipercifose', 'Hipercifose', 2, 269.86, 228.23),
      _avOp('retificada', 'Retificada', 2, 361.64, 228.23),
    ]),
    ..._avSelecaoDE(
      'al_lombar',
      'Lombar',
      secao,
      2,
      198.44,
      235.53,
      [246.85, 261.14, 275.76],
      ['Normal', 'Hiperlordose', 'Retificada'],
    ),
    _avSelecao('al_pelve', 'Pelve', secao, [
      _avOp('neutra', 'Neutra', 2, 198.44, 304.16),
      _avOp('anteversao', 'Anteversao', 2, 269.86, 304.16),
      _avOp('retroversao', 'Retroversao', 2, 361.64, 304.16),
    ]),
    ..._avSelecaoDE(
      'al_joelhos',
      'Joelhos',
      secao,
      2,
      198.44,
      235.53,
      [334.56, 348.85, 363.47],
      ['Normal', 'Hiperextensao', 'Genuflexo'],
    ),
  ];
}

List<_PdfCampo> _avaliacaoVistaPosterior(String secao) {
  return [
    ..._avSelecaoDE(
      'ap_escapulas',
      'Escapulas',
      secao,
      2,
      209.35,
      261.86,
      [434.48, 448.78, 463.39, 476.96, 491.25, 505.87],
      ['Normal', 'Abduzida', 'Aduzida', 'Elevada', 'Deprimida', 'Alada'],
    ),
    ..._avSelecaoDE(
      'ap_processo_espinhoso',
      'Processo espinhoso',
      secao,
      2,
      209.35,
      261.86,
      [522.96, 537.58],
      ['Alinhado', 'Desvio'],
    ),
    ..._avSelecaoDE(
      'ap_eips',
      'EIPS',
      secao,
      2,
      209.35,
      261.86,
      [555.54, 570.16, 583.68],
      ['Alinhada', 'Elevada D', 'Elevada E'],
    ),
    _avSelecao('ap_prega_glutea', 'Prega glutea', secao, [
      _avOp('simetrico', 'Simetrico', 2, 209.35, 601.87),
      _avOp('assimetrico', 'Assimetrico', 2, 300.55, 601.87),
    ]),
    ..._avSelecaoDE(
      'ap_massa_triceps',
      'Massa do triceps sural',
      secao,
      2,
      209.35,
      261.86,
      [619.98, 634.59, 648.12],
      ['Simetrico', 'Hipotrofica', 'Hipertrofica'],
    ),
    ..._avSelecaoDE(
      'ap_tendao_calcaneo',
      'Tendao do calcaneo',
      secao,
      2,
      209.35,
      261.86,
      [666.67, 681.28, 694.81],
      ['Normal', 'Valgo', 'Varo'],
    ),
  ];
}

List<_PdfCampo> _avaliacaoTextosFinais(String secao) {
  const grupos = [
    ('avaliacao_marcha', 'Descricao da marcha', 83.49),
    ('avaliacao_equilibrio', 'Equilibrio', 202.46),
    ('avaliacao_flexibilidade', 'Flexibilidade', 320.87),
    ('avaliacao_forca', 'Forca muscular', 439.23),
  ];

  return grupos.map((grupo) {
    final linhas = List.generate(
      5,
      (index) => _avPos(
        3,
        43.36,
        grupo.$3 + [0.0, 19.2, 36.66, 54.46, 73.66][index],
        508.76,
        24.07,
      ),
    );
    return _avTextoLinhas(grupo.$1, grupo.$2, secao, linhas, 325);
  }).toList();
}

List<_PdfCampo> _avSelecaoDE(
  String chave,
  String rotulo,
  String secao,
  int pageIndex,
  double xDireito,
  double xEsquerdo,
  List<double> ys,
  List<String> rotulos,
) {
  return [
    _avSelecao(
      '${chave}_d',
      '$rotulo - Direito',
      secao,
      List.generate(
        rotulos.length,
        (index) =>
            _avOp('d_$index', rotulos[index], pageIndex, xDireito, ys[index]),
      ),
    ),
    _avSelecao(
      '${chave}_e',
      '$rotulo - Esquerdo',
      secao,
      List.generate(
        rotulos.length,
        (index) =>
            _avOp('e_$index', rotulos[index], pageIndex, xEsquerdo, ys[index]),
      ),
    ),
  ];
}

_PdfCampo _avSelecao(
  String chave,
  String rotulo,
  String secao,
  List<_PdfOpcao> opcoes,
) {
  return _PdfCampo.multiplaEscolha(
    chave: chave,
    rotulo: rotulo,
    icon: Icons.radio_button_checked_rounded,
    secao: secao,
    selecaoUnica: true,
    opcoes: opcoes,
  );
}

_PdfCampo _avTexto(
  String chave,
  String rotulo,
  String secao,
  int pageIndex,
  Rect bounds,
  int maxCaracteres, {
  bool obrigatorio = false,
}) {
  return _PdfCampo(
    chave: chave,
    rotulo: rotulo,
    icon: Icons.edit_outlined,
    secao: secao,
    obrigatorio: obrigatorio,
    centralizadoVertical: true,
    maxCaracteres: maxCaracteres,
    posicao: _PdfPosicao(
      pageIndex: pageIndex,
      bounds: bounds.shift(const Offset(0, _avaliacaoTextOffsetY)),
    ),
  );
}

_PdfCampo _avTextoLinhas(
  String chave,
  String rotulo,
  String secao,
  List<_PdfPosicao> linhas,
  int maxCaracteres, {
  bool obrigatorio = false,
}) {
  return _PdfCampo(
    chave: chave,
    rotulo: rotulo,
    icon: Icons.notes_outlined,
    secao: secao,
    obrigatorio: obrigatorio,
    multilinha: true,
    maxLinesPdf: linhas.length,
    maxCaracteres: maxCaracteres,
    linhasPdf: linhas
        .map(
          (linha) => _PdfPosicao(
            pageIndex: linha.pageIndex,
            bounds: linha.bounds.shift(const Offset(0, _avaliacaoTextOffsetY)),
          ),
        )
        .toList(),
  );
}

_PdfPosicao _avPos(
  int pageIndex,
  double x,
  double y,
  double width,
  double height,
) {
  return _PdfPosicao(
    pageIndex: pageIndex,
    bounds: Rect.fromLTWH(x, y, width, height),
  );
}

_PdfOpcao _avOp(
  String chave,
  String rotulo,
  int pageIndex,
  double x,
  double y, [
  double width = 9.53,
  double height = 11.55,
]) {
  return _PdfOpcao(
    chave: chave,
    rotulo: rotulo,
    posicao: _PdfPosicao(
      pageIndex: pageIndex,
      bounds: Rect.fromLTWH(x, y + _avaliacaoCheckboxOffsetY, width, height),
    ),
  );
}

List<_PdfCampo> _evolucaoDiariaCampos() {
  return [
    _PdfCampo(
      chave: 'paciente_evolucao',
      rotulo: 'Paciente',
      icon: Icons.person_outline_rounded,
      obrigatorio: true,
      centralizadoVertical: true,
      maxCaracteres: 23,
      posicao: _PdfPosicao(
        pageIndex: 0,
        bounds: Rect.fromLTWH(
          102.48,
          103.86 + _evolucaoTextOffsetY,
          179.04,
          18.36,
        ),
      ),
    ),
    ..._camposEvolucao(numero: 1, pageIndex: 0, segundoBloco: false),
    ..._camposEvolucao(numero: 2, pageIndex: 0, segundoBloco: true),
    ..._camposEvolucao(numero: 3, pageIndex: 1, segundoBloco: false),
    ..._camposEvolucao(numero: 4, pageIndex: 1, segundoBloco: true),
    ..._camposEvolucao(numero: 5, pageIndex: 2, segundoBloco: false),
    ..._camposEvolucao(numero: 6, pageIndex: 2, segundoBloco: true),
    ..._camposEvolucao(numero: 7, pageIndex: 3, segundoBloco: false),
    ..._camposEvolucao(numero: 8, pageIndex: 3, segundoBloco: true),
    ..._camposEvolucao(numero: 9, pageIndex: 4, segundoBloco: false),
    ..._camposEvolucao(numero: 10, pageIndex: 4, segundoBloco: true),
  ];
}

List<_PdfCampo> _camposEvolucao({
  required int numero,
  required int pageIndex,
  required bool segundoBloco,
}) {
  final prefixo = 'evolucao_$numero';
  final primeiraPagina = pageIndex == 0;
  final dataBounds = segundoBloco
      ? Rect.fromLTWH(78.16, primeiraPagina ? 415.98 : 474.63, 83.36, 18.36)
      : numero == 1
      ? const Rect.fromLTWH(322.68, 103.86, 80.54, 18.36)
      : const Rect.fromLTWH(80.41, 103.86, 80.54, 18.36);
  final outrosBounds = segundoBloco
      ? Rect.fromLTWH(113.68, primeiraPagina ? 533.10 : 594.10, 434.28, 17.16)
      : const Rect.fromLTWH(115.68, 222.34, 434.28, 18.36);
  final condutasLinhas = segundoBloco
      ? [
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: Rect.fromLTWH(
              161.64,
              primeiraPagina ? 551.46 : 612.46,
              388.32,
              18.36,
            ),
          ),
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: Rect.fromLTWH(
              45.60,
              primeiraPagina ? 572.10 : 633.10,
              504.36,
              primeiraPagina ? 17.28 : 17.28,
            ),
          ),
        ]
      : [
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: const Rect.fromLTWH(161.64, 242.33, 388.32, 18.36),
          ),
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: const Rect.fromLTWH(45.60, 260.46, 504.36, 18.36),
          ),
        ];
  final observacoesLinhas = segundoBloco
      ? [
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: Rect.fromLTWH(
              136.68,
              primeiraPagina ? 591.46 : 652.46,
              413.28,
              18.36,
            ),
          ),
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: Rect.fromLTWH(
              45.60,
              primeiraPagina ? 611.10 : 672.10,
              504.36,
              17.28,
            ),
          ),
        ]
      : [
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: const Rect.fromLTWH(136.68, 281.02, 413.28, 18.36),
          ),
          _PdfPosicao(
            pageIndex: pageIndex,
            bounds: const Rect.fromLTWH(45.60, 300.46, 504.36, 18.36),
          ),
        ];
  final dataBoundsAjustados = dataBounds.shift(
    const Offset(0, _evolucaoTextOffsetY),
  );
  final outrosBoundsAjustados = outrosBounds.shift(
    const Offset(0, _evolucaoTextOffsetY),
  );
  final condutasLinhasAjustadas = condutasLinhas
      .map(
        (posicao) => _PdfPosicao(
          pageIndex: posicao.pageIndex,
          bounds: posicao.bounds.shift(const Offset(0, _evolucaoTextOffsetY)),
        ),
      )
      .toList();
  final observacoesLinhasAjustadas = observacoesLinhas
      .map(
        (posicao) => _PdfPosicao(
          pageIndex: posicao.pageIndex,
          bounds: posicao.bounds.shift(const Offset(0, _evolucaoTextOffsetY)),
        ),
      )
      .toList();

  return [
    _PdfCampo(
      chave: 'data_evolucao_$numero',
      rotulo: 'Data',
      icon: Icons.event_outlined,
      dia: numero,
      centralizadoVertical: true,
      maxCaracteres: 10,
      posicao: _PdfPosicao(pageIndex: pageIndex, bounds: dataBoundsAjustados),
    ),
    _PdfCampo.multiplaEscolha(
      chave: '${prefixo}_aparelhos',
      rotulo: 'Aparelhos',
      icon: Icons.fitness_center_outlined,
      dia: numero,
      opcoes: _opcoesAparelhos(pageIndex, segundoBloco),
    ),
    _PdfCampo.multiplaEscolha(
      chave: '${prefixo}_alongamentos',
      rotulo: 'Alongamentos',
      icon: Icons.accessibility_new_outlined,
      dia: numero,
      opcoes: _opcoesAlongamentos(pageIndex, segundoBloco),
    ),
    _PdfCampo(
      chave: '${prefixo}_outros',
      rotulo: 'Outros',
      icon: Icons.note_add_outlined,
      dia: numero,
      centralizadoVertical: true,
      maxCaracteres: 54,
      posicao: _PdfPosicao(pageIndex: pageIndex, bounds: outrosBoundsAjustados),
    ),
    _PdfCampo(
      chave: '${prefixo}_condutas',
      rotulo: 'Outras condutas',
      icon: Icons.assignment_outlined,
      dia: numero,
      multilinha: true,
      maxLinesPdf: 2,
      maxCaracteres: 108,
      linhasPdf: condutasLinhasAjustadas,
    ),
    _PdfCampo(
      chave: '${prefixo}_observacoes',
      rotulo: 'Observacoes',
      icon: Icons.notes_outlined,
      dia: numero,
      multilinha: true,
      maxLinesPdf: 2,
      maxCaracteres: 114,
      linhasPdf: observacoesLinhasAjustadas,
    ),
  ];
}

List<_PdfOpcao> _opcoesAparelhos(int pageIndex, bool segundoBloco) {
  final primeiraPagina = pageIndex == 0;
  return [
    _opcao(
      'reformer',
      'Reformer',
      pageIndex,
      segundoBloco ? 123.32 : 123.15,
      segundoBloco
          ? primeiraPagina
                ? 496.73
                : 555.73
          : 185.33,
      segundoBloco ? 12.47 : 13.20,
      segundoBloco ? 14.95 : 13.20,
    ),
    _opcao(
      'barrel',
      'Barrel',
      pageIndex,
      segundoBloco ? 206.83 : 206.39,
      segundoBloco
          ? primeiraPagina
                ? 498.74
                : 556.74
          : 185.89,
      segundoBloco ? 11.16 : 12.33,
      segundoBloco ? 11.16 : 12.33,
    ),
    _opcao(
      'cadillac',
      'Cadillac',
      pageIndex,
      segundoBloco ? 268.76 : 269.46,
      segundoBloco
          ? primeiraPagina
                ? 498.18
                : 557.18
          : 185.99,
      segundoBloco ? 11.89 : 12.00,
      segundoBloco ? 11.89 : 12.00,
    ),
    _opcao(
      'chair',
      'Chair',
      pageIndex,
      segundoBloco ? 347.07 : 348.20,
      segundoBloco
          ? primeiraPagina
                ? 497.18
                : 556.18
          : 185.75,
      segundoBloco ? 12.70 : 11.24,
      segundoBloco ? 13.58 : 11.24,
    ),
    _opcao(
      'solo',
      'Solo',
      pageIndex,
      segundoBloco ? 406.25 : 406.41,
      segundoBloco
          ? primeiraPagina
                ? 497.56
                : 556.56
          : 185.55,
      segundoBloco ? 11.40 : 12.11,
      segundoBloco ? 11.60 : 12.11,
    ),
    _opcao(
      'outros',
      'Outros',
      pageIndex,
      segundoBloco ? 46.98 : 48.46,
      segundoBloco
          ? primeiraPagina
                ? 535.63
                : 594.63
          : 224.52,
      segundoBloco ? 14.13 : 12.69,
      segundoBloco ? 14.40 : 12.69,
    ),
  ];
}

List<_PdfOpcao> _opcoesAlongamentos(int pageIndex, bool segundoBloco) {
  final primeiraPagina = pageIndex == 0;
  return [
    _opcao(
      'membros_superiores',
      'Membros superiores',
      pageIndex,
      segundoBloco ? 152.19 : 152.05,
      segundoBloco
          ? primeiraPagina
                ? 516.76
                : 576.11
          : 205.66,
      segundoBloco ? 12.11 : 12.55,
      segundoBloco ? 12.69 : 12.55,
    ),
    _opcao(
      'membros_inferiores',
      'Membros inferiores',
      pageIndex,
      segundoBloco
          ? primeiraPagina
                ? 304.77
                : 305.11
          : 304.71,
      segundoBloco
          ? primeiraPagina
                ? 517.97
                : 576.97
          : 204.71,
      segundoBloco
          ? primeiraPagina
                ? 11.89
                : 11.54
          : 12.87,
      segundoBloco
          ? primeiraPagina
                ? 11.89
                : 11.89
          : 12.87,
    ),
  ];
}

_PdfOpcao _opcao(
  String chave,
  String rotulo,
  int pageIndex,
  double x,
  double y,
  double width,
  double height,
) {
  return _PdfOpcao(
    chave: chave,
    rotulo: rotulo,
    posicao: _PdfPosicao(
      pageIndex: pageIndex,
      bounds: Rect.fromLTWH(x, y + _evolucaoCheckboxOffsetY, width, height),
    ),
  );
}

String _formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

int _calcularIdade(DateTime nascimento) {
  final hoje = DateTime.now();
  var idade = hoje.year - nascimento.year;
  if (hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
    idade--;
  }
  return idade;
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
