import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/widgets/app_state_views.dart';

/// 행성 웹앱과 주고받는 postMessage 의 채널 이름. 행성 쪽 `api/host.ts` 와
/// 같은 값이어야 합니다.
const String _channel = 'goodquestion.planet';

// package:web 를 의존성에 추가하지 않으려고 필요한 DOM API 만 직접 선언합니다.
// (pubspec 을 건드리지 않고, 쓰는 멤버가 다섯 개뿐이라 직접 선언이 더 쌉니다)

@JS('document.createElement')
external JSObject _createElement(String tag);

@JS('window.addEventListener')
external void _addWindowEventListener(String type, JSFunction listener);

@JS('window.removeEventListener')
external void _removeWindowEventListener(String type, JSFunction listener);

extension type _IFrameElement(JSObject _) implements JSObject {
  external set src(String value);
  external void setAttribute(String name, String value);
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// 행성 → 본체 신호. `{ channel: 'goodquestion.planet', type, ... }` 형태로
/// 오고, 없는 필드는 null 로 읽힙니다. → 팀원공유 `행성_연동규약.md` §2
extension type _PlanetSignal(JSObject _) implements JSObject {
  external String? get channel;
  external String? get type;
  external String? get reason;
}

/// 행성 웹앱(`web/planet_app/`)을 같은 도메인 iframe 으로 심습니다.
///
/// 신원(토큰·childId)은 **iframe 주소의 쿼리**로 넘깁니다. postMessage 로
/// 넘기면 행성의 첫 서버 조회(loadPlanet)와 경합해서, auth 가 늦게 도착하면
/// 행성이 독립 모드(빈 섬)로 굳습니다. 쿼리는 행성이 렌더 전에 읽고 주소에서
/// 지우므로 경합이 없습니다. → 행성 `api/host.ts` 의 adoptFromUrl
class PlanetFrame extends StatefulWidget {
  const PlanetFrame({
    required this.token,
    required this.childId,
    required this.onExit,
    super.key,
  });

  /// 부모 accessToken. 행성이 Authorization 헤더에 싣습니다.
  final String token;

  /// 어느 아이의 행성인지. 서버 경로(`/api/children/{childId}/...`)에 들어갑니다.
  final String childId;

  /// 행성이 "나가기" 신호를 보냈을 때. 목적지는 본체가 정합니다.
  final VoidCallback onExit;

  @override
  State<PlanetFrame> createState() => _PlanetFrameState();
}

class _PlanetFrameState extends State<PlanetFrame> {
  /// 뷰 팩토리는 앱 수명 동안 등록만 되고 해제가 없습니다. 같은 이름을 두 번
  /// 등록하면 처음 것(이전 토큰을 문 클로저)이 남으므로 매번 새 이름을 씁니다.
  final String _viewType =
      'planet-frame-${DateTime.now().microsecondsSinceEpoch}';

  late final JSFunction _messageListener;

  /// WebGL 컨텍스트 생성 실패. iframe 자체가 무용지물이라 본체 화면으로 덮습니다.
  bool _webglFailed = false;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final _IFrameElement frame = _IFrameElement(_createElement('iframe'));
      frame.setAttribute('style', 'border:none; width:100%; height:100%;');
      frame.setAttribute('title', '내 행성');
      frame.src = _frameUrl();
      return frame;
    });
    _messageListener = _onMessage.toJS;
    _addWindowEventListener('message', _messageListener);
  }

  @override
  void dispose() {
    _removeWindowEventListener('message', _messageListener);
    super.dispose();
  }

  String _frameUrl() {
    // AppConfig.apiBaseUrl 은 `.../api` 까지 포함하지만 행성은 origin 만 받고
    // 스스로 `/api/...` 를 붙입니다. → web/planet_app/planet-config.js
    final String apiOrigin = AppConfig.apiBaseUrl.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );
    return Uri(
      path: '/planet_app/index.html',
      queryParameters: <String, String>{
        'api': apiOrigin,
        't': widget.token,
        'c': widget.childId,
      },
    ).toString();
  }

  void _onMessage(JSObject event) {
    final JSAny? data = _MessageEvent(event).data;
    // Flutter 엔진도 window 로 message 를 흘리므로 채널부터 확인합니다.
    if (data == null || !data.typeofEquals('object')) return;
    final _PlanetSignal signal = _PlanetSignal(data as JSObject);
    if (signal.channel != _channel) return;

    switch (signal.type) {
      case 'exit':
        widget.onExit();
      case 'error':
        // 서버 조회 실패(planet-load-failed)는 행성이 자체 배너로 알리고 캐시로
        // 계속 동작하므로 그대로 둡니다. 3D 를 아예 못 그리는 경우만 덮습니다.
        if (signal.reason == 'webgl-unavailable' && mounted) {
          setState(() => _webglFailed = true);
        }
      // 'ready' 는 행성이 자체 부팅 화면을 갖고 있어 따로 할 일이 없고,
      // 'balance' 는 홈이 재진입 시 서버에서 다시 읽으므로 여기서 안 씁니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_webglFailed) {
      return AppKidMessageView(
        message: '이 기기에서는 행성을 열 수 없어요',
        actionIcon: AppIcons.home,
        actionLabel: '홈으로',
        onAction: widget.onExit,
      );
    }
    return HtmlElementView(viewType: _viewType);
  }
}
