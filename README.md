<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->
# RMBG
This is a simple flutter package that runs an onnx model to remove background from images.
it's still W.I.P (work in progress) so it's a bit finicky to use in projects because of the usage of both Image class from 'image' package and from dart:ui and converting between them (in short just a messy and bad code base)
I'll try to work on it and improve upon it and adding features that i need or deem needed.
All Contributions are welcome

## Features

As it name suggests it removes (rm) the background (bg) from images and returns both the foreground and the background images which you can both access and use.
I'll be making a function to generate a background blur when i figure out how to merge two images in pure dart if i can't i'll use a library, 'image' would be best (if it can, didnt check). But it'll be after reworking the package from the ground up probably (or not🤷‍♂️; can't choose).

## Getting started

You need the rmbg onnx models i think i'll provide them here.

## Usage
### Intialization (...ig?)
#### Import the package
```dart
// import the package (i mean that bit is obvious)
import 'package:rmbg/rmbg.dart';
```
#### Set an RMBG object
```dart
// initialize it with the model's asset path
final rmbg = RMBG('assets/path/to/model');
```
#### Removing the Background
```dart
// to run it nothing more simple than using the run method in an async function
final RMBGImage outputImage = await rmbg.run(image);
// NOTE: image passed should be of class Image from the dart:ui library.
// if you are using the Image class from the 'image' package you can find some methods i made to convert from one to another
```
#### Converting Images
```dart
// Convert dart ui's Image to "image"'s Image()
Utils().convertUIImageToImage(image);

// Convert "image"'s Image to dart ui's Image
Utils().convertImageToUIImage(image);
```
#### Saving Image
```dart
// saveOutput method in Utils will take care of it
Utils().saveOutput(outputImage.foreground)
// NOTE: You can't pass the full output of this method you should pass the foreground and background seperately
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
