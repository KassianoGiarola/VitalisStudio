import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracaoService {
  ConfiguracaoService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _cobrancaRef =>
      _firestore.collection('configuracoes').doc('cobranca');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> ouvirCobranca() {
    return _cobrancaRef.snapshots();
  }

  static Future<void> salvarConfiguracaoCobranca({
    required bool lembrete1Ativo,
    required int diasAntesLembrete1,
    required String mensagemLembrete1,
    required bool lembrete2Ativo,
    required int diasAntesLembrete2,
    required String mensagemLembrete2,
  }) async {
    await _cobrancaRef.set({
      'lembrete1Ativo': lembrete1Ativo,
      'diasAntesLembrete1': diasAntesLembrete1,
      'mensagemLembrete1': mensagemLembrete1.trim(),
      'lembrete2Ativo': lembrete2Ativo,
      'diasAntesLembrete2': diasAntesLembrete2,
      'mensagemLembrete2': mensagemLembrete2.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
