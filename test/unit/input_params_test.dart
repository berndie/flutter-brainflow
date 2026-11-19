import 'dart:convert';

import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults serialize all 16 fields like the Python binding', () {
    final json = const BrainFlowInputParams().toJson();
    expect(json, {
      'serial_port': '',
      'mac_address': '',
      'ip_address': '',
      'ip_address_aux': '',
      'ip_address_anc': '',
      'ip_port': 0,
      'ip_port_aux': 0,
      'ip_port_anc': 0,
      'ip_protocol': 0,
      'other_info': '',
      'timeout': 0,
      'serial_number': '',
      'file': '',
      'file_aux': '',
      'file_anc': '',
      'master_board': -100,
    });
  });

  test('enums are encoded as BrainFlow integers', () {
    const params = BrainFlowInputParams(
      ipProtocol: IpProtocolTypes.tcp,
      masterBoard: BoardIds.muse2Board,
      macAddress: '00:11:22:33:44:55',
      timeout: 15,
    );
    final decoded = jsonDecode(params.toJsonString()) as Map<String, Object?>;
    expect(decoded['ip_protocol'], 2);
    expect(decoded['master_board'], 38);
    expect(decoded['mac_address'], '00:11:22:33:44:55');
    expect(decoded['timeout'], 15);
  });

  test('value equality', () {
    expect(
      const BrainFlowInputParams(serialPort: 'a'),
      const BrainFlowInputParams(serialPort: 'a'),
    );
    expect(
      const BrainFlowInputParams(serialPort: 'a'),
      isNot(const BrainFlowInputParams(serialPort: 'b')),
    );
  });
}
