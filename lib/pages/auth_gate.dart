import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/auth_service.dart';
import 'admin_home_page.dart';
import 'funcionario_home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoadingPage();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.getUserProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashLoadingPage();
            }

            if (profileSnapshot.hasError) {
              return ErrorPage(message: 'Erro ao carregar perfil do usuário.');
            }

            final data = profileSnapshot.data;

            if (data == null) {
              return MissingProfilePage(email: user.email ?? '');
            }

            final ativo = data['ativo'] == true;
            final role = (data['role'] ?? '').toString().trim();

            if (!ativo) {
              return DisabledUserPage(email: user.email ?? '');
            }

            if (role == 'admin') {
              return AdminHomePage(
                nome: (data['nome'] ?? '').toString(),
                email: (data['email'] ?? user.email ?? '').toString(),
              );
            }

            if (role == 'funcionario') {
              return FuncionarioHomePage(
                nome: (data['nome'] ?? '').toString(),
                email: (data['email'] ?? user.email ?? '').toString(),
              );
            }

            return ErrorPage(
              message: 'Perfil sem permissão válida. Role encontrado: $role',
            );
          },
        );
      },
    );
  }
}

class SplashLoadingPage extends StatelessWidget {
  const SplashLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VitalisColors.offWhite,
      body: Center(
        child: CircularProgressIndicator(color: VitalisColors.verdeEsmeralda),
      ),
    );
  }
}

class MissingProfilePage extends StatelessWidget {
  final String email;

  const MissingProfilePage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil não encontrado'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_search_rounded,
                      size: 54,
                      color: VitalisColors.cobreQueimado,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Usuário autenticado, mas sem perfil no Firestore.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('E-mail: $email', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Text(
                      'Crie ou ajuste o documento em users/{uid} com os campos nome, email, role e ativo.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DisabledUserPage extends StatelessWidget {
  final String email;

  const DisabledUserPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso desativado'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 54,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seu acesso está desativado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: VitalisColors.azulMarinhoProfundo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('E-mail: $email', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Text(
                      'Peça ao administrador para reativar sua conta.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorPage extends StatelessWidget {
  final String message;

  const ErrorPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erro'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: VitalisColors.azulMarinhoProfundo,
            ),
          ),
        ),
      ),
    );
  }
}
