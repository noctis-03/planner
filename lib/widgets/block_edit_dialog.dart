import 'package:flutter/material.dart';
import '../models/task_block.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// 블록 편집 결과
class BlockEditResult {
  final String time;
  final String title;
  final String desc;
  final String categoryId;
  BlockEditResult(this.time, this.title, this.desc, this.categoryId);
}

Future<BlockEditResult?> showBlockEditDialog(
    BuildContext context, TaskBlock block) {
  final timeCtrl = TextEditingController(text: block.time);
  final titleCtrl =
      TextEditingController(text: block.title == '새 일정' ? '' : block.title);
  final descCtrl = TextEditingController(text: block.desc);
  String selectedCat = block.categoryId;

  return showDialog<BlockEditResult>(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            backgroundColor: AppTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rLg),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '일정 편집',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: timeCtrl,
                        decoration: const InputDecoration(
                          labelText: '시간',
                          hintText: '0000 또는 1850 입력 → 자동 변환',
                        ),
                        onEditingComplete: () {
                          timeCtrl.text = autoFormatTime(timeCtrl.text);
                        },
                        onChanged: (v) {
                          // 숫자 4자리 완성 시 즉시 포맷
                          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length == 4) {
                            final f = autoFormatTime(v);
                            timeCtrl.value = TextEditingValue(
                              text: f,
                              selection:
                                  TextSelection.collapsed(offset: f.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '제목',
                          hintText: '무엇을 하나요?',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '설명 (선택)',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '카테고리',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kCategories.map((cat) {
                          final selected = cat.id == selectedCat;
                          return GestureDetector(
                            onTap: () => setState(() => selectedCat = cat.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? cat.tint : AppTokens.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? cat.color
                                      : AppTokens.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: cat.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? cat.color
                                          : AppTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('취소',
                                style: TextStyle(
                                    color: AppTokens.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                ctx,
                                BlockEditResult(
                                  autoFormatTime(timeCtrl.text),
                                  titleCtrl.text.trim().isEmpty
                                      ? '새 일정'
                                      : titleCtrl.text.trim(),
                                  descCtrl.text.trim(),
                                  selectedCat,
                                ),
                              );
                            },
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
