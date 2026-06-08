import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../pages/clientes_page.dart';
import '../pages/financeiro_page.dart';
import '../pages/mensalidades_page.dart';
import '../pages/servicos_page.dart';

class GlobalQuickActionsButton extends StatelessWidget {
  final String role;

  const GlobalQuickActionsButton({super.key, required this.role});

  Future<void> _abrirDialogo(BuildContext context, Widget dialog) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_QuickActionType>(
      tooltip: 'Ações rápidas',
      offset: const Offset(0, 48),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      onSelected: (value) async {
        switch (value) {
          case _QuickActionType.cliente:
            await _abrirDialogo(context, const CadastroClienteDialog());
            break;

          case _QuickActionType.mensalidade:
            await _abrirDialogo(context, CadastroMensalidadeDialog(role: role));
            break;

          case _QuickActionType.servico:
            await _abrirDialogo(context, const CadastroServicoDialog());
            break;

          case _QuickActionType.movimentacao:
            await _abrirDialogo(context, const NovaMovimentacaoDialog());
            break;
        }
      },
      itemBuilder: (context) {
        return [
          _buildItem(
            value: _QuickActionType.cliente,
            icon: Icons.person_add_alt_1_rounded,
            title: 'Novo cliente',
            subtitle: 'Cadastrar cliente',
            color: VitalisColors.verdeEsmeralda,
          ),
          _buildItem(
            value: _QuickActionType.mensalidade,
            icon: Icons.event_note_rounded,
            title: 'Nova mensalidade',
            subtitle: 'Criar lançamento',
            color: VitalisColors.cobreQueimado,
          ),
          _buildItem(
            value: _QuickActionType.servico,
            icon: Icons.design_services_rounded,
            title: 'Novo serviço',
            subtitle: 'Cadastrar plano ou serviço',
            color: VitalisColors.info,
          ),
          _buildItem(
            value: _QuickActionType.movimentacao,
            icon: Icons.attach_money_rounded,
            title: 'Nova movimentação',
            subtitle: 'Entrada ou saída financeira',
            color: VitalisColors.alerta,
          ),
        ];
      },
    );
  }

  PopupMenuItem<_QuickActionType> _buildItem({
    required _QuickActionType value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return PopupMenuItem<_QuickActionType>(
      value: value,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: VitalisColors.azulMarinhoProfundo,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: VitalisColors.cinzaMedio,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuickActionType { cliente, mensalidade, servico, movimentacao }
