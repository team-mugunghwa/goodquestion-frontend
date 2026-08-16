import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../theme/app_spacing.dart';
import 'app_state_views.dart';

/// 약관·정책 문서 시트 본문.
///
/// 문서 원본은 `assets/policies/*.md` 마크다운 파일이고, 이 위젯이 헤더와
/// 표만 골라 꾸며서 보여줍니다. 마크다운 패키지를 들이지 않는 이유는 문서
/// 3개에 필요한 문법이 헤더/표/번호 목록뿐이라 의존성 값을 못 하기
/// 때문입니다.
class PolicyDocumentView extends StatelessWidget {
  const PolicyDocumentView({
    super.key,
    required this.title,
    required this.assetPath,
    this.bundle,
  });

  final String title;
  final String assetPath;

  /// 테스트에서 가짜 번들을 꽂는 자리. `null` 이면 [rootBundle].
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: (bundle ?? rootBundle).loadString(assetPath),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('문서를 불러오지 못했어요.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: AppLoadingView());
        }
        return _DocumentBody(title: title, source: snapshot.data!);
      },
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({required this.title, required this.source});

  final String title;
  final String source;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Widget> children = <Widget>[];
    final List<String> lines = source.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trimRight();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('# ')) {
        // 시트 상단에 제목이 이미 있으므로 문서의 대제목은 건너뜁니다.
        continue;
      }
      if (line.startsWith('## ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(line.substring(3), style: text.titleMedium),
          ),
        );
        continue;
      }
      if (line.startsWith('|')) {
        // 표 블록을 통째로 소비합니다.
        final List<String> rows = <String>[];
        while (i < lines.length && lines[i].trimRight().startsWith('|')) {
          rows.add(lines[i].trimRight());
          i++;
        }
        i--;
        children.add(_table(context, rows));
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(line, style: text.bodyMedium?.copyWith(height: 1.6)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(title, style: text.titleLarge),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _table(BuildContext context, List<String> rows) {
    final TextTheme text = Theme.of(context).textTheme;
    List<String> cells(String row) => row
        .split('|')
        .map((String c) => c.trim())
        .where((String c) => c.isNotEmpty)
        .toList();

    final List<TableRow> tableRows = <TableRow>[];
    for (int r = 0; r < rows.length; r++) {
      final List<String> c = cells(rows[r]);
      if (c.every((String v) => RegExp(r'^:?-+:?$').hasMatch(v))) {
        continue; // 구분선 행
      }
      final bool header = r == 0;
      tableRows.add(
        TableRow(
          children: c
              .map(
                (String v) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    v,
                    style: header
                        ? text.bodySmall?.copyWith(fontWeight: FontWeight.w700)
                        : text.bodySmall?.copyWith(height: 1.5),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    if (tableRows.isEmpty) {
      return const SizedBox.shrink();
    }
    // 행마다 칸 수가 다르면 Table 이 던지므로 최대 칸 수에 맞춰 채웁니다.
    final int columns = tableRows
        .map((TableRow r) => r.children.length)
        .reduce((int a, int b) => a > b ? a : b);
    final List<TableRow> padded = tableRows
        .map(
          (TableRow r) => TableRow(
            children: <Widget>[
              ...r.children,
              for (int k = r.children.length; k < columns; k++)
                const SizedBox.shrink(),
            ],
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Table(
        border: TableBorder.all(
          color: Theme.of(context).dividerColor,
          width: .6,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: padded,
      ),
    );
  }
}
