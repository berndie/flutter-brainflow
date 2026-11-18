import 'package:brainflow_hook_spike/version.dart';
import 'package:ffi/ffi.dart';

String params({String mac = '', int timeout = 0}) =>
    '{"serial_port":"","mac_address":"$mac","ip_address":"",'
    '"ip_address_aux":"","ip_address_anc":"","ip_port":0,"ip_port_aux":0,'
    '"ip_port_anc":0,"ip_protocol":0,"other_info":"","timeout":$timeout,'
    '"serial_number":"","file":"","file_aux":"","file_anc":"",'
    '"master_board":-100}';

void main(List<String> args) {
  print('BrainFlow via @Native + hook: ${brainflowVersion()}');
  // Board ids taken from args: probe whether helper libs get dlopened.
  for (final id in args.map(int.parse)) {
    final p = params(timeout: 2).toNativeUtf8();
    final rc = prepareSession(id, p);
    print('prepare_session(board $id) -> $rc');
    if (rc == 0) releaseSession(id, p);
    malloc.free(p);
  }
}
