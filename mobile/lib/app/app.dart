import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/features/auth/data/auth_api_client.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/presentation/auth_screen.dart';
import 'package:saas_uchet_mobile/features/health/domain/health_gateway.dart';
import 'package:saas_uchet_mobile/features/profile/presentation/profile_screen.dart';

class SaasUchetApp extends StatefulWidget {
  const SaasUchetApp({
    super.key,
    this.authGateway,
    this.healthGateway,
    this.initialSession,
  });

  final AuthGateway? authGateway;
  final HealthGateway? healthGateway;
  final AuthSession? initialSession;

  @override
  State<SaasUchetApp> createState() => _SaasUchetAppState();
}

class _SaasUchetAppState extends State<SaasUchetApp> {
  late final AuthGateway _authGateway;
  late final bool _ownsAuthGateway;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _ownsAuthGateway = widget.authGateway == null;
    _authGateway = widget.authGateway ?? AuthApiClient();
    _session = widget.initialSession;
  }

  @override
  void dispose() {
    if (_ownsAuthGateway) {
      _authGateway.dispose();
    }
    super.dispose();
  }

  void _handleAuthenticated(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  void _handleSessionChanged(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  void _handleLogout() {
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saas Uchet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F1),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        useMaterial3: true,
      ),
      home: _session == null
          ? AuthScreen(
              authGateway: _authGateway,
              onAuthenticated: _handleAuthenticated,
            )
          : ProfileScreen(
              authGateway: _authGateway,
              healthGateway: widget.healthGateway,
              session: _session!,
              onLogout: _handleLogout,
              onSessionChanged: _handleSessionChanged,
              onAccountDeleted: _handleLogout,
            ),
    );
  }
}
