import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await ref.read(authProvider.notifier).register(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim(),
          );
      if (mounted) {
        // 注册成功并自动登录后，跳转到“我的爱车”设置页面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const VehicleInfoScreen(isSettingsMode: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorKey = ref.read(authProvider).error;
        String errorMsg;
        final l10n = AppLocalizations.of(context)!;

        if (errorKey == 'error_email_taken') {
          errorMsg = l10n.error_email_taken;
        } else if (errorKey == 'error_password_too_short') {
          errorMsg = l10n.error_password_too_short;
        } else {
          errorMsg = l10n.register_failed;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {String? hint}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      hintStyle: const TextStyle(color: Color(0xFF636366), fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.register,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.person_add_outlined,
                    size: 80, color: Colors.grey),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(),
                  decoration:
                      _buildInputDecoration(l10n.name, Icons.person_outline),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(),
                  decoration: _buildInputDecoration(
                      'Email', Icons.email_outlined,
                      hint: 'example@email.com'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Invalid email' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(),
                  decoration:
                      _buildInputDecoration(l10n.password, Icons.lock_outline),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Min 8 characters' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(),
                  decoration: _buildInputDecoration(
                      l10n.password, Icons.lock_reset_outlined,
                      hint: 'Repeat password'),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                  ),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.register,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          )),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.has_account,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
