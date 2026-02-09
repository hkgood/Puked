import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _agreeToPrivacy = false;
  File? _avatarFile;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final toolbarColor = isDark
        ? const Color(0xFF1A1A1A)
        : Theme.of(context).colorScheme.primary;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      // 核心优化：限制最大尺寸和压缩质量（头像256x256即可满足显示需求）
      maxWidth: 256,
      maxHeight: 256,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: AppLocalizations.of(context)!.crop_avatar,
          toolbarColor: toolbarColor,
          statusBarColor: toolbarColor,
          backgroundColor: backgroundColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: isDark
              ? const Color(0xFF1A1A1A)
              : Theme.of(context).colorScheme.primary,
          dimmedLayerColor: isDark ? Colors.black.withValues(alpha: 0.8) : null,
          cropFrameColor: isDark
              ? const Color(0xFF1A1A1A)
              : Theme.of(context).colorScheme.primary,
          cropGridColor: Colors.white.withValues(alpha: 0.5),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: AppLocalizations.of(context)!.crop_avatar,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          hidesNavigationBar: false,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _avatarFile = File(croppedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.passwords_not_match),
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

      // 如果选择了头像，在注册并自动登录后上传
      if (_avatarFile != null) {
        await ref.read(authProvider.notifier).updateAvatar(_avatarFile!);
      }

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
                Center(
                  child: GestureDetector(
                    onTap: _pickAndCropAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? const Icon(Icons.person_add_outlined,
                                  size: 50, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(),
                  decoration:
                      _buildInputDecoration(l10n.name, Icons.person_outline),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? l10n.field_required : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(),
                  decoration: _buildInputDecoration(
                      l10n.email, Icons.email_outlined,
                      hint: 'example@email.com'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? l10n.invalid_email_format
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(),
                  decoration:
                      _buildInputDecoration(l10n.password, Icons.lock_outline),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 8)
                      ? l10n.password_too_short
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(),
                  decoration: _buildInputDecoration(
                      l10n.password, Icons.lock_reset_outlined,
                      hint: l10n.repeat_password),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? l10n.field_required : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreeToPrivacy,
                        onChanged: (v) {
                          setState(() {
                            _agreeToPrivacy = v ?? false;
                          });
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          children: _buildPrivacyTextSpans(l10n),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _agreeToPrivacy
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                  ),
                  onPressed: (isLoading || !_agreeToPrivacy) ? null : _submit,
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

  List<TextSpan> _buildPrivacyTextSpans(AppLocalizations l10n) {
    // 使用占位符来精准拆分中英文，确保链接位置正确
    final String fullText = l10n.agree_privacy_link('||POLICY||');
    final parts = fullText.split('||POLICY||');

    return [
      TextSpan(text: parts[0]),
      TextSpan(
        text: l10n.privacy_policy,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            launchUrl(
              Uri.parse('https://hkgood.github.io/puked-privacy/'),
              mode: LaunchMode.inAppWebView,
            );
          },
      ),
      if (parts.length > 1) TextSpan(text: parts[1]),
    ];
  }
}
