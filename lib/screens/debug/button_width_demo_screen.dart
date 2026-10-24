import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import '../../widgets/movielog_button.dart';

/// MovieLogButton의 width 세 가지(null · double.infinity · 고정 값)와
/// 상태 세 가지(기본 · 통신 중 · 비활성)를 한 화면에서 비교하는 디버그 전용 화면.
///
/// release 빌드에는 Route가 등록되지 않는다. (`/debug/buttons`)
class ButtonWidthDemoScreen extends StatelessWidget {
  const ButtonWidthDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MovieLogButton 비교'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Caption('width: null → 내용(label) 크기'),
          Align(
            alignment: Alignment.centerLeft,
            child: MovieLogButton(label: '중복 확인', onPressed: () {}),
          ),
          const _Caption('width: 96 → 항상 같은 크기'),
          Align(
            alignment: Alignment.centerLeft,
            child: MovieLogButton(label: '확인', width: 96, onPressed: () {}),
          ),
          const _Caption('width: double.infinity → 부모 최대 너비'),
          MovieLogButton(
            label: '가입하기',
            width: double.infinity,
            onPressed: () {},
          ),
          const _Caption('Row 안: Expanded(입력창) + width null 버튼'),
          Row(
            children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MovieLogButton(label: '중복 확인', onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const _Caption('상태: 기본 / 통신 중 / 비활성'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MovieLogButton(label: '기본', onPressed: () {}),
              MovieLogButton(label: '통신 중', isLoading: true, onPressed: () {}),
              const MovieLogButton(label: '비활성', onPressed: null),
            ],
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: AppTextStyles.bodySmall),
    );
  }
}
