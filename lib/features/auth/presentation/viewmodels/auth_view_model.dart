import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/auth_options.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/usecases/auth_use_cases.dart';

/// `/auth` 안의 세 스텝.
///
/// **별도 라우트로 쪼개지 않았습니다.** 중간에 이탈했다가 돌아와도 어디서든
/// `/auth` 하나로 수렴해야 하기 때문입니다. 스텝을 URL 로 만들면
/// `/auth/consent` 같은 주소가 북마크되고, 로그인 안 된 채로 그리 들어옵니다.
enum AuthStep { signIn, consent, childProfile }

/// 보호자 인증의 상태.
///
/// 화면 하나에 폼이 세 개라 ViewModel 도 그만큼 큽니다. 대신 **화면 이동을
/// 여기서 하지 않습니다** — [completed] 가 true 가 되면 View 가 홈으로 보냅니다.
/// (`docs/ARCHITECTURE.md` 4장)
class AuthViewModel extends BaseViewModel {
  AuthViewModel(
    this._getOptions,
    this._signInWithSocial,
    this._signInWithEmail,
    this._saveConsents,
    this._createChild,
    this._signOut, {
    Future<String?> Function()? loadCurrentChildName,
    bool startAtChildProfile = false,
  }) : _step = startAtChildProfile ? AuthStep.childProfile : AuthStep.signIn,
       _enteredAtChildProfile = startAtChildProfile,
       // named 파라미터라 초기화 형식(this._loadCurrentChildName)으로 못 바꿉니다
       // — Dart 는 밑줄로 시작하는 named 인자를 허용하지 않습니다.
       // ignore: prefer_initializing_formals
       _loadCurrentChildName = loadCurrentChildName;

  final GetAuthOptionsUseCase _getOptions;
  final SignInWithSocialUseCase _signInWithSocial;
  final SignInWithEmailUseCase _signInWithEmail;
  final SaveConsentsUseCase _saveConsents;
  final CreateChildUseCase _createChild;
  final SignOutUseCase _signOut;
  final Future<String?> Function()? _loadCurrentChildName;

  AuthOptions? _options;
  AuthStep _step;

  /// 프로필 없는 기존 계정으로 곧장 스텝 3 에 들어왔는가.
  ///
  /// 이때 뒤로가기는 스텝 2 로 가면 안 됩니다 — 동의는 이미 했고, 홈으로
  /// 보내면 게이트 원칙이 깨집니다. 남는 선택지는 **로그아웃**뿐입니다.
  final bool _enteredAtChildProfile;

  // ── 스텝 1 ──
  bool _isSignUpMode = false;
  String _email = '';
  String _password = '';
  String _guardianName = '';
  bool _rememberMe = true;
  String? _formError;

  // ── 스텝 2 ──
  final Set<String> _agreed = <String>{};

  /// 필수 항목을 안 채운 채 눌렀는가. View 가 흔들림으로 강조하고 지웁니다.
  bool _consentShake = false;

  // ── 스텝 3 ──
  String _childName = '';
  int? _childAge;

  bool _submitting = false;
  bool _completed = false;

  AuthOptions? get options => _options;
  AuthStep get step => _step;
  bool get isSignUpMode => _isSignUpMode;
  String get email => _email;
  bool get rememberMe => _rememberMe;
  String? get formError => _formError;
  Set<String> get agreed => Set<String>.unmodifiable(_agreed);
  String get childName => _childName;
  int? get childAge => _childAge;

  /// 제출 중. 버튼을 잠그고 입력을 막습니다 — 중복 제출 방지.
  bool get isSubmitting => _submitting;

  /// 다 끝났다. View 가 홈으로 보냅니다.
  bool get completed => _completed;

  /// 뒤로가기가 로그아웃을 의미하는 상황인가.
  bool get backMeansSignOut =>
      _step == AuthStep.childProfile && _enteredAtChildProfile;

  /// 스텝 인디케이터에 쓰는 1-based 번호. 로그인은 표시하지 않습니다.
  int get stepNumber => switch (_step) {
    AuthStep.signIn => 1,
    AuthStep.consent => 2,
    AuthStep.childProfile => 3,
  };

  /// 필수 동의를 다 채웠는가.
  bool get canContinueConsent {
    final AuthOptions? options = _options;
    if (options == null) return false;
    return options.requiredConsentIds.every(_agreed.contains);
  }

  /// 이름과 나이가 다 있는가. **에러가 아니라 비활성**으로 처리합니다 —
  /// 아직 입력하지 않은 걸 틀렸다고 하면 안 됩니다.
  bool get canStart => _childName.trim().isNotEmpty && _childAge != null;

  /// 한 번 읽고 지웁니다.
  bool takeConsentShake() {
    final bool value = _consentShake;
    _consentShake = false;
    return value;
  }

  Future<void> load() => guard(() async {
    _options = await _getOptions();
  });

  // ── 스텝 1 ──

  void setEmail(String value) {
    _email = value;
    if (_formError != null) {
      _formError = null;
      safeNotify();
    }
  }

  void setPassword(String value) {
    _password = value;
    if (_formError != null) {
      _formError = null;
      safeNotify();
    }
  }

