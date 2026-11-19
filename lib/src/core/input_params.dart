import 'dart:convert';

import 'constants.g.dart';

/// Connection parameters for a board, mirroring BrainFlow's
/// `BrainFlowInputParams`.
///
/// Which fields are required depends on the board; see
/// <https://brainflow.readthedocs.io/en/stable/SupportedBoards.html>.
class BrainFlowInputParams {
  /// Creates input params; every field defaults to "not set".
  const BrainFlowInputParams({
    this.serialPort = '',
    this.macAddress = '',
    this.ipAddress = '',
    this.ipAddressAux = '',
    this.ipAddressAnc = '',
    this.ipPort = 0,
    this.ipPortAux = 0,
    this.ipPortAnc = 0,
    this.ipProtocol = IpProtocolTypes.noIpProtocol,
    this.otherInfo = '',
    this.timeout = 0,
    this.serialNumber = '',
    this.file = '',
    this.fileAux = '',
    this.fileAnc = '',
    this.masterBoard = BoardIds.noBoard,
  });

  /// Serial port, e.g. `/dev/ttyUSB0` or `COM3`.
  final String serialPort;

  /// MAC address of a Bluetooth device.
  final String macAddress;

  /// IP address (also used for multicast groups by the streaming board).
  final String ipAddress;

  /// IP address for the auxiliary preset.
  final String ipAddressAux;

  /// IP address for the ancillary preset.
  final String ipAddressAnc;

  /// IP port.
  final int ipPort;

  /// IP port for the auxiliary preset.
  final int ipPortAux;

  /// IP port for the ancillary preset.
  final int ipPortAnc;

  /// IP protocol.
  final IpProtocolTypes ipProtocol;

  /// Board-specific extra information.
  final String otherInfo;

  /// Timeout for device discovery or connection, in seconds (0: default).
  final int timeout;

  /// Serial number or device name, e.g. for BLE discovery.
  final String serialNumber;

  /// File to read, e.g. for `BoardIds.playbackFileBoard`.
  final String file;

  /// File for the auxiliary preset.
  final String fileAux;

  /// File for the ancillary preset.
  final String fileAnc;

  /// The board whose data format the streaming/playback board reproduces.
  final BoardIds masterBoard;

  /// The JSON object BrainFlow's C API expects.
  ///
  /// Always contains all fields: `prepare_session` rejects partial JSON.
  Map<String, Object> toJson() => {
    'serial_port': serialPort,
    'mac_address': macAddress,
    'ip_address': ipAddress,
    'ip_address_aux': ipAddressAux,
    'ip_address_anc': ipAddressAnc,
    'ip_port': ipPort,
    'ip_port_aux': ipPortAux,
    'ip_port_anc': ipPortAnc,
    'ip_protocol': ipProtocol.value,
    'other_info': otherInfo,
    'timeout': timeout,
    'serial_number': serialNumber,
    'file': file,
    'file_aux': fileAux,
    'file_anc': fileAnc,
    'master_board': masterBoard.value,
  };

  /// [toJson] encoded as a string.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is BrainFlowInputParams && other.toJsonString() == toJsonString();

  @override
  int get hashCode => toJsonString().hashCode;

  @override
  String toString() => 'BrainFlowInputParams(${toJsonString()})';
}
