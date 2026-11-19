import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

// Verbatim from get_board_descr(MUSE_2_BOARD, DEFAULT_PRESET), BrainFlow 5.23.
const _muse2 =
    '{"eeg_channels":[1,2,3,4],"eeg_names":"TP9,AF7,AF8,TP10",'
    '"marker_channel":7,"name":"Muse2","num_rows":8,"other_channels":[5],'
    '"package_num_channel":0,"sampling_rate":256,"timestamp_channel":6}';

void main() {
  test('parses a real description', () {
    final d = BoardDescription.parse(_muse2);
    expect(d.name, 'Muse2');
    expect(d.samplingRate, 256);
    expect(d.numRows, 8);
    expect(d.eegChannels, [1, 2, 3, 4]);
    expect(d.eegNames, ['TP9', 'AF7', 'AF8', 'TP10']);
    expect(d.otherChannels, [5]);
    expect(d.timestampChannel, 6);
    expect(d.markerChannel, 7);
    expect(d.packageNumChannel, 0);
  });

  test('missing channel kinds are empty or null', () {
    final d = BoardDescription.parse('{"name":"PlayBack"}');
    expect(d.accelChannels, isEmpty);
    expect(d.eegNames, isEmpty);
    expect(d.batteryChannel, isNull);
    expect(d.samplingRate, isNull);
  });

  test('keeps unknown keys in raw', () {
    final d = BoardDescription.parse('{"name":"X","future_key":[1]}');
    expect(d.raw['future_key'], [1]);
  });
}
