import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/sentence_practice.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/repositories/word_repository.dart';

/// 따라 말하기 화면의 진행 단계.
enum PracticeStep { pick, speak, result }

/// 말하기 단계 안에서 마이크의 상태. mission_overlay 의 것과 같은 흐름에
/// 서버 제출(submitting)이 하나 더 있습니다.
enum PracticeVoiceStage { ready, recording, transcribing, submitting }

/// 결과 화면이 그릴 분기.
enum PracticeResultKind {
  /// 90% 이상 + 별가루 지급.
  rewarded,

  /// 맞았지만 이 문장으로는 이미 받았음.
  alreadyRewarded,

  /// 맞았지만 오늘 한도를 다 채웠음.
  dailyLimit,

  /// 90% 미만. 다시 해 보자고 격려합니다.
  notMatched,

  /// 이 종류의 예문이 아직 없음. (`EXAMPLE_SENTENCE_MISSING`)
  sentenceMissing,

  /// 네트워크 등 제출 자체가 실패함.
  failed,
}

/// 마이크 옆에 짧게 뜨는 안내. 문구는 View 가 `SentencePracticeStrings`
/// 에서 고릅니다 - ViewModel 은 화면 문구를 모릅니다.
enum PracticeMicHint { notHeard, tooLong, waitAndRetry, permission, micFailed }

/// 고를 수 있는 예문 하나.
class PracticeSentence {
  const PracticeSentence({required this.type, required this.text});

  final SentenceType type;
  final String text;
}

/// 따라 말하기의 상태 기계.
///
/// 녹음기(마이크 하드웨어)는 View 의 몫입니다. 여기는 녹음이 만든 WAV 를
/// 받아 "받아쓰기 -> 채점 -> 결과 분기"만 책임져서, 가짜 저장소 하나로
/// 단위 테스트가 됩니다.
class SentencePracticeViewModel extends BaseViewModel {
  SentencePracticeViewModel(
    this._repository, {
    required this.wordId,
    SavedWord? initialWord,
  }) : _word = initialWord;

  final WordRepository _repository;
  final String wordId;

  SavedWord? _word;
  PracticeStep _step = PracticeStep.pick;
  PracticeVoiceStage _voiceStage = PracticeVoiceStage.ready;
  SentenceType? _selectedType;
  SentencePracticeResult? _result;
  PracticeResultKind? _resultKind;
  String? _failureMessage;
  String? _spokenText;
  PracticeMicHint? _micHint;

  SavedWord? get word => _word;
  PracticeStep get step => _step;
  PracticeVoiceStage get voiceStage => _voiceStage;
  SentenceType? get selectedType => _selectedType;
  SentencePracticeResult? get result => _result;
  PracticeResultKind? get resultKind => _resultKind;

  /// [PracticeResultKind.failed] 일 때 보여 줄 수 있는 서버 메시지.
  String? get failureMessage => _failureMessage;

  /// 서버가 알아들은 아이의 문장. 결과 화면이 그대로 보여 줍니다.
  String? get spokenText => _spokenText;
  PracticeMicHint? get micHint => _micHint;

  /// 이 단어에서 고를 수 있는 예문들. 없는 종류는 빠집니다.
  List<PracticeSentence> get sentences {
    final SavedWord? word = _word;
    if (word == null) return const <PracticeSentence>[];
    return <PracticeSentence>[
      for (final SentenceType type in SentenceType.values)
        if ((word.sentenceOf(type) ?? '').trim().isNotEmpty)
          PracticeSentence(type: type, text: word.sentenceOf(type)!.trim()),
    ];
  }

  /// 지금 따라 말하는 문장.
  String? get targetSentence {
    final SentenceType? type = _selectedType;
    if (type == null) return null;
    return _word?.sentenceOf(type)?.trim();
  }

  /// 단어장 목록에서 extra 로 단어를 받으면 그대로 쓰고, 주소로 바로
  /// 들어온 경우에만 서버에서 다시 찾습니다.
  Future<void> load() => guard(() async {
    if (_word != null) return;
    final WordBook book = await _repository.getWordBook();
    for (final WordGroup group in book.groups) {
      for (final SavedWord word in group.words) {
        if (word.wordId == wordId) {
          _word = word;
          return;
        }
      }
    }
    throw const UnknownFailure('단어를 찾지 못했어요.');
  });

  void selectSentence(SentenceType type) {
    _selectedType = type;
    _step = PracticeStep.speak;
    _clearAttempt();
    safeNotify();
  }

  /// 예문 고르기로 돌아갑니다. 결과와 안내를 전부 지웁니다.
  void backToPick() {
    _selectedType = null;
    _step = PracticeStep.pick;
    _clearAttempt();
    safeNotify();
  }

  /// 같은 문장을 한 번 더. (`notMatched` 결과의 "다시 말하기")
  void speakAgain() {
    _step = PracticeStep.speak;
    _clearAttempt();
    safeNotify();
  }

