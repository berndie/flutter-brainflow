# Third-party notices

The MIT license in [`LICENSE`](LICENSE) covers the Dart code of
flutter_brainflow only. This package does not contain or redistribute any
BrainFlow or SimpleBLE binaries. At build time it downloads the unmodified,
official [BrainFlow](https://github.com/brainflow-dev/brainflow) release
archives (`compiled_libs.tar`, `brainflow-android.aar`) from BrainFlow's GitHub
releases and bundles libraries from them into your app:

- **BrainFlow** (`libBoardController`, `libDataHandler`, `libMLModule`, and the
  board helpers `libMuseLib`, `libGanglionLib`, `libBrainBitLib`,
  `libBrainFlowBluetooth`). MIT licensed, see below.
- **SimpleBLE** (`libsimpleble-c`, and on Android the Java bridge classes
  from `libs/simpleble-bridge.jar` in the AAR), as incorporated in BrainFlow.
  SimpleBLE is owned by The California Open Source Company LLC and is used by
  BrainFlow under license. BrainFlow's notice below lists the restrictions.
  flutter_brainflow cannot grant any rights to SimpleBLE. If you build or
  distribute an app with this package, make sure your use complies with that
  notice. Questions about it go to The California Open Source Company LLC
  (contact@simpleble.org).
- **ONNX Runtime** (`libonnxruntime_x64.so`, Linux only), as shipped in
  BrainFlow's release. MIT licensed, Copyright (c) Microsoft Corporation, see
  https://github.com/microsoft/onnxruntime/blob/main/LICENSE.

The vendored C headers in `third_party/brainflow/include/` are BrainFlow's,
under the license below (also in `third_party/brainflow/include/LICENSE`).

## BrainFlow license (verbatim)

```text
MIT License

Copyright (c) 2018 Andrey Parfenov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

IMPORTANT NOTICE: BrainFlow uses SimpleBLE, 
which is owned by The California Open Source Company LLC and used under license. 
As an End User of BrainFlow, you are prohibited from using, modifying, or 
distributing SimpleBLE, or any part thereof, except as incorporated in this 
Project. Specifically, you may not:

a) Extract, isolate, or separate SimpleBLE from BrainFlow; 
b) Modify, adapt or translate SimpleBLE; 
c) Distribute, sublicense, rent, lease, lend, or transfer SimpleBLE to any third party; 
d) Remove, obscure, or alter any copyright, trademark, or other proprietary rights 
notices contained within SimpleBLE.
Your use of this Application is subject to your compliance with these restrictions. 
If you have any questions about these terms, please contact 
The California Open Source Company LLC [contact@simpleble.org].

```
