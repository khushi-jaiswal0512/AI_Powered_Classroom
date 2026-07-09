import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'student';

  // For animated dots in the cold-start banner
  late Timer _dotTimer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _dotTimer.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Register handler ──────────────────────────────────────────────────────

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _selectedRole.toUpperCase(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Registration successful! Please login.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      context.pop();
      return;
    }

    final error = ref.read(authProvider).error ?? '';

    if (error.startsWith('timeout:')) {
      // All retries exhausted — tell user to try again manually
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⏳ Server is still waking up. Tap Register again in a moment.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleRegister,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.isNotEmpty ? error : 'Registration failed'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Cold-start banner ─────────────────────────────────────────────────────

  Widget _buildColdStartBanner() {
    final dots = '.' * _dotCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade400, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Server is waking up$dots\nThis may take up to 2–3 minutes on first use.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final isColdStart = authState.isColdStart;

    // Loading button label depends on state
    String loadingLabel() {
      if (isColdStart) return 'Waking server up…';
      return 'Registering…';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isLoading ? null : () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header icon ─────────────────────────────────────────
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 80,
                    color: AppColors.primary,
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 32),

                  // ── Cold-start banner (shown during retries) ────────────
                  if (isColdStart) _buildColdStartBanner(),

                  // ── Full Name ───────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),

                  // ── Email ───────────────────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Please enter your email' : null,
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),

                  // ── Password ────────────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                    onFieldSubmitted: (_) => isLoading ? null : _handleRegister(),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
                  const SizedBox(height: 24),

                  // ── Role Selector ───────────────────────────────────────
                  DropdownButtonFormField<String>(
                    isExpanded: true, // Prevent overflow
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    ],
                    onChanged: isLoading
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedRole = val);
                          },
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 32),

                  // ── Register Button ─────────────────────────────────────
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleRegister,
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                loadingLabel(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ).animate().fadeIn(delay: 500.ms).scale(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