  /// View 가 녹음기를 실제로 켠 다음에 부릅니다.
  void beginRecording() {
    if (_voiceStage != PracticeVoiceStage.ready) return;
    _voiceStage = PracticeVoiceStage.recording;
    _micHint = null;
    safeNotify();
  }

  /// 마이크 권한이 거절됐을 때. 화면을 에러로 바꾸지 않고 마이크 옆에
  /// 안내만 둡니다. (play 와 같은 처리)
  void micDenied() {
    _voiceStage = PracticeVoiceStage.ready;
    _micHint = PracticeMicHint.permission;
    safeNotify();
  }

  /// 녹음기를 켜다 실패했을 때.
  void micFailed() {
    _voiceStage = PracticeVoiceStage.ready;
    _micHint = PracticeMicHint.micFailed;
    safeNotify();
  }

  /// 녹음이 끝났습니다. 받아쓰기 -> 채점까지 이어서 갑니다.
  ///
  /// 받아쓰기 실패(무음, 짧은 소음, 일시적 서버 문제)는 흔한 일이라 화면을
  /// 통째로 에러로 바꾸지 않고 마이크 옆 안내로 되돌립니다. -> play_view
  Future<void> submitRecording(Uint8List? wavBytes) async {
    if (_voiceStage != PracticeVoiceStage.recording) return;
    if (wavBytes == null || wavBytes.isEmpty) {
      _voiceStage = PracticeVoiceStage.ready;
      _micHint = PracticeMicHint.notHeard;
      safeNotify();
      return;
    }
    _voiceStage = PracticeVoiceStage.transcribing;
    _micHint = null;
    safeNotify();

    final String text;
    try {
      text = (await _repository.transcribe(wavBytes)).trim();
    } on Object catch (error) {
      _voiceStage = PracticeVoiceStage.ready;
      _micHint = _hintOf(error);
      safeNotify();
      return;
    }
    if (text.isEmpty) {
      _voiceStage = PracticeVoiceStage.ready;
      _micHint = PracticeMicHint.notHeard;
      safeNotify();
      return;
    }
    _spokenText = text;
    await _submit(text);
  }

  /// 제출만 실패했을 때(네트워크 등) 다시 보냅니다. 이미 알아들은 문장을
  /// 다시 쓰므로 아이가 또 말할 필요가 없습니다.
  Future<void> resubmit() async {
    final String? text = _spokenText;
    if (text == null || _voiceStage == PracticeVoiceStage.submitting) return;
    await _submit(text);
  }

  Future<void> _submit(String spokenText) async {
    final SentenceType? type = _selectedType;
    if (type == null) return;
    _step = PracticeStep.speak;
    _voiceStage = PracticeVoiceStage.submitting;
    _result = null;
    _resultKind = null;
    _failureMessage = null;
    safeNotify();
    try {
      final SentencePracticeResult result = await _repository.practiceSentence(
        wordId: wordId,
        sentenceType: type,
        spokenText: spokenText,
      );
      _result = result;
      _resultKind = _kindOf(result);
    } on ServerFailure catch (failure) {
      if (failure.code == 'EXAMPLE_SENTENCE_MISSING') {
        _resultKind = PracticeResultKind.sentenceMissing;
      } else {
        _resultKind = PracticeResultKind.failed;
        _failureMessage = failure.message;
      }
    } on Failure catch (failure) {
      _resultKind = PracticeResultKind.failed;
      _failureMessage = failure.message;
    } on Object {
      _resultKind = PracticeResultKind.failed;
    }
    _step = PracticeStep.result;
    _voiceStage = PracticeVoiceStage.ready;
    safeNotify();
  }

  PracticeResultKind _kindOf(SentencePracticeResult result) {
    if (result.rewarded) return PracticeResultKind.rewarded;
    if (!result.matched) return PracticeResultKind.notMatched;
    return result.skipReason == SentencePracticeSkipReason.dailyLimit
        ? PracticeResultKind.dailyLimit
        : PracticeResultKind.alreadyRewarded;
  }

  /// 받아쓰기 실패를 마이크 옆 안내로 번역합니다. 코드 분기는 play 의
  /// `_voiceRetryHint` 와 같은 기준입니다.
  PracticeMicHint _hintOf(Object error) {
    if (error is ServerFailure) {
      return switch (error.code) {
        'AUDIO_TOO_LARGE' => PracticeMicHint.tooLong,
        'AI_RATE_LIMITED' ||
        'AI_UPSTREAM_ERROR' ||
        'AI_UNAVAILABLE' => PracticeMicHint.waitAndRetry,
        _ => PracticeMicHint.notHeard,
      };
    }
    if (error is NetworkFailure) return PracticeMicHint.waitAndRetry;
    return PracticeMicHint.notHeard;
  }

  void _clearAttempt() {
    _voiceStage = PracticeVoiceStage.ready;
    _result = null;
    _resultKind = null;
    _failureMessage = null;
    _spokenText = null;
    _micHint = null;
  }
}
