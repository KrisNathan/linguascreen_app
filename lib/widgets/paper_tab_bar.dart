import 'package:flutter/material.dart';
import 'package:lingua_screen/theme.dart';

/// Bottom tabs as words on paper. A highlighter stroke slides under the
/// current one.
class PaperTabBar extends StatelessWidget {
  const PaperTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final style = serif(fontSize: 19, fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String label) => (TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout()).width;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.paper,
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / labels.length;
              // A little wider than the word, like a real stroke.
              final mark = widthOf(labels[selectedIndex]) + 12;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: slot * selectedIndex + (slot - mark) / 2,
                    width: mark,
                    top: 33,
                    height: 12,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.highlighter,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, label) in labels.indexed)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == selectedIndex,
                            child: InkResponse(
                              onTap: () => onSelected(i),
                              highlightShape: BoxShape.rectangle,
                              containedInkWell: true,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: style.copyWith(
                                    color: i == selectedIndex
                                        ? Palette.ink
                                        : Palette.inkSoft,
                                  ),
                                  child: Text(label),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
