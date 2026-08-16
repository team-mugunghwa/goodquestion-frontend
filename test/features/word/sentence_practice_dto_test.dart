import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/word/data/dtos/sentence_practice_dto.dart';
import 'package:goodquestion/features/word/data/dtos/word_response_dto.dart';
import 'package:goodquestion/features/word/domain/entities/saved_word.dart';
import 'package:goodquestion/features/word/domain/entities/sentence_practice.dart';

void main() {
  group('WordResponseDto', () {
    test('서버 WordResponse 가 SavedWord 로 올라온다', () {
      final SavedWord word = WordResponseDto.fromJson(<String, dynamic>{
        'id': 'w-1',
        'word': '며느리',
        'meaning': '아들과 결혼한 사람이에요.',
        'exampleSentence': '이야기 예문',
        'exampleSentenceDaily': '일상 예문',
        'exampleSentenceAdvanced': '심화 예문',
        'entryType': 'FAVORITE',
        'sourceSceneId': null,
        'storyId': 's-11',
        'storyTitle': '방귀 뀌는 며느리',
        'storyImageUrl': null,
        'createdAt': '2026-08-08T11:20:00Z',
      }).toEntity();

      expect(word.wordId, 'w-1');
      expect(word.word, '며느리');
      expect(word.liked, isTrue, reason: 'FAVORITE 이 좋아요로 번역돼야 합니다');
      expect(word.sentenceOf(SentenceType.story), '이야기 예문');
      expect(word.sentenceOf(SentenceType.daily), '일상 예문');
      expect(word.sentenceOf(SentenceType.advanced), '심화 예문');
      expect(word.storyId, 's-11');
      expect(word.storyTitle, '방귀 뀌는 며느리');
      expect(word.savedAt, isNotNull);
      expect(word.hasPracticeSentence, isTrue);
    });

    test('예문 확장 전 단어 - 일상/심화가 null 이어도 죽지 않는다', () {
      final SavedWord word = WordResponseDto.fromJson(<String, dynamic>{
        'id': 'w-2',
        'word': '참다',
        'meaning': null,
        'exampleSentence': null,
        'entryType': 'UNKNOWN',
        'storyId': null,
        'createdAt': null,
      }).toEntity();

      expect(word.liked, isFalse);
      expect(word.meaning, isNull);
      expect(word.hasPracticeSentence, isFalse);
    });
  });

  group('SentencePracticeResultDto', () {
    test('보상 응답이 그대로 올라온다', () {
      final SentencePracticeResult result =
          SentencePracticeResultDto.fromJson(<String, dynamic>{
            'matched': true,
            'similarity': 0.95,
            'targetSentence': '옛날에 며느리가 살았어요.',
            'rewarded': true,
            'skipReason': null,
            'stardustAmount': 2,
            'stardustBalance': 12,
          }).toEntity();

      expect(result.matched, isTrue);
      expect(result.rewarded, isTrue);
      expect(result.similarity, 0.95);
      expect(result.similarityPercent, 95);
      expect(result.skipReason, isNull);
      expect(result.stardustAmount, 2);
      expect(result.stardustBalance, 12);
    });

    test('skipReason 문자열이 enum 으로 번역된다', () {
      SentencePracticeResult of(String? reason) =>
          SentencePracticeResultDto.fromJson(<String, dynamic>{
            'matched': true,
            'similarity': 1,
            'targetSentence': '문장',
            'rewarded': false,
            'skipReason': reason,
            'stardustAmount': 0,
            'stardustBalance': 10,
          }).toEntity();

      expect(
        of('ALREADY_REWARDED').skipReason,
        SentencePracticeSkipReason.alreadyRewarded,
      );
      expect(
        of('DAILY_LIMIT').skipReason,
        SentencePracticeSkipReason.dailyLimit,
      );
      // 모르는 값이 와도 화면이 죽지 않아야 합니다.
      expect(of('SOMETHING_NEW').skipReason, isNull);
    });
  });
}
