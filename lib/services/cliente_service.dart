import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteService {
  ClienteService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _clientesRef =>
      _firestore.collection('clientes');

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarClientes({
    int limite = 500,
  }) {
    return _clientesRef.orderBy('nome').limit(limite).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarClientesPorStatus({
    required String status,
    int limite = 300,
  }) {
    return _clientesRef
        .where('status', isEqualTo: status)
        .orderBy('nome')
        .limit(limite)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> listarClientesNatacao({
    int limite = 300,
  }) {
    return _clientesRef
        .where('clienteNatacao', isEqualTo: true)
        .orderBy('nome')
        .limit(limite)
        .snapshots();
  }

  static Future<void> criarCliente({
    required String nome,
    required String telefone,
    required String cpf,
    required String categoria,
    required String status,
    required String observacoes,
    required bool clienteNatacao,
    required bool receberMensagemAniversario,
    required bool receberMensagemCobranca,
    DateTime? dataNascimentoCliente,
    String? nomeCrianca,
    DateTime? dataNascimentoCrianca,
    required String cep,
    required String logradouro,
    required String numero,
    required String complemento,
    required String bairro,
    required String cidade,
    required String uf,
  }) async {
    await _clientesRef.add({
      'nome': nome.trim(),
      'telefone': telefone.trim(),
      'cpf': cpf.trim(),
      'categoria': categoria,
      'status': status,
      'observacoes': observacoes.trim(),
      'clienteNatacao': clienteNatacao,
      'receberMensagemAniversario': receberMensagemAniversario,
      'receberMensagemCobranca': receberMensagemCobranca,
      'dataNascimentoCliente': dataNascimentoCliente == null
          ? null
          : Timestamp.fromDate(dataNascimentoCliente),
      'nomeCrianca': (nomeCrianca == null || nomeCrianca.trim().isEmpty)
          ? null
          : nomeCrianca.trim(),
      'dataNascimentoCrianca': dataNascimentoCrianca == null
          ? null
          : Timestamp.fromDate(dataNascimentoCrianca),
      'cep': cep.trim(),
      'logradouro': logradouro.trim(),
      'numero': numero.trim(),
      'complemento': complemento.trim(),
      'bairro': bairro.trim(),
      'cidade': cidade.trim(),
      'uf': uf.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> atualizarCliente({
    required String id,
    required String nome,
    required String telefone,
    required String cpf,
    required String categoria,
    required String status,
    required String observacoes,
    required bool clienteNatacao,
    required bool receberMensagemAniversario,
    required bool receberMensagemCobranca,
    DateTime? dataNascimentoCliente,
    String? nomeCrianca,
    DateTime? dataNascimentoCrianca,
    required String cep,
    required String logradouro,
    required String numero,
    required String complemento,
    required String bairro,
    required String cidade,
    required String uf,
  }) async {
    await _clientesRef.doc(id).update({
      'nome': nome.trim(),
      'telefone': telefone.trim(),
      'cpf': cpf.trim(),
      'categoria': categoria,
      'status': status,
      'observacoes': observacoes.trim(),
      'clienteNatacao': clienteNatacao,
      'receberMensagemAniversario': receberMensagemAniversario,
      'receberMensagemCobranca': receberMensagemCobranca,
      'dataNascimentoCliente': dataNascimentoCliente == null
          ? null
          : Timestamp.fromDate(dataNascimentoCliente),
      'nomeCrianca': (nomeCrianca == null || nomeCrianca.trim().isEmpty)
          ? null
          : nomeCrianca.trim(),
      'dataNascimentoCrianca': dataNascimentoCrianca == null
          ? null
          : Timestamp.fromDate(dataNascimentoCrianca),
      'cep': cep.trim(),
      'logradouro': logradouro.trim(),
      'numero': numero.trim(),
      'complemento': complemento.trim(),
      'bairro': bairro.trim(),
      'cidade': cidade.trim(),
      'uf': uf.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> excluirCliente(String id) async {
    await _clientesRef.doc(id).delete();
  }
}
