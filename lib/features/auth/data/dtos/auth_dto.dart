/// 보호자 인증 화면의 DTO. 손으로 쓴 `fromJson` 입니다.
/// → `docs/SCREEN_RECIPE.md`
library;

import '../../domain/entities/auth_options.dart';

class AuthOptionsDto {
  const AuthOptionsDto({
    required this.providers,
    required this.consents,
    required this.ages,
    required this.demoAccounts,
  });

  factory AuthOptionsDto.fromJson(Map<String, dynamic> json) => AuthOptionsDto(
    providers: _objects(
      json['providers'],
    ).map(SocialProviderDto.fromJson).toList(growable: false),
    consents: _objects(
      json['consents'],
    ).map(ConsentItemDto.fromJson).toList(growable: false),
    ages: (json['ages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<int>()
        .toList(growable: false),
    demoAccounts: _objects(
      json['demoAccounts'],
    ).map(DemoAccountDto.fromJson).toList(growable: false),
  );

  final List<SocialProviderDto> providers;
  final List<ConsentItemDto> consents;
  final List<int> ages;

  /// **목업 전용.** 실제 서버 응답에는 없습니다 — 진짜 인증이 붙으면
  /// 이 필드와 `auth_screen.json` 의 `demoAccounts` 가 함께 사라집니다.
  final List<DemoAccountDto> demoAccounts;

  AuthOptions toEntity() => AuthOptions(
    providers: providers
        .map((SocialProviderDto dto) => dto.toEntity())
        .toList(growable: false),
    consents: consents
        .map((ConsentItemDto dto) => dto.toEntity())
        .toList(growable: false),
    ages: ages,
  );
}

class SocialProviderDto {
  const SocialProviderDto({required this.provider, required this.label});

  factory SocialProviderDto.fromJson(Map<String, dynamic> json) =>
      SocialProviderDto(
        provider: json['provider'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );

  final String provider;
  final String label;

  SocialProvider toEntity() => SocialProvider(provider: provider, label: label);
}

class ConsentItemDto {
  const ConsentItemDto({
    required this.id,
    required this.title,
    required this.required,
    this.docUrl,
  });

  factory ConsentItemDto.fromJson(Map<String, dynamic> json) => ConsentItemDto(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    required: json['required'] as bool? ?? false,
    docUrl: json['docUrl'] as String?,
  );

  final String id;
  final String title;
  final bool required;
  final String? docUrl;

  ConsentItem toEntity() =>
      ConsentItem(id: id, title: title, required: required, docUrl: docUrl);
}

/// 목업 로그인이 대조할 계정. 서버가 붙으면 사라집니다.
class DemoAccountDto {
  const DemoAccountDto({
    required this.email,
    required this.password,
    required this.hasChild,
  });

  factory DemoAccountDto.fromJson(Map<String, dynamic> json) => DemoAccountDto(
    email: json['email'] as String? ?? '',
    password: json['password'] as String? ?? '',
    hasChild: json['hasChild'] as bool? ?? false,
  );

  final String email;
  final String password;

  /// 이미 아이 프로필이 있는 계정인지. 로그인 후 분기를 가릅니다.
  final bool hasChild;
}

List<Map<String, dynamic>> _objects(Object? raw) =>
    (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
