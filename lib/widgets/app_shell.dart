import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'app_drawer.dart';
import 'global_quick_actions_button.dart';
import 'global_search_button.dart';

class AppShell extends StatelessWidget {
  final String title;
  final String nome;
  final String email;
  final String role;
  final String currentPage;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final ValueChanged<String>? onNavigate;

  const AppShell({
    super.key,
    required this.title,
    required this.nome,
    required this.email,
    required this.role,
    required this.child,
    this.currentPage = '',
    this.actions,
    this.floatingActionButton,
    this.onNavigate,
  });

  bool get isAdmin => role == 'admin';

  String get _roleLabel => isAdmin ? 'Administrador' : 'Funcionário';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        return Scaffold(
          backgroundColor: VitalisColors.offWhite,
          appBar: AppBar(
            toolbarHeight: 68,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: VitalisColors.azulMarinhoProfundo,
            foregroundColor: Colors.white,
            centerTitle: false,
            titleSpacing: isWide ? 24 : 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.68),
                  ),
                ),
              ],
            ),
            actions: [
              if (onNavigate != null)
                GlobalSearchButton(
                  role: role,
                  currentPage: currentPage,
                  onNavigate: onNavigate!,
                ),
              if (onNavigate != null) const SizedBox(width: 8),
              GlobalQuickActionsButton(role: role),
              const SizedBox(width: 8),
              if (actions != null) ...actions!,
              const SizedBox(width: 10),
            ],
          ),
          drawer: isWide
              ? null
              : AppDrawer(
                  nome: nome,
                  email: email,
                  role: role,
                  currentPage: currentPage,
                  onNavigate: onNavigate,
                ),
          floatingActionButton: floatingActionButton,
          body: Row(
            children: [
              if (isWide)
                Container(
                  width: 300,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: VitalisColors.cinzaClaro,
                        width: 1,
                      ),
                    ),
                  ),
                  child: AppDrawer(
                    nome: nome,
                    email: email,
                    role: role,
                    currentPage: currentPage,
                    onNavigate: onNavigate,
                  ),
                ),
              Expanded(
                child: Container(color: VitalisColors.offWhite, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}
