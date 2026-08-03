import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 미니멀 공용 편집 다이얼로그
Widget minimalField(TextEditingController ctrl, String label, {String? hint}) {
  return TextField(
    controller: ctrl,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

void showMinimalEditDialog(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  required VoidCallback onSave,
  String saveLabel = '저장',
}) {
  showDialog(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (ctx) => Dialog(
      backgroundColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.rLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              ...children,
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('취소',
                        style: TextStyle(color: AppTokens.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      onSave();
                      Navigator.pop(ctx);
                    },
                    child: Text(saveLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
