import 'dart:typed_data';

/// A block of samples from a board: a `numRows x numSamples` matrix.
///
/// Rows are channels (which row holds what is described by `BoardShim`'s
/// channel getters or `BoardDescription`), columns are samples in time order.
/// Storage is row-major like BrainFlow's own buffers.
class BoardData {
  /// Wraps row-major [data] of length `numRows * numSamples`.
  BoardData(this.numRows, this.numSamples, this.data)
    : assert(numRows >= 0 && numSamples >= 0),
      assert(data.length == numRows * numSamples);

  /// No samples, [numRows] rows.
  BoardData.empty(this.numRows) : numSamples = 0, data = Float64List(0);

  /// Concatenates blocks with the same [numRows] along the sample axis.
  factory BoardData.concat(int numRows, Iterable<BoardData> blocks) {
    final list = blocks.toList();
    final total = list.fold(0, (n, b) => n + b.numSamples);
    final out = Float64List(numRows * total);
    var offset = 0;
    for (final b in list) {
      if (b.numRows != numRows) {
        throw ArgumentError('Row count mismatch: ${b.numRows} != $numRows');
      }
      for (var r = 0; r < numRows; r++) {
        out.setRange(
          r * total + offset,
          r * total + offset + b.numSamples,
          b.data,
          r * b.numSamples,
        );
      }
      offset += b.numSamples;
    }
    return BoardData(numRows, total, out);
  }

  /// Number of rows (channels, timestamps, markers, ...).
  final int numRows;

  /// Number of samples per row.
  final int numSamples;

  /// Row-major values: sample `s` of row `r` is `data[r * numSamples + s]`.
  final Float64List data;

  /// Whether there are no samples.
  bool get isEmpty => numSamples == 0;

  /// The samples of row [index], as a view into [data] (no copy).
  Float64List row(int index) {
    RangeError.checkValidIndex(index, null, 'index', numRows);
    return Float64List.sublistView(
      data,
      index * numSamples,
      (index + 1) * numSamples,
    );
  }

  /// The views of several rows, e.g. `data.rows(BoardShim.getEegChannels(id))`.
  List<Float64List> rows(Iterable<int> indices) => [
    for (final i in indices) row(i),
  ];

  /// Sample [sample] of row [row].
  double at(int row, int sample) {
    RangeError.checkValidIndex(row, null, 'row', numRows);
    RangeError.checkValidIndex(sample, null, 'sample', numSamples);
    return data[row * numSamples + sample];
  }

  @override
  String toString() => 'BoardData($numRows x $numSamples)';
}
