import 'dart:io';

import 'package:image/image.dart' as img;

String _readPrimary600HexFromAppColors() {
  final appColorsPath = File('lib/theme/app_colors.dart');
  if (!appColorsPath.existsSync()) {
    throw Exception('Missing lib/theme/app_colors.dart');
  }

  final contents = appColorsPath.readAsStringSync();
  final match = RegExp(r'primary600\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)')
      .firstMatch(contents);
  if (match == null) {
    throw Exception('Could not find AppColors.primary600 in app_colors.dart');
  }
  return match.group(1)!; // AARRGGBB
}

void main(List<String> args) {
  final inputPath =
      args.isNotEmpty ? args[0] : 'assets/icons/privacy-pulse-icon.png';
  final outputPath = args.length >= 2
      ? args[1]
      : 'assets/icons/privacy-pulse-icon-colored.png';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    throw Exception('Input PNG not found: $inputPath');
  }

  final primaryHex = _readPrimary600HexFromAppColors();
  final aa = int.parse(primaryHex.substring(0, 2), radix: 16);
  final rr = int.parse(primaryHex.substring(2, 4), radix: 16);
  final gg = int.parse(primaryHex.substring(4, 6), radix: 16);
  final bb = int.parse(primaryHex.substring(6, 8), radix: 16);

  // Decode
  final bytes = inputFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not decode PNG: $inputPath');
  }

  // Convert grayscale -> tinted RGBA.
  // The SVG we have embeds a grayscale PNG (no alpha). In practice this is
  // usually a dark logo on a light/white background.
  //
  // We invert luminance to build an alpha mask:
  // - dark pixels => opaque logo
  // - light pixels => transparent background
  final out =
      img.Image(width: decoded.width, height: decoded.height, numChannels: 4);
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final p = decoded.getPixel(x, y);
      // Using luminance from red channel is fine for grayscale inputs.
      final luminance = p.r.toInt();
      // Invert luminance to get alpha, scaled by theme alpha.
      final inv = 255 - luminance;
      final a = (inv * aa / 255).round().clamp(0, 255);
      out.setPixelRgba(x, y, rr, gg, bb, a);
    }
  }

  // Ensure output directory exists
  File(outputPath).parent.createSync(recursive: true);
  File(outputPath).writeAsBytesSync(img.encodePng(out));

  stdout.writeln('Wrote $outputPath (tinted with primary600: 0x$primaryHex)');
}
