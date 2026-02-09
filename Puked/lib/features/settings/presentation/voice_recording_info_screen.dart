import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/utils/i18n.dart';

import 'package:markdown/markdown.dart' as md;

class VoiceRecordingInfoScreen extends ConsumerWidget {
  const VoiceRecordingInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final locale = i18n.locale;
    final isZh = locale.languageCode == 'zh';

    // 根据系统语言自动切换本地 MD 文件
    final assetPath = isZh
        ? 'assets/voice_recording/voice_zh.md'
        : 'assets/voice_recording/voice_en.md';

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('voice_recording_title')),
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Markdown(
              data: snapshot.data!,
              selectable: true,
              padding: const EdgeInsets.all(20),
              // 注册自定义图标构建器
              builders: {
                'emoji': IconElementBuilder(context),
              },
              // 扩展 Markdown 语法以识别 :icon_name:
              inlineSyntaxes: [
                EmojiSyntax(),
              ],
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                h1: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 2.0,
                ),
                h3: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5,
                ),
                p: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                ),
                blockSpacing: 16.0,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error loading voice recording info: ${snapshot.error}'));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// 自定义语法：识别 :icon_name: 格式并创建元素节点
class EmojiSyntax extends md.InlineSyntax {
  EmojiSyntax() : super(r':(\w+):');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String iconName = match[1]!;
    // 创建一个 'emoji' 类型的元素，文本内容为图标名称
    final element = md.Element.text('emoji', iconName);
    parser.addNode(element);
    return true;
  }
}

/// 自定义图标构建器：将 :name: 转换为 Flutter Icon
class IconElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  IconElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // textContent 现在直接就是图标名称（如 "pan_tool"）
    final String name = element.textContent;

    IconData? iconData;
    Color? color;

    // 映射 App 内部使用的图标和颜色
    switch (name) {
      case 'pan_tool':
        iconData = Icons.pan_tool;
        color = const Color(0xFFFF3B30); // 智驾接管 - 红色
        break;
      case 'gavel':
        iconData = Icons.gavel;
        color = const Color(0xFF5856D6); // 法规违章 - 紫色
        break;
      case 'sentiment_dissatisfied':
        iconData = Icons.sentiment_dissatisfied;
        color = const Color(0xFF007AFF); // 智驾体验 - 蓝色
        break;
      case 'stars':
        iconData = Icons.stars;
        color = const Color(0xFF34C759); // 手动记录 - 绿色
        break;
    }

    if (iconData != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(iconData, size: 24, color: color),
      );
    }
    return null;
  }
}