  void setGuardianName(String value) {
    _guardianName = value;
    if (_formError != null) {
      _formError = null;
      safeNotify();
    }
  }

  void setRememberMe(bool value) {
    _rememberMe = value;
    safeNotify();
  }

  void toggleSignUpMode() {
    _isSignUpMode = !_isSignUpMode;
    _formError = null;
    safeNotify();
  }

  Future<void> signInWithSocial(String provider) =>
      _submit(() => _signInWithSocial(provider, rememberMe: _rememberMe));

  Future<void> submitEmail() {
    // 서버에 보내기 전에 잡을 수 있는 건 여기서 잡습니다.
    if (_email.trim().isEmpty) return _fail(AuthStrings.emailRequired);
    if (_password.isEmpty) return _fail(AuthStrings.passwordRequired);
    if (_isSignUpMode && _guardianName.trim().isEmpty) {
      return _fail(AuthStrings.nameRequired);
    }
    return _submit(
      () => _signInWithEmail(
        email: _email.trim(),
        password: _password,
        isSignUp: _isSignUpMode,
        name: _guardianName.trim(),
        rememberMe: _rememberMe,
      ),
    );
  }

  // ── 스텝 2 ──

  void toggleConsent(String id) {
    if (!_agreed.remove(id)) _agreed.add(id);
    safeNotify();
  }

  /// 전체 동의. 하나라도 빠져 있으면 전부 켜고, 다 켜져 있으면 전부 끕니다.
  void toggleAll() {
    final AuthOptions? options = _options;
    if (options == null) return;
    final List<String> all = options.consents
        .map((ConsentItem c) => c.id)
        .toList(growable: false);
    if (all.every(_agreed.contains)) {
      _agreed.clear();
    } else {
      _agreed.addAll(all);
    }
    safeNotify();
  }

  bool get isAllAgreed {
    final AuthOptions? options = _options;
    if (options == null || options.consents.isEmpty) return false;
    return options.consents.every((ConsentItem c) => _agreed.contains(c.id));
  }

  Future<void> submitConsents() async {
    if (!canContinueConsent) {
      // 버튼을 비활성으로 두지 않고 **눌리되 이유를 알려 줍니다** —
      // 왜 못 누르는지 모르는 비활성 버튼이 가장 답답합니다.
      _consentShake = true;
      safeNotify();
      return;
    }
    await _saveConsents(_agreed);
    _step = AuthStep.childProfile;
    safeNotify();
  }

  // ── 스텝 3 ──

  void setChildName(String value) {
    _childName = value;
    safeNotify();
  }

  void setChildAge(int age) {
    _childAge = age;
    safeNotify();
  }

  Future<void> submitChild() async {
    if (!canStart || _submitting) return;
    _submitting = true;
    safeNotify();
    try {
      await _createChild(name: _childName.trim(), age: _childAge!);
      _completed = true;
    } catch (e) {
      setError(e);
    } finally {
      _submitting = false;
      safeNotify();
    }
  }

  // ── 이동 ──

  /// 스텝 뒤로. [backMeansSignOut] 인 경우는 View 가 먼저 확인을 받습니다.
  void goBack() {
    _step = switch (_step) {
      AuthStep.childProfile => AuthStep.consent,
      AuthStep.consent => AuthStep.signIn,
      AuthStep.signIn => AuthStep.signIn,
    };
    safeNotify();
  }

  Future<void> signOut() async {
    await _signOut();
    _step = AuthStep.signIn;
    _agreed.clear();
    _email = '';
    _password = '';
    _guardianName = '';
    _childName = '';
    _childAge = null;
    safeNotify();
  }

  Future<void> _submit(Future<AuthOutcome> Function() action) async {
    if (_submitting) return;
    _submitting = true;
    _formError = null;
    safeNotify();
    try {
      final AuthOutcome outcome = await action();
      _step = switch (outcome) {
        AuthOutcome.needsConsent => AuthStep.consent,
        AuthOutcome.needsChild => AuthStep.childProfile,
        AuthOutcome.ready => _step,
      };
      if (outcome == AuthOutcome.ready) {
        try {
          final String? currentChildName = await _loadCurrentChildName?.call();
          if (currentChildName != null && currentChildName.trim().isNotEmpty) {
            _childName = currentChildName.trim();
          }
        } on Object {
          // 로그인은 이미 완료되었습니다. 프로필 이름 조회 실패가
          // 인증 성공 자체를 취소하지 않도록 기본 환영 문구로 진행합니다.
        }
        _completed = true;
      }
    } catch (e) {
      // 로그인 실패는 화면을 통째로 에러로 바꾸지 않습니다.
      // 폼은 그대로 두고 인라인 메시지만 답니다 — 다시 입력할 자리가
      // 사라지면 사용자는 앱을 껐다 켭니다.
      _formError = _messageOf(e);
    } finally {
      _submitting = false;
      safeNotify();
    }
  }

  Future<void> _fail(String message) async {
    _formError = message;
    safeNotify();
  }

  String _messageOf(Object error) =>
      error is Failure ? error.message : Failure.fromException(error).message;
}
