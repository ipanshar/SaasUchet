import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/features/auth/data/auth_api_client.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/presentation/auth_screen.dart';
import 'package:saas_uchet_mobile/features/business/data/business_api_client.dart';
import 'package:saas_uchet_mobile/features/business/domain/business_gateway.dart';
import 'package:saas_uchet_mobile/features/business/presentation/business_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaasUchetApp extends StatefulWidget {
  const SaasUchetApp({
    super.key,
    this.authGateway,
    this.businessGateway,
    this.initialSession,
  });

  final AuthGateway? authGateway;
  final BusinessGateway? businessGateway;
  final AuthSession? initialSession;

  @override
  State<SaasUchetApp> createState() => _SaasUchetAppState();
}

class _SaasUchetAppState extends State<SaasUchetApp> {
  static const _sessionPrefKey = 'auth_session';

  late final AuthGateway _authGateway;
  late final bool _ownsAuthGateway;
  late final BusinessGateway _businessGateway;
  late final bool _ownsBusinessGateway;
  AuthSession? _session;
  bool _hasCompletedOnboarding = false;
  bool _isRestoringSession = false;

  @override
  void initState() {
    super.initState();
    _ownsAuthGateway = widget.authGateway == null;
    _authGateway = widget.authGateway ?? AuthApiClient();
    _ownsBusinessGateway = widget.businessGateway == null;
    _businessGateway = widget.businessGateway ?? BusinessApiClient();
    _session = widget.initialSession;
    _hasCompletedOnboarding = widget.initialSession != null;
    if (widget.initialSession != null) {
      _saveSession(widget.initialSession!);
    } else {
      _isRestoringSession = true;
      _restoreSession();
    }
  }

  @override
  void dispose() {
    if (_ownsAuthGateway) {
      _authGateway.dispose();
    }
    if (_ownsBusinessGateway) {
      _businessGateway.dispose();
    }
    super.dispose();
  }

  void _handleAuthenticated(AuthSession session) {
    _saveSession(session);
    setState(() {
      _session = session;
      _hasCompletedOnboarding = true;
    });
  }

  void _handleSessionChanged(AuthSession session) {
    _saveSession(session);
    setState(() {
      _session = session;
      _hasCompletedOnboarding = true;
    });
  }

  void _handleLogout() {
    _clearStoredSession();
    setState(() {
      _session = null;
    });
  }

  Future<void> _restoreSession() async {
    AuthSession? restoredSession;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSession = prefs.getString(_sessionPrefKey);
      if (rawSession == null || rawSession.isEmpty) {
        return;
      }

      final decoded = jsonDecode(rawSession);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_sessionPrefKey);
        return;
      }

      final storedSession = AuthSession.fromJson(decoded);
      if (storedSession.accessToken.isEmpty ||
          storedSession.expiresAt.isBefore(DateTime.now().toUtc())) {
        await prefs.remove(_sessionPrefKey);
        return;
      }

      try {
        final profile = await _authGateway.fetchProfile(
          accessToken: storedSession.accessToken,
        );
        restoredSession = storedSession.copyWith(user: profile);
        await prefs.setString(
          _sessionPrefKey,
          jsonEncode(restoredSession.toJson()),
        );
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          await prefs.remove(_sessionPrefKey);
          return;
        }
        restoredSession = storedSession;
      } catch (_) {
        restoredSession = storedSession;
      }
    } on FormatException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionPrefKey);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _session = restoredSession;
        _hasCompletedOnboarding = restoredSession != null;
        _isRestoringSession = false;
      });
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefKey, jsonEncode(session.toJson()));
  }

  Future<void> _clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefKey);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saas Uchet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
        fontFamily: 'SF Pro Display',
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF00A86B),
              width: 1.4,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00A86B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      home: _isRestoringSession
          ? const _SessionRestoreScreen()
          : _session != null
              ? BusinessShell(
                  authGateway: _authGateway,
                  businessGateway: _businessGateway,
                  session: _session!,
                  onLogout: _handleLogout,
                  onSessionChanged: _handleSessionChanged,
                  onAccountDeleted: _handleLogout,
                )
              : !_hasCompletedOnboarding
                  ? OnboardingFlowScreen(
                      onComplete: () {
                        setState(() {
                          _hasCompletedOnboarding = true;
                        });
                      },
                    )
                  : AuthScreen(
                      authGateway: _authGateway,
                      onAuthenticated: _handleAuthenticated,
                    ),
    );
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
