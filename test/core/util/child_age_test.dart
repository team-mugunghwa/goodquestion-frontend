import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/util/child_age.dart';

/// 아이 등록과 계정 찾기가 **같은 식**으로 나이↔출생연도를 오가야 합니다.
/// 한쪽만 달라지면 같은 아이인데도 연도가 어긋나 계정을 못 찾습니다.
void main() {
  final DateTime now = DateTime(2026, 8, 19);

  test('지금 나이에서 출생연도를 구한다', () {
    expect(birthYearFromAge(8, now: now), 2018);
    expect(birthYearFromAge(7, now: now), 2019);
  });

  test('출생연도에서 지금 나이를 구한다 - 서로 역이다', () {
    expect(ageFromBirthYear(2018, now: now), 8);
    expect(ageFromBirthYear(birthYearFromAge(10, now: now), now: now), 10);
  });

  test('해가 바뀌면 같은 아이의 나이가 한 살 오른다', () {
    // 그래서 화면이 "가입할 때 고른 나이"가 아니라 **지금 나이**를 물어야
    // 합니다. 2025년에 7세로 등록한 아이는 2026년에 8세로 물어야 2018이
    // 나옵니다.
    final int birthYear = birthYearFromAge(7, now: DateTime(2025, 8, 19));
    expect(birthYear, 2018);
    expect(birthYearFromAge(8, now: now), birthYear);
  });
}
