import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Widget that renders text with inline LaTeX math expressions
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MathText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? const TextStyle(fontSize: 16);
    
    // Split text by LaTeX delimiters: $...$ for inline, $$...$$ for display
    final parts = _parseLatex(text);
    
    // Group parts into lines - display math should be on its own line
    final List<Widget> widgets = [];
    List<Widget> currentLine = [];
    
    for (var part in parts) {
      if (part.isLatex && part.isDisplay) {
        // Flush current line if any
        if (currentLine.isNotEmpty) {
          widgets.add(
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: currentLine,
            ),
          );
          currentLine = [];
        }
        // Add display math on its own line with horizontal scrolling
        widgets.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildMath(part.content, true),
          ),
        );
      } else if (part.isLatex) {
        // Inline math - can overflow to next line
        currentLine.add(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildMath(part.content, false),
            ),
          ),
        );
      } else {
        // Regular text - split by newlines and wrap properly
        final lines = part.content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            currentLine.add(
              Text(
                lines[i],
                style: defaultStyle,
                softWrap: true,
              ),
            );
          }
          // Add line break widget if not the last line
          if (i < lines.length - 1) {
            if (currentLine.isNotEmpty) {
              widgets.add(
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: currentLine,
                ),
              );
              currentLine = [];
            }
          }
        }
      }
    }
    
    // Flush remaining line
    if (currentLine.isNotEmpty) {
      widgets.add(
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: currentLine,
        ),
      );
    }
    
    // Add spacing between children for better readability
    final spacedWidgets = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      spacedWidgets.add(widgets[i]);
      // Add spacing between elements, except after the last one
      if (i < widgets.length - 1) {
        spacedWidgets.add(const SizedBox(height: 8));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: spacedWidgets,
    );
  }

  Widget _buildMath(String latex, bool isDisplay) {
    try {
      return Math.tex(
        latex,
        textStyle: style,
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
        textScaleFactor: 1.2,
      );
    } catch (e) {
      // If LaTeX parsing fails, show the raw text
      return Text(
        '\$$latex\$',
        style: style?.copyWith(color: Colors.red.shade300),
      );
    }
  }

  List<_TextPart> _parseLatex(String input) {
    final parts = <_TextPart>[];
    int i = 0;
    StringBuffer currentText = StringBuffer();

    while (i < input.length) {
      // Check for display math $$...$$
      if (i < input.length - 1 && input[i] == '\$' && input[i + 1] == '\$') {
        if (currentText.isNotEmpty) {
          parts.add(_TextPart(currentText.toString(), false, false));
          currentText.clear();
        }
        i += 2;
        final start = i;
        while (i < input.length - 1) {
          if (input[i] == '\$' && input[i + 1] == '\$') {
            parts.add(_TextPart(input.substring(start, i), true, true));
            i += 2;
            break;
          }
          i++;
        }
      }
      // Check for inline math $...$
      else if (input[i] == '\$') {
        if (currentText.isNotEmpty) {
          parts.add(_TextPart(currentText.toString(), false, false));
          currentText.clear();
        }
        i++;
        final start = i;
        while (i < input.length) {
          if (input[i] == '\$') {
            parts.add(_TextPart(input.substring(start, i), true, false));
            i++;
            break;
          }
          i++;
        }
      }
      // Also support \[ \] for display math and \( \) for inline
      else if (i < input.length - 1 && input[i] == '\\' && input[i + 1] == '[') {
        if (currentText.isNotEmpty) {
          parts.add(_TextPart(currentText.toString(), false, false));
          currentText.clear();
        }
        i += 2;
        final start = i;
        while (i < input.length - 1) {
          if (input[i] == '\\' && input[i + 1] == ']') {
            parts.add(_TextPart(input.substring(start, i), true, true));
            i += 2;
            break;
          }
          i++;
        }
      }
      else if (i < input.length - 1 && input[i] == '\\' && input[i + 1] == '(') {
        if (currentText.isNotEmpty) {
          parts.add(_TextPart(currentText.toString(), false, false));
          currentText.clear();
        }
        i += 2;
        final start = i;
        while (i < input.length - 1) {
          if (input[i] == '\\' && input[i + 1] == ')') {
            parts.add(_TextPart(input.substring(start, i), true, false));
            i += 2;
            break;
          }
          i++;
        }
      }
      else {
        currentText.write(input[i]);
        i++;
      }
    }

    if (currentText.isNotEmpty) {
      parts.add(_TextPart(currentText.toString(), false, false));
    }

    return parts;
  }
}

class _TextPart {
  final String content;
  final bool isLatex;
  final bool isDisplay;

  _TextPart(this.content, this.isLatex, this.isDisplay);
}
