import 'package:flutter/foundation.dart';
import 'package:flutter_brainflow/flutter_brainflow.dart';

/// Fixed-size rolling window of the last [capacity] samples per channel.
class SignalBuffer extends ChangeNotifier {
  SignalBuffer(int channels, this.capacity)
    : _data = List.generate(channels, (_) => Float64List(capacity));

  final int capacity;
  final List<Float64List> _data;
  int _start = 0; // index of the oldest sample
  int _length = 0;

  int get channels => _data.length;
  int get length => _length;

  /// Appends one block; [rows] are the new samples per channel.
  void addAll(List<Float64List> rows) {
    assert(rows.length == channels);
    final n = rows.isEmpty ? 0 : rows.first.length;
    for (var s = 0; s < n; s++) {
      final i = (_start + _length) % capacity;
      for (var c = 0; c < channels; c++) {
        _data[c][i] = rows[c][s];
      }
      if (_length < capacity) {
        _length++;
      } else {
        _start = (_start + 1) % capacity;
      }
    }
    if (n > 0) notifyListeners();
  }

  /// Sample [index] (0 = oldest) of [channel].
  double at(int channel, int index) =>
      _data[channel][(_start + index) % capacity];

  /// The window as a `channels x length` matrix, oldest sample first.
  BoardData toBoardData() {
    final out = Float64List(channels * _length);
    for (var c = 0; c < channels; c++) {
      for (var i = 0; i < _length; i++) {
        out[c * _length + i] = at(c, i);
      }
    }
    return BoardData(channels, _length, out);
  }

  void clear() {
    _start = 0;
    _length = 0;
    notifyListeners();
  }
}
