import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../pages/admin_home_page.dart';
import '../pages/aniversariantes_page.dart';
import '../pages/caixa_page.dart';
import '../pages/clientes_page.dart';
import '../pages/cobrancas_page.dart';
import '../pages/configuracoes_lembrete_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/financeiro_page.dart';
import '../pages/funcionario_home_page.dart';
import '../pages/mensalidades_page.dart';
import '../pages/pdfs_page.dart';
import '../pages/servicos_page.dart';
import '../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final String nome;
  final String email;
  final String role;
  final String currentPage;
  final ValueChanged<String>? onNavigate;

  const AppDrawer({
    super.key,
    required this.nome,
    required this.email,
    required this.role,
    this.currentPage = '',
    this.onNavigate,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  bool get isFuncionario => role.trim().toLowerCase() == 'funcionario';

  String get _perfilLabel => isAdmin ? 'Administrador' : 'Funcionário';

  bool _isActive(String page) {
    if (page == 'lembretes' || page == 'configuracoes') {
      return currentPage == 'lembretes' || currentPage == 'configuracoes';
    }

    return currentPage == page;
  }

  bool _podeAcessar(String pageKey) {
    if (isAdmin) return true;

    const paginasFuncionario = {
      'home',
      'clientes',
      'servicos',
      'mensalidades',
      'cobrancas',
      'aniversariantes',
      'pdfs',
      'financeiro',
    };

    return paginasFuncionario.contains(pageKey);
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));

    if (partes.isEmpty || partes.first.isEmpty) {
      return 'VS';
    }

    if (partes.length == 1) {
      final primeira = partes.first;

      return primeira.length >= 2
          ? primeira.substring(0, 2).toUpperCase()
          : primeira.substring(0, 1).toUpperCase();
    }

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  void _fecharDrawerSeAberto(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _navegarPara({
    required BuildContext context,
    required String pageKey,
    required Widget page,
  }) {
    if (!_podeAcessar(pageKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para acessar esta área.'),
        ),
      );
      return;
    }

    _fecharDrawerSeAberto(context);

    if (onNavigate != null) {
      onNavigate!(pageKey);
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Widget _paginaInicial() {
    if (isAdmin) {
      return AdminHomePage(nome: nome, email: email);
    }

    return FuncionarioHomePage(nome: nome, email: email);
  }

  @override
  Widget build(BuildContext context) {
    final nomeExibicao = nome.trim().isEmpty ? 'Usuário' : nome;
    final emailExibicao = email.trim().isEmpty ? 'Sem e-mail' : email;

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeaderPremium(
              nome: nomeExibicao,
              email: emailExibicao,
              perfil: _perfilLabel,
              iniciais: _iniciais(nomeExibicao),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                children: [
                  const _DrawerSectionTitle('INÍCIO'),
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'Painel inicial',
                    active: _isActive('home'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'home',
                        page: _paginaInicial(),
                      );
                    },
                  ),

                  if (isAdmin) ...[
                    const _DrawerSpacer(),
                    const _DrawerSectionTitle('VISÃO GERAL'),
                    _DrawerItem(
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      active: _isActive('dashboard'),
                      onTap: () {
                        _navegarPara(
                          context: context,
                          pageKey: 'dashboard',
                          page: DashboardPage(
                            nome: nome,
                            email: email,
                            role: role,
                          ),
                        );
                      },
                    ),
                  ],

                  const _DrawerSpacer(),
                  const _DrawerSectionTitle('GESTÃO'),
                  _DrawerItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Clientes',
                    active: _isActive('clientes'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'clientes',
                        page: ClientesPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.design_services_rounded,
                    title: 'Serviços',
                    active: _isActive('servicos'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'servicos',
                        page: ServicosPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.event_note_rounded,
                    title: 'Mensalidades',
                    active: _isActive('mensalidades'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'mensalidades',
                        page: MensalidadesPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Cobranças',
                    active: _isActive('cobrancas'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'cobrancas',
                        page: CobrancasPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.cake_rounded,
                    title: 'Aniversariantes',
                    active: _isActive('aniversariantes'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'aniversariantes',
                        page: AniversariantesPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'PDFs',
                    active: _isActive('pdfs'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'pdfs',
                        page: PdfsPage(nome: nome, email: email, role: role),
                      );
                    },
                  ),

                  const _DrawerSpacer(),
                  const _DrawerSectionTitle('FINANCEIRO'),
                  _DrawerItem(
                    icon: Icons.attach_money_rounded,
                    title: isAdmin ? 'Financeiro' : 'Lançamentos financeiros',
                    active: _isActive('financeiro'),
                    onTap: () {
                      _navegarPara(
                        context: context,
                        pageKey: 'financeiro',
                        page: FinanceiroPage(
                          nome: nome,
                          email: email,
                          role: role,
                        ),
                      );
                    },
                  ),

                  if (isAdmin) ...[
                    const _DrawerSpacer(),
                    const _DrawerSectionTitle('ADMINISTRAÇÃO'),
                    _DrawerItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Caixa',
                      active: _isActive('caixa'),
                      onTap: () {
                        _navegarPara(
                          context: context,
                          pageKey: 'caixa',
                          page: CaixaPage(nome: nome, email: email, role: role),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Lembretes',
                      active: _isActive('lembretes'),
                      onTap: () {
                        _navegarPara(
                          context: context,
                          pageKey: 'lembretes',
                          page: ConfiguracoesLembretePage(
                            nome: nome,
                            email: email,
                            role: role,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _LogoutButton(
                onTap: () async {
                  _fecharDrawerSeAberto(context);
                  await AuthService.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeaderPremium extends StatelessWidget {
  final String nome;
  final String email;
  final String perfil;
  final String iniciais;

  const _DrawerHeaderPremium({
    required this.nome,
    required this.email,
    required this.perfil,
    required this.iniciais,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: VitalisColors.azulMarinhoProfundo,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  iniciais,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vitalis Studio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.68),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  perfil,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String text;

  const _DrawerSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: VitalisColors.cinzaMedio,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerSpacer extends StatelessWidget {
  const _DrawerSpacer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = active
        ? VitalisColors.verdeEsmeralda
        : VitalisColors.azulMarinhoProfundo;

    final textColor = active
        ? VitalisColors.azulMarinhoProfundo
        : VitalisColors.pretoSuave;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? VitalisColors.verdeEsmeralda.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(
            children: [
              if (active)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: VitalisColors.verdeEsmeralda,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : VitalisColors.verdeEsmeralda.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, size: 20, color: itemColor),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: active
                          ? VitalisColors.verdeEsmeralda
                          : VitalisColors.cinzaMedio,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VitalisColors.erro.withOpacity(0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: VitalisColors.erro, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sair da conta',
                  style: TextStyle(
                    color: VitalisColors.erro,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
