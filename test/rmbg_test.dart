import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:rmbg/rmbg.dart';

void main() async {
  RMBG rmbg = RMBG(modelPath: 'assets/rmbg-1.4.onnx');
  rmbg.debug = true; // Toggle debug

  List<String> imagePaths = [
    r'c:\ali\dev\onnx\ImageSegmentation\OIP.jpeg',
    r'c:\ali\dev\python\onnx_playground\rmbg_test1\image1.jpg'
  ];

  final Completer<ui.Image> completer = Completer();

  ui.decodeImageFromList(File(imagePaths.first).readAsBytesSync(),
      (ui.Image img) {
    completer.complete(img);
  });

  ui.Image image = await completer.future;
  final output = await rmbg.run(image);
  Utils().saveOutputImage(output.foreground);
}
