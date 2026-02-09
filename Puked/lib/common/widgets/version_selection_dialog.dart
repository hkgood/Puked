import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/models/db_models.dart';

class VersionSelectionDialog extends StatefulWidget {
  final String? currentVersion;
  final List<SoftwareVersion> presetVersions;
  final String brandName;

  const VersionSelectionDialog({
    super.key,
    this.currentVersion,
    required this.presetVersions,
    required this.brandName,
  });

  @override
  State<VersionSelectionDialog> createState() => _VersionSelectionDialogState();
}

class _VersionSelectionDialogState extends State<VersionSelectionDialog> {
  late TextEditingController _customController;
  dynamic _selectedResult;
  bool _isCustomInput = false;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();

    if (widget.currentVersion != null && widget.currentVersion!.isNotEmpty) {
      final preset = widget.presetVersions.firstWhere(
          (v) => v.versionString == widget.currentVersion,
          orElse: () => SoftwareVersion()..versionString = '');
      if (preset.versionString.isNotEmpty) {
        _selectedResult = preset;
      } else {
        _isCustomInput = true;
        _customController.text = widget.currentVersion!;
        _selectedResult = widget.currentVersion;
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final i18n = ref.watch(i18nProvider);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t('select_version'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // iOS 风格自定义输入框
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _customController,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: i18n.t('custom_version_input'),
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      prefixIcon: Icon(Icons.edit_outlined,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.black54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          _selectedResult = value;
                          _isCustomInput = true;
                        } else {
                          _isCustomInput = false;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 预设版本列表
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.presetVersions.length,
                      separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05)),
                      itemBuilder: (context, index) {
                        final versionObj = widget.presetVersions[index];
                        final versionStr = versionObj.versionString;
                        final isSelected = !_isCustomInput &&
                            (_selectedResult is SoftwareVersion &&
                                (_selectedResult as SoftwareVersion)
                                        .versionString ==
                                    versionStr);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedResult = versionObj;
                              _isCustomInput = false;
                              _customController.clear();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    versionStr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.9)
                                              : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                      size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 底部操作按钮
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF2F2F7),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          i18n.t('cancel'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedResult),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text(
                          i18n.t('confirm'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
