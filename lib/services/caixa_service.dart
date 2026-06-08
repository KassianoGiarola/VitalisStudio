import 'package:cloud_firestore/cloud_firestore.dart';

class CaixaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _colecao = 'caixa';

  static Stream<QuerySnapshot<Map<String, dynamic>>> ouvirHistorico() {
    return _firestore
        .collection(_colecao)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?>
  buscarCaixaAberto() async {
    final query = await _firestore
        .collection(_colecao)
        .where('aberto', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return query.docs.first;
  }

  static Future<void> abrirCaixa(double valorInicial) async {
    final caixaAberto = await buscarCaixaAberto();

    if (caixaAberto != null) {
      throw Exception('Já existe um caixa aberto.');
    }

    await _firestore.collection(_colecao).add({
      'aberto': true,
      'saldo': valorInicial,
      'saldoInicial': valorInicial,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> fecharCaixa({
    required double valorContado,
    required double trocoParaProximoDia,
  }) async {
    final caixaDoc = await buscarCaixaAberto();

    if (caixaDoc == null) {
      throw Exception('Nenhum caixa aberto.');
    }

    final data = caixaDoc.data() ?? {};
    final double saldoSistema = _toDouble(data['saldo']);
    final double diferenca = valorContado - saldoSistema;

    await caixaDoc.reference.update({
      'aberto': false,
      'fechadoAt': FieldValue.serverTimestamp(),
      'saldoFinalContado': valorContado,
      'saldoSistema': saldoSistema,
      'diferenca': diferenca,
      'trocoSeparado': trocoParaProximoDia,
    });
  }

  static Future<void> entrada(double valor) async {
    final caixaDoc = await buscarCaixaAberto();

    if (caixaDoc == null) {
      throw Exception('Abra o caixa primeiro.');
    }

    final data = caixaDoc.data() ?? {};
    final double saldoAtual = _toDouble(data['saldo']);

    await caixaDoc.reference.update({'saldo': saldoAtual + valor});
  }

  static Future<void> saida(double valor) async {
    final caixaDoc = await buscarCaixaAberto();

    if (caixaDoc == null) {
      throw Exception('Abra o caixa primeiro.');
    }

    final data = caixaDoc.data() ?? {};
    final double saldoAtual = _toDouble(data['saldo']);

    await caixaDoc.reference.update({'saldo': saldoAtual - valor});
  }

  static Future<void> registrarMovimento({
    required String tipo,
    required double valor,
  }) async {
    if (tipo == 'entrada') {
      await entrada(valor);
      return;
    }

    if (tipo == 'saida') {
      await saida(valor);
      return;
    }

    throw Exception('Tipo de movimento inválido: $tipo');
  }

  static double _toDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }
}
