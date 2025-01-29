import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

class RMBG {
  final String modelPath;
  bool debug = false;
  Utils utils = Utils();

  RMBG({
    required this.modelPath,
  });

  Future<ui.Image> _applyMask(List maskData, ui.Image image,
      {double threshold = .5, bool hard = true}) async {
    final mask = Uint8List(1024 * 1024);

    // Apply threshold to differentiate background and foreground
    for (int i = 0; i < 1024 * 1024; i++) {
      double maskValue = maskData[0][0][i ~/ 1024][i % 1024];
      if (maskValue >= threshold) {
        mask[i] = 255; // Foreground
      } else {
        mask[i] = 0; // Background
      }

      // Apply soft or hard mask based on 'hard' argument
      if (!hard) {
        mask[i] = (mask[i] * (1 - (maskValue - threshold).abs() / threshold))
            .clamp(0, 255)
            .toInt();
      }
    }

    final imageAsFloatBytes =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final rgbaUnits = Uint8List.view(imageAsFloatBytes.buffer);

    for (int i = 0; i < 1024 * 1024; i++) {
      rgbaUnits[i * 4 + 3] = mask[i]; // Set the alpha channel with the mask
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgbaUnits, 1024, 1024, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  Future<ui.Image> _applyBGMask(List maskData, ui.Image image) async {
    final mask = Uint8List(1024 * 1024);
    for (int i = 0; i < 1024 * 1024; i++) {
      mask[i] = (255 -
              (maskData[0][0][i ~/ 1024][i % 1024] * 255).toInt().clamp(0, 255))
          .toInt();
    }

    final imageAsFloatBytes =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final rgbaUnits = Uint8List.view(imageAsFloatBytes.buffer);

    for (int i = 0; i < 1024 * 1024; i++) {
      rgbaUnits[i * 4 + 3] = mask[i];
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgbaUnits, 1024, 1024, ui.PixelFormat.rgba8888,
        (ui.Image uiImage) async {
      completer.complete(uiImage);
    });

    return completer.future;
  }

  Future<RMBGImage> run(ui.Image inputImage) async {
    // check height and width
    if (inputImage.width != 1024 || inputImage.height != 1024) {
      // resize it to fit the model
      inputImage = await utils.resizeImage(inputImage, 1024, 1024);
    }

    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final rawAssetFile = await rootBundle.load("assets/models/rmbg-1.4.onnx");
    final bytes = rawAssetFile.buffer.asUint8List();
    final session = OrtSession.fromBuffer(bytes, sessionOptions);

    final runOptions = OrtRunOptions();
    final rgbFloats = await utils.imageToFloatTensor(inputImage);
    final inputOrt = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(rgbFloats), [1, 3, 1024, 1024]);
    final input = {"input": inputOrt};
    final output = session.run(runOptions, input, ["output"]);

    inputOrt.release();
    runOptions.release();
    sessionOptions.release();
    OrtEnv.instance.release();

    List outputMask = output.first?.value as List;
    final image = await _applyMask(outputMask, inputImage, threshold: .1);
    final bgImage = await _applyBGMask(outputMask, inputImage);
    // blur the background image
    final convImage = await utils.convertUiImageToImage(bgImage);
    final bluredImage = img.gaussianBlur(convImage, radius: 10);
    final uiBluredImage = await utils.convertImageToUiImage(bluredImage);

    return RMBGImage(foreground: image, background: uiBluredImage);
  }
}

class RMBGImage {
  final ui.Image foreground;
  final ui.Image background;

  RMBGImage({
    required this.foreground,
    required this.background,
  });
}

class Utils {
  Future<img.Image> convertUiImageToImage(ui.Image uiImage) async {
    final ByteData? byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null)
      throw Exception("Failed to get byte data from image.");

    Uint8List rgbaBytes = byteData.buffer.asUint8List();
    return img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: rgbaBytes.buffer,
      numChannels: 4, // RGBA
    );
  }

  Future<ui.Image> resizeImage(ui.Image image, int width, int height) async {
    final convImage = await convertUiImageToImage(image);
    return convertImageToUiImage(
      img.copyResize(convImage, width: width, height: height),
    );
  }

  Future<ui.Image> convertImageToUiImage(img.Image image) async {
    final Uint8List pngBytes = Uint8List.fromList(img.encodePng(image));
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(pngBytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  Future<void> saveOutputImage(ui.Image outputImage) async {
    final byteData =
        await outputImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return;

    final file = File('$directoryPath/output_image.png');
    await file.writeAsBytes(pngBytes);
  }

  Future<List<double>> imageToFloatTensor(ui.Image image) async {
    final imageAsFloatBytes =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final rgbaUnits = Uint8List.view(imageAsFloatBytes.buffer);

    final indexed = rgbaUnits.indexed;
    return [
      ...indexed.where((e) => e.$1 % 4 == 0).map((e) => e.$2 / 255.0),
      ...indexed.where((e) => e.$1 % 4 == 1).map((e) => e.$2 / 255.0),
      ...indexed.where((e) => e.$1 % 4 == 2).map((e) => e.$2 / 255.0),
    ];
  }
}
