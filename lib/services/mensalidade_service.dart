import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'caixa_service.dart';

class MensalidadeService {
  MensalidadeService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _mensalidadesRef =>
      _firestore.collection('mensalidades');

  static CollectionReference<Map<String, dynamic>> get _pagamentosRef =>
      _firestore.collection('pagamentos');

  static CollectionReference<Map<String, dynamic>> get _clientesRef =>
      _firestore.collection('clientes');

  static CollectionReference<Map<String, dynamic>> get _servicosRef =>
      _firestore.collection('servicos');

  static CollectionReference<Map<String, dynamic>>
  get _movimentacoesFinanceirasRef =>
      _firestore.collection('movimentacoes_financeiras');

  static String gerarCompetencia(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    return '${data.year}-$mes';
  }

  static bool isMensalidade(String tipoCobranca) {
    return tipoCobranca == 'mensalidade';
  }

  static double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  static int _toInt(dynamic valor, {int padrao = 0}) {
    if (valor == null) return padrao;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString()) ?? padrao;
  }

  static double calcularValorFinal({
    required double valorBase,
    required double desconto,
    required double juros,
  }) {
    final valorFinal = valorBase - desconto + juros;
    return valorFinal < 0 ? 0 : valorFinal;
  }

  static int _diasNoMes(int ano, int mes) {
    return DateTime(ano, mes + 1, 0).day;
  }

  static DateTime _competenciaParaData(String competencia) {
    final partes = competencia.split('-');
    if (partes.length != 2) {
      throw Exception('Competência inválida: $competencia');
    }

    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);

    if (ano == null || mes == null || mes < 1 || mes > 12) {
      throw Exception('Competência inválida: $competencia');
    }

    return DateTime(ano, mes, 1);
  }

  static String _somarMesesCompetencia(String competencia, int meses) {
    final base = _competenciaParaData(competencia);
    return gerarCompetencia(DateTime(base.year, base.month + meses, 1));
  }

  static DateTime _somarMesesVencimento({
    required DateTime vencimentoBase,
    required int diaReferencia,
    int meses = 1,
  }) {
    final baseProximoMes = DateTime(
      vencimentoBase.year,
      vencimentoBase.month + meses,
      1,
    );

    final ultimoDia = _diasNoMes(baseProximoMes.year, baseProximoMes.month);
    final dia = min(max(diaReferencia, 1), ultimoDia);

    return DateTime(baseProximoMes.year, baseProximoMes.month, dia);
  }

  static int _compararCompetencia(String a, String b) {
    final da = _competenciaParaData(a);
    final db = _competenciaParaData(b);

    if (da.year != db.year) return da.year.compareTo(db.year);
    return da.month.compareTo(db.month);
  }

  static bool _mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarMensalidades() {
    // A ordenacao por createdAt ocultava documentos antigos sem esse campo,
    // e o limite fixo deixava de fora mensalidades acima dos 200 registros.
    return _mensalidadesRef.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarClientes({
    int limite = 500,
  }) {
    return _clientesRef.orderBy('nome').limit(limite).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarServicos({
    int limite = 300,
  }) {
    return _servicosRef.orderBy('nome').limit(limite).snapshots();
  }

  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _buscarPendenciaAberta({
    required String clienteId,
    required String servicoId,
    required String competencia,
    required String tipoCobranca,
    DateTime? dataServico,
  }) async {
    Query<Map<String, dynamic>> query = _mensalidadesRef
        .where('clienteId', isEqualTo: clienteId)
        .where('servicoId', isEqualTo: servicoId)
        .where('status', isEqualTo: 'pendente');

    if (isMensalidade(tipoCobranca)) {
      query = query.where('competencia', isEqualTo: competencia);
    } else if (dataServico != null) {
      final inicio = DateTime(
        dataServico.year,
        dataServico.month,
        dataServico.day,
      );
      final fim = inicio.add(const Duration(days: 1));

      query = query
          .where(
            'dataServico',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
          )
          .where('dataServico', isLessThan: Timestamp.fromDate(fim));
    }

    final snap = await query.limit(1).get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  static Future<void> _criarProximaMensalidadeSeNaoExistir({
    required String clienteId,
    required String nomeCliente,
    required String servicoId,
    required String nomeServico,
    required double valorUnitario,
    required int quantidade,
    required int diaVencimento,
    required bool ativa,
    required String competenciaBase,
    required DateTime vencimentoBase,
    WriteBatch? batch,
    dynamic createdAtValue,
    dynamic updatedAtValue,
  }) async {
    final proximaCompetencia = _somarMesesCompetencia(competenciaBase, 1);

    final proximoVencimento = _somarMesesVencimento(
      vencimentoBase: vencimentoBase,
      diaReferencia: diaVencimento,
      meses: 1,
    );

    final jaExiste = await _mensalidadesRef
        .where('clienteId', isEqualTo: clienteId)
        .where('servicoId', isEqualTo: servicoId)
        .where('competencia', isEqualTo: proximaCompetencia)
        .limit(1)
        .get();

    if (jaExiste.docs.isNotEmpty) return;

    final quantidadeSegura = quantidade < 1 ? 1 : quantidade;
    final valorBase = valorUnitario * quantidadeSegura;

    final novaRef = _mensalidadesRef.doc();

    final payload = {
      'clienteId': clienteId,
      'nomeCliente': nomeCliente,
      'servicoId': servicoId,
      'nomeServico': nomeServico,
      'tipoCobranca': 'mensalidade',
      'valorUnitario': valorUnitario,
      'quantidade': quantidadeSegura,
      'valorBase': valorBase,
      'valorFinal': valorBase,
      'diaVencimento': diaVencimento,
      'competencia': proximaCompetencia,
      'vencimento': Timestamp.fromDate(proximoVencimento),
      'dataServico': null,
      'status': 'pendente',
      'ativa': ativa,
      'desconto': 0.0,
      'juros': 0.0,
      'formaPagamento': null,
      'dataPagamento': null,
      'createdAt': createdAtValue ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAtValue ?? FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.set(novaRef, payload);
    } else {
      await novaRef.set(payload);
    }
  }

  static Future<void> criarMensalidade({
    required String clienteId,
    required String nomeCliente,
    required String servicoId,
    required String nomeServico,
    required double valorUnitario,
    required int quantidade,
    required String tipoCobranca,
    required String competenciaInicial,
    required DateTime dataServico,
    DateTime? vencimentoInicial,
    bool registrarPagamentoAgora = false,
    String? formaPagamento,
    double descontoCadastro = 0,
    double jurosCadastro = 0,
  }) async {
    final tipo = tipoCobranca.isEmpty ? 'mensalidade' : tipoCobranca;
    final mensalidade = isMensalidade(tipo);

    if (mensalidade && vencimentoInicial == null) {
      throw Exception('Informe o vencimento da mensalidade.');
    }

    final pendenteExistente = await _buscarPendenciaAberta(
      clienteId: clienteId,
      servicoId: servicoId,
      competencia: competenciaInicial,
      tipoCobranca: tipo,
      dataServico: dataServico,
    );

    if (pendenteExistente != null) {
      final existente = pendenteExistente.data();

      throw Exception(
        'Já existe um lançamento pendente encontrado.\n'
        'Cliente: ${existente['nomeCliente'] ?? '-'}\n'
        'Serviço: ${existente['nomeServico'] ?? '-'}\n'
        'Competência: ${existente['competencia'] ?? '-'}\n'
        'ID: ${pendenteExistente.id}',
      );
    }

    final quantidadeSegura = quantidade < 1 ? 1 : quantidade;
    final valorBase = valorUnitario * quantidadeSegura;
    final diaVencimento = mensalidade ? vencimentoInicial!.day : null;

    final doc = await _mensalidadesRef.add({
      'clienteId': clienteId,
      'nomeCliente': nomeCliente,
      'servicoId': servicoId,
      'nomeServico': nomeServico,
      'tipoCobranca': tipo,
      'valorUnitario': valorUnitario,
      'quantidade': quantidadeSegura,
      'valorBase': valorBase,
      'valorFinal': valorBase,
      'diaVencimento': diaVencimento,
      'competencia': competenciaInicial,
      'vencimento': mensalidade ? Timestamp.fromDate(vencimentoInicial!) : null,
      'dataServico': Timestamp.fromDate(dataServico),
      'status': 'pendente',
      'ativa': true,
      'desconto': 0.0,
      'juros': 0.0,
      'formaPagamento': null,
      'dataPagamento': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (registrarPagamentoAgora) {
      await registrarPagamento(
        mensalidadeId: doc.id,
        clienteId: clienteId,
        nomeCliente: nomeCliente,
        nomeServico: nomeServico,
        valorOriginal: valorBase,
        formaPagamento: formaPagamento ?? 'pix',
        desconto: descontoCadastro,
        juros: jurosCadastro,
      );
    }
  }

  static Future<void> atualizarMensalidade({
    required String id,
    required String clienteId,
    required String nomeCliente,
    required String servicoId,
    required String nomeServico,
    required double valorUnitario,
    required int quantidade,
    required String tipoCobranca,
    required String competencia,
    required DateTime dataServico,
    DateTime? vencimento,
    required bool ativa,
    String? formaPagamento,
    double? desconto,
    double? juros,
  }) async {
    final doc = await _mensalidadesRef.doc(id).get();
    final data = doc.data();

    if (data == null) {
      throw Exception('Mensalidade não encontrada.');
    }

    final tipo = tipoCobranca.isEmpty ? 'mensalidade' : tipoCobranca;
    final mensalidade = isMensalidade(tipo);

    if (mensalidade && vencimento == null) {
      throw Exception('Informe o vencimento da mensalidade.');
    }

    final status = (data['status'] ?? 'pendente').toString().toLowerCase();
    final estavaPago = status == 'pago';

    final competenciaAntiga = (data['competencia'] ?? '').toString();
    final clienteIdAntigo = (data['clienteId'] ?? '').toString();
    final servicoIdAntigo = (data['servicoId'] ?? '').toString();

    final quantidadeSegura = quantidade < 1 ? 1 : quantidade;
    final valorBase = valorUnitario * quantidadeSegura;
    final diaVencimento = mensalidade ? vencimento!.day : null;

    final descontoSeguro = desconto == null || desconto < 0 ? 0.0 : desconto;
    final jurosSeguro = juros == null || juros < 0 ? 0.0 : juros;

    final valorFinal = estavaPago
        ? calcularValorFinal(
            valorBase: valorBase,
            desconto: descontoSeguro,
            juros: jurosSeguro,
          )
        : valorBase;

    final batch = _firestore.batch();

    final updateMensalidade = <String, dynamic>{
      'clienteId': clienteId,
      'nomeCliente': nomeCliente,
      'servicoId': servicoId,
      'nomeServico': nomeServico,
      'tipoCobranca': tipo,
      'valorUnitario': valorUnitario,
      'quantidade': quantidadeSegura,
      'valorBase': valorBase,
      'valorFinal': valorFinal,
      'diaVencimento': diaVencimento,
      'competencia': competencia,
      'vencimento': mensalidade ? Timestamp.fromDate(vencimento!) : null,
      'dataServico': Timestamp.fromDate(dataServico),
      'ativa': ativa,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (estavaPago) {
      updateMensalidade.addAll({
        'desconto': descontoSeguro,
        'juros': jurosSeguro,
        'formaPagamento': formaPagamento,
      });
    }

    batch.update(_mensalidadesRef.doc(id), updateMensalidade);

    if (mensalidade && competenciaAntiga.isNotEmpty) {
      final futurasSnap = await _mensalidadesRef
          .where('clienteId', isEqualTo: clienteIdAntigo)
          .where('servicoId', isEqualTo: servicoIdAntigo)
          .where('status', isEqualTo: 'pendente')
          .where('tipoCobranca', isEqualTo: 'mensalidade')
          .get();

      final futuras =
          futurasSnap.docs.where((futura) {
            if (futura.id == id) return false;

            final comp = (futura.data()['competencia'] ?? '').toString();
            if (comp.isEmpty) return false;

            return _compararCompetencia(comp, competenciaAntiga) > 0;
          }).toList()..sort((a, b) {
            final ca = (a.data()['competencia'] ?? '').toString();
            final cb = (b.data()['competencia'] ?? '').toString();
            return _compararCompetencia(ca, cb);
          });

      for (int i = 0; i < futuras.length; i++) {
        final novaCompetencia = _somarMesesCompetencia(competencia, i + 1);
        final novoVencimento = _somarMesesVencimento(
          vencimentoBase: vencimento!,
          diaReferencia: diaVencimento ?? vencimento.day,
          meses: i + 1,
        );

        batch.update(futuras[i].reference, {
          'clienteId': clienteId,
          'nomeCliente': nomeCliente,
          'servicoId': servicoId,
          'nomeServico': nomeServico,
          'tipoCobranca': 'mensalidade',
          'valorUnitario': valorUnitario,
          'quantidade': quantidadeSegura,
          'valorBase': valorBase,
          'valorFinal': valorBase,
          'diaVencimento': diaVencimento,
          'competencia': novaCompetencia,
          'vencimento': Timestamp.fromDate(novoVencimento),
          'dataServico': Timestamp.fromDate(novoVencimento),
          'ativa': ativa,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    double ajusteCaixa = 0.0;
    String? tipoAjusteCaixa;

    if (estavaPago) {
      final formaAntiga = (data['formaPagamento'] ?? '').toString();
      final valorAntigo = _toDouble(data['valorFinal']);
      final formaNova = (formaPagamento ?? formaAntiga).toString();
      final tipoAntigo = (data['tipoCobranca'] ?? 'mensalidade').toString();
      final descontoAntigo = _toDouble(data['desconto']);
      final jurosAntigo = _toDouble(data['juros']);
      final dataServicoAntiga = data['dataServico'] is Timestamp
          ? (data['dataServico'] as Timestamp).toDate()
          : null;

      final dadosFinanceirosAlterados =
          clienteIdAntigo != clienteId ||
          (data['nomeCliente'] ?? '').toString() != nomeCliente ||
          servicoIdAntigo != servicoId ||
          (data['nomeServico'] ?? '').toString() != nomeServico ||
          tipoAntigo != tipo ||
          competenciaAntiga != competencia ||
          (valorAntigo - valorFinal).abs() > 0.001 ||
          (descontoAntigo - descontoSeguro).abs() > 0.001 ||
          (jurosAntigo - jurosSeguro).abs() > 0.001 ||
          formaAntiga != formaNova ||
          (!mensalidade &&
              (dataServicoAntiga == null ||
                  !_mesmoDia(dataServicoAntiga, dataServico)));

      if (dadosFinanceirosAlterados) {
        final pagamentoSnap = await _pagamentosRef
            .where('mensalidadeId', isEqualTo: id)
            .limit(1)
            .get();

        if (pagamentoSnap.docs.isNotEmpty) {
          batch.update(pagamentoSnap.docs.first.reference, {
            'clienteId': clienteId,
            'nomeCliente': nomeCliente,
            'servicoId': servicoId,
            'nomeServico': nomeServico,
            'tipoCobranca': tipo,
            'competencia': competencia,
            'dataServico': Timestamp.fromDate(dataServico),
            'valorOriginal': valorBase,
            'desconto': descontoSeguro,
            'juros': jurosSeguro,
            'valorPago': valorFinal,
            'formaPagamento': formaNova,
          });
        }

        final movimentacaoSnap = await _movimentacoesFinanceirasRef
            .where('mensalidadeId', isEqualTo: id)
            .limit(1)
            .get();

        if (movimentacaoSnap.docs.isNotEmpty) {
          batch.update(movimentacaoSnap.docs.first.reference, {
            'clienteId': clienteId,
            'nomeCliente': nomeCliente,
            'servicoId': servicoId,
            'nomeServico': nomeServico,
            'tipoCobranca': tipo,
            'competencia': competencia,
            'dataServico': Timestamp.fromDate(dataServico),
            'valor': valorFinal,
            'valorOriginal': valorBase,
            'desconto': descontoSeguro,
            'juros': jurosSeguro,
            'formaPagamento': formaNova,
            'subcategoria': nomeServico,
            'descricao': mensalidade
                ? 'Pagamento de mensalidade - $nomeServico - competência $competencia'
                : 'Pagamento de serviço - $nomeServico',
            'afetaCaixa': formaNova == 'dinheiro',
          });
        }

        final antigoAfetavaCaixa = formaAntiga == 'dinheiro';
        final novoAfetaCaixa = formaNova == 'dinheiro';

        if (antigoAfetavaCaixa && novoAfetaCaixa) {
          ajusteCaixa = valorFinal - valorAntigo;
        } else if (antigoAfetavaCaixa && !novoAfetaCaixa) {
          ajusteCaixa = -valorAntigo;
        } else if (!antigoAfetavaCaixa && novoAfetaCaixa) {
          ajusteCaixa = valorFinal;
        }

        if (ajusteCaixa > 0) {
          tipoAjusteCaixa = 'entrada';
        } else if (ajusteCaixa < 0) {
          tipoAjusteCaixa = 'saida';
        }
      }
    }

    await batch.commit();

    if (tipoAjusteCaixa != null && ajusteCaixa != 0) {
      await CaixaService.registrarMovimento(
        tipo: tipoAjusteCaixa,
        valor: ajusteCaixa.abs(),
      );
    }
  }

  static Future<void> registrarPagamento({
    required String mensalidadeId,
    required String clienteId,
    required String nomeCliente,
    required String nomeServico,
    required double valorOriginal,
    required String formaPagamento,
    double desconto = 0,
    double juros = 0,
  }) async {
    final mensalidadeSnap = await _mensalidadesRef.doc(mensalidadeId).get();
    final mensalidadeData = mensalidadeSnap.data();

    if (mensalidadeData == null) {
      throw Exception('Mensalidade não encontrada.');
    }

    final statusAtual = (mensalidadeData['status'] ?? '')
        .toString()
        .toLowerCase();

    if (statusAtual == 'pago') {
      throw Exception('Esta mensalidade já foi paga.');
    }

    final tipoCobranca = (mensalidadeData['tipoCobranca'] ?? 'mensalidade')
        .toString();
    final mensalidade = isMensalidade(tipoCobranca);

    final clienteIdBanco = (mensalidadeData['clienteId'] ?? '').toString();
    final nomeClienteBanco = (mensalidadeData['nomeCliente'] ?? '').toString();
    final servicoId = (mensalidadeData['servicoId'] ?? '').toString();
    final nomeServicoBanco = (mensalidadeData['nomeServico'] ?? '').toString();
    final competenciaAtual = (mensalidadeData['competencia'] ?? '').toString();
    final diaVencimento = _toInt(mensalidadeData['diaVencimento'], padrao: 10);
    final valorUnitario = _toDouble(mensalidadeData['valorUnitario']);
    final quantidade = _toInt(mensalidadeData['quantidade'], padrao: 1);
    final ativa = mensalidadeData['ativa'] == true;

    final vencimentoAtual = mensalidadeData['vencimento'] is Timestamp
        ? (mensalidadeData['vencimento'] as Timestamp).toDate()
        : DateTime.now();

    final dataServicoAtual = mensalidadeData['dataServico'] is Timestamp
        ? (mensalidadeData['dataServico'] as Timestamp).toDate()
        : DateTime.now();

    final descontoSeguro = desconto < 0 ? 0.0 : desconto;
    final jurosSeguro = juros < 0 ? 0.0 : juros;
    final valorBaseBanco = _toDouble(mensalidadeData['valorBase']);
    final valorBaseEfetivo = valorBaseBanco > 0
        ? valorBaseBanco
        : valorOriginal;

    final valorFinal = calcularValorFinal(
      valorBase: valorBaseEfetivo,
      desconto: descontoSeguro,
      juros: jurosSeguro,
    );

    final batch = _firestore.batch();
    final agora = FieldValue.serverTimestamp();

    final pagamentoDoc = _pagamentosRef.doc();
    batch.set(pagamentoDoc, {
      'mensalidadeId': mensalidadeId,
      'competencia': competenciaAtual,
      'dataServico': Timestamp.fromDate(dataServicoAtual),
      'tipoCobranca': tipoCobranca,
      'clienteId': clienteIdBanco.isEmpty ? clienteId : clienteIdBanco,
      'nomeCliente': nomeClienteBanco.isEmpty ? nomeCliente : nomeClienteBanco,
      'servicoId': servicoId,
      'nomeServico': nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco,
      'valorOriginal': valorBaseEfetivo,
      'desconto': descontoSeguro,
      'juros': jurosSeguro,
      'valorPago': valorFinal,
      'formaPagamento': formaPagamento,
      'origem': tipoCobranca,
      'dataPagamento': agora,
      'createdAt': agora,
    });

    batch.update(_mensalidadesRef.doc(mensalidadeId), {
      'status': 'pago',
      'desconto': descontoSeguro,
      'juros': jurosSeguro,
      'valorFinal': valorFinal,
      'formaPagamento': formaPagamento,
      'dataPagamento': agora,
      'updatedAt': agora,
    });

    final movimentacaoDoc = _movimentacoesFinanceirasRef.doc();
    batch.set(movimentacaoDoc, {
      'tipo': 'entrada',
      'origem': tipoCobranca,
      'categoria': mensalidade ? 'Mensalidades' : 'Serviços',
      'subcategoria': nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco,
      'clienteId': clienteIdBanco.isEmpty ? clienteId : clienteIdBanco,
      'nomeCliente': nomeClienteBanco.isEmpty ? nomeCliente : nomeClienteBanco,
      'servicoId': servicoId,
      'nomeServico': nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco,
      'mensalidadeId': mensalidadeId,
      'tipoCobranca': tipoCobranca,
      'competencia': competenciaAtual,
      'dataServico': Timestamp.fromDate(dataServicoAtual),
      'valor': valorFinal,
      'valorOriginal': valorBaseEfetivo,
      'desconto': descontoSeguro,
      'juros': jurosSeguro,
      'formaPagamento': formaPagamento,
      'descricao': mensalidade
          ? 'Pagamento de mensalidade - ${nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco} - competência $competenciaAtual'
          : 'Pagamento de serviço - ${nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco}',
      'afetaCaixa': formaPagamento == 'dinheiro',
      'data': agora,
      'createdAt': agora,
    });

    if (mensalidade) {
      await _criarProximaMensalidadeSeNaoExistir(
        clienteId: clienteIdBanco.isEmpty ? clienteId : clienteIdBanco,
        nomeCliente: nomeClienteBanco.isEmpty ? nomeCliente : nomeClienteBanco,
        servicoId: servicoId,
        nomeServico: nomeServicoBanco.isEmpty ? nomeServico : nomeServicoBanco,
        valorUnitario: valorUnitario,
        quantidade: quantidade,
        diaVencimento: diaVencimento,
        ativa: ativa,
        competenciaBase: competenciaAtual,
        vencimentoBase: vencimentoAtual,
        batch: batch,
        createdAtValue: agora,
        updatedAtValue: agora,
      );
    }

    await batch.commit();

    if (formaPagamento == 'dinheiro') {
      await CaixaService.registrarMovimento(tipo: 'entrada', valor: valorFinal);
    }
  }

  static Future<void> excluirMensalidade(String id) async {
    final batch = _firestore.batch();

    final pagamentos = await _pagamentosRef
        .where('mensalidadeId', isEqualTo: id)
        .get();

    for (final doc in pagamentos.docs) {
      batch.delete(doc.reference);
    }

    final movimentacoes = await _movimentacoesFinanceirasRef
        .where('mensalidadeId', isEqualTo: id)
        .get();

    for (final doc in movimentacoes.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_mensalidadesRef.doc(id));

    await batch.commit();
  }
}
