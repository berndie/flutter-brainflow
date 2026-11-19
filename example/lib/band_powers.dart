import 'package:flutter/material.dart';
import 'package:flutter_brainflow/flutter_brainflow.dart';

/// Relative EEG band powers (delta..gamma) as horizontal bars.
class BandPowerBars extends StatelessWidget {
  const BandPowerBars({super.key, required this.powers});

  /// Output of `DataFilter.getAvgBandPowers`, or null before enough data.
  final BandPowers? powers;

  static const _bands = ['δ 2–4', 'θ 4–8', 'α 8–13', 'β 13–30', 'γ 30–45'];

  @override
  Widget build(BuildContext context) {
    final avg = powers?.avg;
    final total = avg == null ? 0.0 : avg.fold(0.0, (a, b) => a + b);
    final text = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Band powers (relative, all channels)', style: text),
        const SizedBox(height: 4),
        for (final (i, label) in _bands.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(label, style: text)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: total > 0 ? avg![i] / total : 0,
                    minHeight: 8,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    total > 0 ? '${(100 * avg![i] / total).round()}%' : '–',
                    textAlign: TextAlign.end,
                    style: text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
