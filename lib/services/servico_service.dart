import 'package:cloud_firestore/cloud_firestore.dart';

class ServicoService {
  ServicoService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _servicosRef =>
      _firestore.collection('servicos');

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarServicos() {
    return _servicosRef.orderBy('nome').snapshots();
  }

  static const tiposCobranca = [
    'mensalidade',
    'avulso',
    'sessao',
    'aula_experimental',
    'outro',
  ];

  static Future<void> criarServico({
    required String nome,
    required double valor,
    required String tipoCobranca,
  }) async {
    await _servicosRef.add({
      'nome': nome.trim(),
      'valor': valor,

      // NOVO
      'tipoCobranca': tipoCobranca,

      'ativo': true,

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> atualizarServico({
    required String id,
    required String nome,
    required double valor,
    required bool ativo,
    required String tipoCobranca,
  }) async {
    await _servicosRef.doc(id).update({
      'nome': nome.trim(),

      'valor': valor,

      // NOVO
      'tipoCobranca': tipoCobranca,

      'ativo': ativo,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
