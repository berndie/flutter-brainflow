import 'package:brainflow_hook_spike/version.dart';
import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(
    home: Scaffold(body: Center(child: Text('BrainFlow ${brainflowVersion()}')))));
