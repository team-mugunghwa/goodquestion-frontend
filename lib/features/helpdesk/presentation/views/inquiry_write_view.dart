import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';

/// 문의 작성.
/// [initial] 이 있으면 수정 모드입니다 - 답변 전 문의만 이 화면으로 올 수
/// 있고, 저장은 PATCH 로 나갑니다.
class InquiryWritePage extends StatelessWidget {
  const InquiryWritePage({super.key, this.initial});

  final Inquiry? initial;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InquiryWriteViewModel>(
      create: (_) => InquiryWriteViewModel(
        getIt<CreateInquiryUseCase>(),
        getIt<UpdateInquiryUseCase>(),
        initial: initial,
      ),
      child: InquiryWriteView(initial: initial),
    );
  }
}

class InquiryWriteView extends StatefulWidget {
  const InquiryWriteView({super.key, this.initial});

  final Inquiry? initial;

  @override
  State<InquiryWriteView> createState() => _InquiryWriteViewState();
}

class _InquiryWriteViewState extends State<InquiryWriteView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.initial?.content ?? '',
  );

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final InquiryWriteViewModel vm = context.read<InquiryWriteViewModel>();
    final Inquiry? created = await vm.submit(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );
    if (!mounted) return;

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.errorMessage ??
                (_isEdit ? '문의를 수정하지 못했습니다.' : '문의를 등록하지 못했습니다.'),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? '문의를 수정했습니다.' : '문의를 접수했습니다. 답변이 등록되면 알려드릴게요.'),
      ),
    );
    // 수정 모드는 상세로 돌아가 새 내용을 보여줘야 한다 - pop 결과로 알린다.
    context.pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final InquiryWriteViewModel vm = context.watch<InquiryWriteViewModel>();
    final TextTheme text = Theme.of(context).textTheme;

    return GuardianScaffold(
      title: _isEdit ? '문의 수정' : '문의하기',
      onBack: () => context.pop(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: <Widget>[
            Text('문의 유형', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<InquiryCategory>(
              initialValue: vm.category,
              items: <DropdownMenuItem<InquiryCategory>>[
                for (final InquiryCategory category in InquiryCategory.values)
                  DropdownMenuItem<InquiryCategory>(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (InquiryCategory? value) => value == null
                  ? null
                  : context.read<InquiryWriteViewModel>().changeCategory(value),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('제목', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(hintText: '어떤 점이 궁금하신가요?'),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                  ? '제목을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            Text('내용', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _contentController,
              maxLines: 8,
              minLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    '겪으신 상황을 알려주시면 더 빠르게 도와드릴 수 있어요.\n'
                    '사용 중인 기기와 아이 이름도 함께 적어주세요.',
              ),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                  ? '내용을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              '답변이 등록되면 알림으로 알려드립니다. 알림함에서도 다시 확인하실 수 있어요.',
              style: text.bodySmall?.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: vm.isSubmitting ? null : _submit,
              child: Text(
                vm.isSubmitting
                    ? (_isEdit ? '수정 중...' : '등록 중...')
                    : (_isEdit ? '수정 완료' : '문의 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
