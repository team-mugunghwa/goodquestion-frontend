import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_list.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/guardian_gate.dart';
import '../../domain/usecases/my_page_use_cases.dart';
import '../viewmodels/my_page_view_model.dart';
import '../widgets/child_profile_card.dart';
import '../widgets/guardian_gate_dialog.dart';

/// 마이페이지 — 계정·관리 허브.
///
/// ## 경계에 있는 화면입니다
///
/// 하단 내비에 있어서 아이가 누를 수 있지만 **내용은 보호자 것**입니다.
/// 그래서 바탕은 `guardian`, 글자는 보호자 스케일을 쓰되, 리포트 진입만
/// 보호자 확인 게이트 뒤에 둡니다. (PRD F-09, `docs/DESIGN_SYSTEM.md` 2장)
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 헤더 — "마이페이지" (탭 루트라 뒤로가기 없음) |
/// | 2 | 현재 아이 프로필 카드 + 활동 요약 |
/// | 3 | 보호자 메뉴 — 리포트 (자물쇠 + 새 리포트 배지) |
/// | 4 | 관리 — 아이 추가 · 설정 |
/// | 5 | 하단 내비 (마이 활성) |
///
/// 이 화면은 허브이지 콘텐츠 화면이 아닙니다. 리포트 내용·프로필 편집 폼을
/// 여기서 펼치지 않고 모달·하위 라우트로 넘깁니다.
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MyPageViewModel>(
      create: (_) => MyPageViewModel(
        getIt<GetMyPageSummaryUseCase>(),
        getIt<CreateMyPageChildUseCase>(),
        getIt<GetMyPageChildrenUseCase>(),
        getIt<SelectMyPageChildUseCase>(),
      )..load(),
      child: const MyPageView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final MyPageViewModel vm = context.watch<MyPageViewModel>();

    return GuardianScaffold(
      title: MyPageStrings.title,
      bottomNav: const AppBottomNav(current: AppNavTab.myPage),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          _profileArea(context, vm),
          const SizedBox(height: AppSpacing.xl),
          // 메뉴는 정적이라 로딩 중에도 즉시 보입니다. 화면 전체가 스켈레톤이
          // 되면 보호자는 앱이 멈춘 줄 압니다.
          GuardianSection(
            title: MyPageStrings.guardianMenu,
            children: <Widget>[
              GuardianTile(
                icon: AppIcons.locked,
                label: MyPageStrings.report,
                showBadge: vm.summary?.hasNewReport ?? false,
                // 아이가 없으면 볼 리포트도 없습니다.
                enabled: vm.hasChild,
                onTap: () => _openReport(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GuardianSection(
            title: MyPageStrings.manageMenu,
            children: <Widget>[
              GuardianTile(
                icon: AppIcons.add,
                label: MyPageStrings.addChild,
                onTap: () => _openChildForm(context),
              ),
              GuardianTile(
                icon: AppIcons.settings,
                label: MyPageStrings.settings,
                onTap: () => context.go(AppRoutes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileArea(BuildContext context, MyPageViewModel vm) {
    if (vm.state.isError) {
      return AppErrorView(
        message: vm.errorMessage ?? MyPageStrings.loadFailed,
        onRetry: vm.load,
      );
    }
    final MyPageSummary? summary = vm.summary;
    if (summary == null) {
      return const SkeletonBox(height: 180, borderRadius: AppRadius.md);
    }
    return ChildProfileCard(
      summary: summary,
      onSwitch: () => _openChildSwitch(context),
      onEdit: () => _openChildForm(context),
      onCreate: () => _openChildForm(context),
    );
  }

  /// 리포트는 보호자 확인을 통과해야 열립니다. **같은 세션 안에서 한 번만**
  /// 묻습니다 — 목록과 상세를 오갈 때마다 물으면 아무도 안 씁니다.
  Future<void> _openReport(BuildContext context) async {
    final GuardianGate gate = getIt<GuardianGate>();
    if (!gate.isPassed) {
      final bool passed = await showGuardianGateDialog(context);
      if (!passed) return;
      gate.pass();
    }
    if (!context.mounted) return;
    unawaited(context.push(AppRoutes.report));
  }

  /// 아이 프로필 추가·수정 모달의 자리.
  ///
  /// 모달 내부 폼은 별도 설계 범위라, 여기서는 호출 지점만 만들어 둡니다.
  /// 지금은 최초 등록 화면(`/auth`)이 같은 일을 하므로 그리로 보냅니다.
  Future<void> _openChildForm(BuildContext context) async {
    final _ChildFormValue? value = await showModalBottomSheet<_ChildFormValue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const _ChildProfileForm(),
    );
    if (value == null || !context.mounted) return;

    final MyPageViewModel vm = context.read<MyPageViewModel>();
    final bool saved = await vm.addChild(name: value.name, age: value.age);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? '아이 프로필이 저장되었습니다.' : vm.childSaveError ?? '저장하지 못했습니다.',
        ),
      ),
    );
  }

  /// 아이 프로필 전환 모달(모달 6)의 자리. 홈의 호출 지점과 같은 모달입니다.
  Future<void> _openChildSwitch(BuildContext context) async {
    final MyPageViewModel vm = context.read<MyPageViewModel>();
    final String? childId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                MyPageStrings.switchChild,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '학습할 아이를 선택해 주세요.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: vm.children.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final MyPageChild child = vm.children[index];
                    final bool selected =
                        child.childId == vm.summary?.child?.childId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      leading: CircleAvatar(
                        child: Text(
                          child.name.isEmpty ? '?' : child.name.substring(0, 1),
                        ),
                      ),
                      title: Text(child.name),
                      subtitle: Text('${child.age}살'),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.circle_outlined),
                      selected: selected,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(child.childId),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openChildForm(context);
                },
                icon: const Icon(AppIcons.add),
                label: const Text('새 아이 프로필 추가'),
              ),
            ],
          ),
        ),
      ),
    );
    if (childId == null || !context.mounted) return;
    if (childId == vm.summary?.child?.childId) return;

    final bool switched = await vm.switchChild(childId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switched
              ? '${vm.summary?.child?.name ?? ''} 프로필로 전환했습니다.'
              : vm.childSaveError ?? '프로필을 전환하지 못했습니다.',
        ),
      ),
    );
  }
}

class _ChildFormValue {
  const _ChildFormValue(this.name, this.age);

  final String name;
  final int age;
}

class _ChildProfileForm extends StatefulWidget {
  const _ChildProfileForm();

  @override
  State<_ChildProfileForm> createState() => _ChildProfileFormState();
}

class _ChildProfileFormState extends State<_ChildProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  int _age = 7;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('아이 프로필 추가', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '아이의 이름과 나이를 입력해 주세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 50,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '아이 이름',
                  hintText: '예: 하늘',
                ),
                validator: (String? value) =>
                    value == null || value.trim().isEmpty
                    ? '아이 이름을 입력해 주세요.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _age,
                decoration: const InputDecoration(labelText: '나이'),
                items: <DropdownMenuItem<int>>[
                  for (int age = 4; age <= 13; age++)
                    DropdownMenuItem<int>(value: age, child: Text('$age세')),
                ],
                onChanged: (int? value) {
                  if (value != null) _age = value;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(
      context,
    ).pop(_ChildFormValue(_nameController.text.trim(), _age));
  }
}
