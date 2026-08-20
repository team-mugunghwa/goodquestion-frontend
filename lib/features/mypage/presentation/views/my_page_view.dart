import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/child_avatar.dart';
import '../../../../core/widgets/guardian_list.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../../../core/widgets/policy_document_view.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/guardian_gate.dart';
import '../../domain/usecases/my_page_use_cases.dart';
import '../viewmodels/my_page_view_model.dart';
import '../viewmodels/settings_view_model.dart';
import '../widgets/child_profile_card.dart';
import '../widgets/guardian_gate_dialog.dart';
import '../widgets/settings_sections.dart';

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
/// | 4 | 관리 — 아이 추가 |
/// | 5 | 알림 · 안내 · 약관 · 계정 (예전 설정 화면) |
/// | 6 | 하단 내비 (마이 활성) |
///
/// ## 설정을 별도 화면으로 두지 않습니다
///
/// 예전에는 `/settings` 가 따로 있었고, 알림 토글 하나 바꾸거나 로그아웃
/// 한 번 하려고 마이페이지에서 한 뎁스를 더 들어갔다 나와야 했습니다.
/// 보호자가 오래 머무는 화면이 아니라서 그 왕복이 그대로 마찰이었습니다.
/// → [SettingsSections]
///
/// 리포트 내용과 프로필 편집 폼은 여전히 모달·하위 라우트로 넘깁니다 —
/// 그건 "읽고 쓰는 콘텐츠"라 허브에 펼칠 것이 아닙니다.
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 설정을 이 화면에 펼치므로 설정 ViewModel 도 여기서 답니다.
    // 두 ViewModel 을 한 화면이 나눠 쓰는 건, 원래 두 화면이었던 것을
    // 합친 결과입니다 — 데이터 출처가 서로 다르기 때문입니다.
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<MyPageViewModel>(
          create: (_) => MyPageViewModel(
            getIt<GetMyPageSummaryUseCase>(),
            getIt<CreateMyPageChildUseCase>(),
            getIt<UpdateMyPageChildUseCase>(),
            getIt<GetMyPageChildrenUseCase>(),
            getIt<SelectMyPageChildUseCase>(),
          )..load(),
        ),
        ChangeNotifierProvider<SettingsViewModel>(
          create: (_) => SettingsViewModel(
            getIt<GetSettingsUseCase>(),
            getIt<SetReportNotificationUseCase>(),
            getIt<SetMarketingConsentUseCase>(),
          )..load(),
        ),
      ],
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
    final SettingsViewModel settingsVm = context.watch<SettingsViewModel>();

    // 마케팅 동의는 법적 의미가 있어서 바뀐 걸 알립니다.
    final bool? toast = settingsVm.takeMarketingToast();
    if (toast != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toast
                  ? SettingsStrings.marketingOn
                  : SettingsStrings.marketingOff,
            ),
          ),
        );
      });
    }

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
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // 예전에는 여기 "설정" 한 줄이 있었고, 알림 토글 하나 바꾸려 해도
          // 한 뎁스를 더 들어갔다 나와야 했습니다. 보호자가 오래 머무는
          // 화면이 아니라서 그 왕복이 그대로 마찰이었습니다. 펼칩니다.
          SettingsSections(vm: settingsVm),
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
      // 연필은 **지금 아이를 고치는** 자리입니다. 값을 안 넘기면 빈 폼이
      // 열리고, 저장하면 아이가 하나 더 생깁니다.
      onEdit: () => _openChildForm(context, child: summary.child),
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

  /// 아이 프로필 추가·수정 모달.
  ///
  /// [child] 가 있으면 **그 아이를 고치는** 폼입니다(지금 값이 채워진 채로
  /// 열리고 저장하면 PATCH). 없으면 빈 폼으로 새로 만듭니다.
  Future<void> _openChildForm(
    BuildContext context, {
    MyPageChild? child,
  }) async {
    final _ChildFormValue? value = await showModalBottomSheet<_ChildFormValue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => _ChildProfileForm(child: child),
    );
    if (value == null || !context.mounted) return;

    final MyPageViewModel vm = context.read<MyPageViewModel>();
    final bool saved = child == null
        ? await vm.addChild(name: value.name, age: value.age)
        : await vm.updateChild(
            childId: child.childId,
            name: value.name,
            age: value.age,
          );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (child == null ? '아이 프로필을 추가했습니다.' : '아이 프로필을 수정했습니다.')
              : vm.childSaveError ?? '저장하지 못했습니다.',
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
                      leading: ChildAvatar(
                        name: child.name,
                        image: child.avatar,
                        diameter: AppSizes.tapGuardian,
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

/// 아이 프로필 폼. **추가와 수정이 같은 폼을 씁니다.**
///
/// 받는 것이 이름과 나이로 똑같아서, 나누면 검증과 나이 선택이 두 벌이 되고
/// 한쪽만 고치는 실수가 생깁니다. 다른 것은 무엇을 하는 자리인지 알려 주는
/// 제목·안내·버튼 문구뿐이라 [child] 유무로 갈라 씁니다.
class _ChildProfileForm extends StatefulWidget {
  const _ChildProfileForm({this.child});

  /// null 이면 새로 만드는 폼, 있으면 그 아이를 고치는 폼입니다.
  final MyPageChild? child;

  @override
  State<_ChildProfileForm> createState() => _ChildProfileFormState();
}

class _ChildProfileFormState extends State<_ChildProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.child?.name ?? '',
  );

  /// 서버가 출생연도에서 계산해 내려준 나이를 그대로 씁니다. 목록에 없는
  /// 나이면(선택지는 4~13세) 값이 사라지지 않게 목록에 끼워 넣습니다.
  late int _age = widget.child?.age ?? 7;

  bool get _isEdit => widget.child != null;

  /// 아동 개인정보 수집 동의. **추가할 때만 받습니다** - 수정은 이미 동의를
  /// 받아 둔 아이를 고치는 것이고, 서버 동의 기록도 아이 생성 시점에
  /// 남습니다.
  bool _consented = false;
  bool _consentMissing = false;

  List<int> get _ageOptions =>
      <int>{for (int age = 4; age <= 13; age++) age, _age}.toList()..sort();

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
              Text(
                _isEdit ? '아이 프로필 수정' : '아이 프로필 추가',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isEdit ? '바꿀 내용을 고쳐 주세요.' : '아이의 이름과 나이를 입력해 주세요.',
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
                  for (final int age in _ageOptions)
                    DropdownMenuItem<int>(value: age, child: Text('$age세')),
                ],
                onChanged: (int? value) {
                  if (value != null) _age = value;
                },
              ),
              if (!_isEdit) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Checkbox(
                      value: _consented,
                      onChanged: (bool? value) => setState(() {
                        _consented = value ?? false;
                        if (_consented) _consentMissing = false;
                      }),
                    ),
                    Expanded(
                      child: Text(
                        '[${MyPageStrings.childConsentRequired}] '
                        '${MyPageStrings.childConsentLabel}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openChildPrivacy(context),
                      child: const Text(MyPageStrings.childConsentView),
                    ),
                  ],
                ),
                if (_consentMissing)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Text(
                      MyPageStrings.childConsentMissing,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
              ],
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
                      child: Text(_isEdit ? '수정' : '저장'),
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

  /// 동의 내용을 실제로 읽을 수 있어야 합니다. 설정에서 여는 것과 **같은
  /// 번들 문서**라 두 곳의 고지 내용이 갈리지 않습니다.
  void _openChildPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .82,
          child: const PolicyDocumentView(
            title: SettingsStrings.childPrivacy,
            assetPath: 'assets/policies/child_privacy.md',
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    // 동의 없이 아이만 만들어지면 그 아이로는 이야기를 시작할 수 없습니다.
    if (!_isEdit && !_consented) {
      setState(() => _consentMissing = true);
      return;
    }
    Navigator.of(
      context,
    ).pop(_ChildFormValue(_nameController.text.trim(), _age));
  }
}
