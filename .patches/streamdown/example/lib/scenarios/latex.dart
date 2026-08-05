import 'package:flutter/material.dart';
import 'package:streamdown/streamdown.dart';

/// Scenario 6 — LaTeX math rendering via the `latex: true` flag.
class LatexScreen extends StatelessWidget {
  const LatexScreen({super.key});

  static const _md = r'''
# LaTeX showcase

Inline math is wrapped in single dollar signs: $E = mc^2$. The Pythagorean
theorem states $a^2 + b^2 = c^2$ for a right triangle.

Block math uses double dollar signs:

$$\int_{0}^{\infty} e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}$$

Or a matrix:

$$\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}$$

When `latex: false` (the default), dollar amounts like $10 and $20 are
preserved as literal text — no false math triggers.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6. LaTeX math')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Streamdown.text(_md, latex: true),
      ),
    );
  }
}
