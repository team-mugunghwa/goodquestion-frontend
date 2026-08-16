import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/dio_client.dart';
import '../../mypage/domain/entities/my_page_summary.dart';
import '../../mypage/domain/repositories/my_page_repository.dart';

/// 담기 한 번의 결과. [savedWord] 는 서버가 실제로 저장한 표제어 -
/// "기왓장이"를 눌러도 "기왓장"으로 저장되므로, 안내 문구는 이 값을 써야
/// 아이가 단어장에서 보게 될 형태와 같다.
class WordCaptureOutcome {
  const WordCaptureOutcome(this.result, {this.savedWord});

  final WordCaptureResult result;
  final String? savedWord;
}

/// 담기 결과. 실패(네트워크 등)는 [Failure] 로 던져지고, 여기에는
/// **화면이 다르게 안내해야 하는 성공 갈래**만 담습니다.
enum WordCaptureResult {
  /// 새로 담겼다.
  saved,

  /// 이미 담아 둔 단어다(서버 409 DUPLICATE_WORD). 에러가 아니라
  /// "이미 있어요" 안내 대상입니다 - 아이가 같은 단어를 두 번 궁금해하는 건
  /// 자연스러운 일입니다.
  duplicate,
}

/// 이야기 화면에서 아이가 고른 단어를 단어장에 담습니다.
///
/// word 기능의 저장소를 쓰지 않고 따로 둔 이유: 단어장 화면의 실서버 연동이
/// 진행 중이라(#32) 그쪽 계층이 통째로 바뀌는 중입니다. 재생 화면이 필요한
/// 건 "담기" 호출 하나뿐이라 자족적으로 두고, 단어장 연동이 정착하면
/// 합치는 후속을 남깁니다.
abstract interface class DialogueWordCapture {
  /// [word] 를 "모르는 말"로 담습니다.
  ///
  /// [sourceSceneId] 는 지금 장면 - 서버가 이 장면의 설명을 문맥으로 써서
  /// **이야기 안에서 쓰인 뜻**으로 풀이를 만듭니다(단어-06).
  /// [exampleSentence] 는 아이가 단어를 고른 그 대사 문장 - 서버는 요청에
  /// 예문이 있으면 생성분보다 우선합니다(이야기 원문이라서).
  Future<WordCaptureOutcome> save({
    required String word,
    String? sourceSceneId,
    String? exampleSentence,
  });
}

class RemoteDialogueWordCapture implements DialogueWordCapture {
  RemoteDialogueWordCapture(this._client, this._children);

  final DioClient _client;
  final ChildProfileRepository _children;

  @override
  Future<WordCaptureOutcome> save({
    required String word,
    String? sourceSceneId,
    String? exampleSentence,
  }) async {
    try {
      final String? childId = await _selectedChildId();
      if (childId == null) {
        throw const UnknownFailure('아이 정보를 찾을 수 없습니다.');
      }
      // 서버는 표제어로 정규화해 저장한다("기왓장이" -> "기왓장"). 응답의
      // word가 실제 저장된 형태라 안내 문구가 이 값을 쓴다.
      final String? savedWord = await _client.post<String?>(
        '/children/$childId/words',
        body: <String, dynamic>{
          'word': word,
          'entryType': 'UNKNOWN',
          if (sourceSceneId != null) 'sourceSceneId': sourceSceneId,
          if (exampleSentence != null && exampleSentence.trim().isNotEmpty)
            'exampleSentence': exampleSentence.trim(),
        },
        parse: (Object? data) =>
            data is Map<String, dynamic> ? data['word'] as String? : null,
      );
      return WordCaptureOutcome(WordCaptureResult.saved, savedWord: savedWord);
    } on Failure catch (failure) {
      if (_isDuplicate(failure)) {
        return const WordCaptureOutcome(WordCaptureResult.duplicate);
      }
      rethrow;
    } on ServerException catch (error) {
      if (error.code == 'DUPLICATE_WORD') {
        return const WordCaptureOutcome(WordCaptureResult.duplicate);
      }
      throw Failure.fromException(error);
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }

  static bool _isDuplicate(Failure failure) =>
      failure is ServerFailure && failure.code == 'DUPLICATE_WORD';

  /// 선택된 아이가 없으면 첫 아이를 고릅니다 - 설정 화면과 같은 규칙
  /// (`settings_repository_impl.dart`).
  Future<String?> _selectedChildId() async {
    final String? selectedId = _children.selectedChildId;
    if (selectedId != null) return selectedId;
    final List<MyPageChild> children = await _children.getChildren();
    if (children.isEmpty) return null;
    await _children.selectChild(children.first.childId);
    return children.first.childId;
  }
}
