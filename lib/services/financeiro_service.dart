import 'package:cloud_firestore/cloud_firestore.dart';

import 'caixa_service.dart';

class FinanceiroService {
  FinanceiroService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _movRef =>
      _firestore.collection('movimentacoes_financeiras');

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarMovimentacoes({
    int limite = 200,
  }) {
    return _movRef
        .orderBy('createdAt', descending: true)
        .limit(limite)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  listarMovimentacoesPorPeriodo({
    required DateTime dataInicial,
    required DateTime dataFinal,
    int limite = 300,
  }) {
    final inicio = DateTime(
      dataInicial.year,
      dataInicial.month,
      dataInicial.day,
    );

    final fim = DateTime(
      dataFinal.year,
      dataFinal.month,
      dataFinal.day,
      23,
      59,
      59,
    );

    return _movRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(fim))
        .orderBy('createdAt', descending: true)
        .limit(limite)
        .snapshots();
  }

  static Future<void> registrarMovimentacao({
    required String tipo,
    required double valor,
    required String formaPagamento,
    required String categoria,
    required String descricao,
  }) async {
    final afetaCaixa = formaPagamento == 'dinheiro';

    await _movRef.add({
      'tipo': tipo,
      'valor': valor,
      'formaPagamento': formaPagamento,
      'categoria': categoria,
      'descricao': descricao,
      'afetaCaixa': afetaCaixa,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (afetaCaixa) {
      await CaixaService.registrarMovimento(tipo: tipo, valor: valor);
    }
  }

  static Future<void> atualizarMovimentacao({
    required String id,
    required String tipo,
    required double valor,
    required String formaPagamento,
    required String categoria,
    required String descricao,
  }) async {
    final doc = await _movRef.doc(id).get();

    if (!doc.exists) {
      throw Exception('Movimentação não encontrada.');
    }

    final data = doc.data() ?? {};

    final tipoAntigo = (data['tipo'] ?? '').toString();
    final valorAntigo = _toDouble(data['valor']);
    final afetaCaixaAntigo = data['afetaCaixa'] == true;

    final afetaCaixaNovo = formaPagamento == 'dinheiro';

    if (afetaCaixaAntigo) {
      await CaixaService.registrarMovimento(
        tipo: _tipoInverso(tipoAntigo),
        valor: valorAntigo,
      );
    }

    await _movRef.doc(id).update({
      'tipo': tipo,
      'valor': valor,
      'formaPagamento': formaPagamento,
      'categoria': categoria,
      'descricao': descricao,
      'afetaCaixa': afetaCaixaNovo,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (afetaCaixaNovo) {
      await CaixaService.registrarMovimento(tipo: tipo, valor: valor);
    }
  }

  static Future<void> excluirMovimentacao(String id) async {
    final doc = await _movRef.doc(id).get();

    if (!doc.exists) {
      throw Exception('Movimentação não encontrada.');
    }

    final data = doc.data() ?? {};
    final tipo = (data['tipo'] ?? '').toString();
    final valor = _toDouble(data['valor']);
    final afetaCaixa = data['afetaCaixa'] == true;

    if (afetaCaixa) {
      await CaixaService.registrarMovimento(
        tipo: _tipoInverso(tipo),
        valor: valor,
      );
    }

    await _movRef.doc(id).delete();
  }

  static String _tipoInverso(String tipo) {
    if (tipo == 'entrada') return 'saida';
    if (tipo == 'saida') return 'entrada';
    throw Exception('Tipo inválido para reversão: $tipo');
  }

  static double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }
}
