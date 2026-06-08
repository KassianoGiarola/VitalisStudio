import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteServicoService {
  ClienteServicoService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('cliente_servicos');

  /// LISTAR TODOS OS VÍNCULOS
  static Stream<QuerySnapshot<Map<String, dynamic>>> listarTodos() {
    return _ref.orderBy('createdAt', descending: true).snapshots();
  }

  /// LISTAR POR CLIENTE
  static Stream<QuerySnapshot<Map<String, dynamic>>> listarPorCliente(
    String clienteId,
  ) {
    return _ref
        .where('clienteId', isEqualTo: clienteId)
        .where('ativo', isEqualTo: true)
        .snapshots();
  }

  /// CRIAR VÍNCULO CLIENTE ↔ SERVIÇO
  static Future<void> criarClienteServico({
    required String clienteId,
    required String nomeCliente,
    required String servicoId,
    required String nomeServico,
    required double valorUnitario,
    required int quantidade,
    required int diaVencimento,
  }) async {
    final quantidadeSegura = quantidade < 1 ? 1 : quantidade;
    final valorBase = valorUnitario * quantidadeSegura;

    await _ref.add({
      'clienteId': clienteId,
      'nomeCliente': nomeCliente,
      'servicoId': servicoId,
      'nomeServico': nomeServico,
      'valorUnitario': valorUnitario,
      'quantidade': quantidadeSegura,
      'valorBase': valorBase,
      'diaVencimento': diaVencimento,
      'ativo': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ATUALIZAR VÍNCULO
  static Future<void> atualizarClienteServico({
    required String id,
    required String clienteId,
    required String nomeCliente,
    required String servicoId,
    required String nomeServico,
    required double valorUnitario,
    required int quantidade,
    required int diaVencimento,
    required bool ativo,
  }) async {
    final quantidadeSegura = quantidade < 1 ? 1 : quantidade;
    final valorBase = valorUnitario * quantidadeSegura;

    await _ref.doc(id).update({
      'clienteId': clienteId,
      'nomeCliente': nomeCliente,
      'servicoId': servicoId,
      'nomeServico': nomeServico,
      'valorUnitario': valorUnitario,
      'quantidade': quantidadeSegura,
      'valorBase': valorBase,
      'diaVencimento': diaVencimento,
      'ativo': ativo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DESATIVAR (NÃO DELETAR)
  static Future<void> desativar(String id) async {
    await _ref.doc(id).update({
      'ativo': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
