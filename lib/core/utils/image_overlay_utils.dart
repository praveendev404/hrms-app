import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';

/// Utility class for adding GPS overlays to images
class ImageOverlayUtils {
  /// Add GPS watermark overlay to an image
  static Future<File> addGPSOverlay({
    required File imageFile,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    // Load the original image
    final originalImage = await _loadImage(imageFile);
    
    // Get address from live location using reverse geocoding
    String address = 'Location unavailable';
    String city = 'Unknown';
    String state = 'Unknown';
    String country = 'Unknown';
    
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        address = [placemark.street, placemark.subLocality, placemark.locality]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
        if (address.isEmpty) address = 'Location unavailable';
        city = placemark.locality ?? 'Unknown';
        state = placemark.administrativeArea ?? 'Unknown';
        country = placemark.country ?? 'Unknown';
      }
    } catch (e) {
      // If reverse geocoding fails, use default values
      print('Reverse geocoding failed: $e');
    }
    
    // Create a canvas to draw the overlay
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw original image
    canvas.drawImage(originalImage, Offset.zero, Paint());
    
    // Create overlay
    await _drawOverlay(
      canvas: canvas,
      width: originalImage.width.toDouble(),
      height: originalImage.height.toDouble(),
      latitude: latitude,
      longitude: longitude,
      address: address,
      city: city,
      state: state,
      country: country,
      timestamp: timestamp,
    );
    
    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
    
    // Convert to byte data as PNG first
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    
    // Save PNG temporarily
    final tempDir = await getTemporaryDirectory();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final tempPngFile = File('${tempDir.path}/temp_overlay_$timestampMs.png');
    await tempPngFile.writeAsBytes(pngBytes);
    
    // Compress to JPEG with quality 70 to reduce file size
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      tempPngFile.path,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    
    // Delete temporary PNG file
    await tempPngFile.delete();
    
    // Save compressed JPEG
    final outputFile = File('${tempDir.path}/gps_overlay_$timestampMs.jpg');
    await outputFile.writeAsBytes(compressedBytes!);
    
    return outputFile;
  }

  /// Load image from file
  static Future<ui.Image> _loadImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Draw GPS overlay on canvas
  static Future<void> _drawOverlay({
    required Canvas canvas,
    required double width,
    required double height,
    required double latitude,
    required double longitude,
    required String address,
    required String city,
    required String state,
    required String country,
    required DateTime timestamp,
  }) async {
    // Define overlay dimensions - larger to accommodate content
    final overlayHeight = height * 0.28; // 28% of image height
    final overlayY = height - overlayHeight;
    
    // Draw semi-transparent dark background
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.80)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(0, overlayY, width, overlayHeight),
      backgroundPaint,
    );
    
    // Calculate responsive font sizes
    final titleFontSize = width * 0.030;
    final locationFontSize = width * 0.038;
    final addressFontSize = width * 0.026;
    final detailsFontSize = width * 0.024;
    final noteFontSize = width * 0.022;
    
    final padding = width * 0.03;
    final thumbnailSize = overlayHeight * 0.55;
    final contentStartX = padding + thumbnailSize + padding;
    final contentWidth = width - contentStartX - padding;
    
    // Draw map thumbnail (left side)
    final thumbnailPaint = Paint()
      ..color = Colors.green.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding,
          overlayY + padding,
          thumbnailSize,
          thumbnailSize,
        ),
        const Radius.circular(8),
      ),
      thumbnailPaint,
    );
    
    // Draw location pin icon in thumbnail
    _drawText(
      canvas: canvas,
      text: '📍',
      x: padding + (thumbnailSize / 2) - (thumbnailSize * 0.15),
      y: overlayY + padding + (thumbnailSize / 2) - (thumbnailSize * 0.15),
      fontSize: thumbnailSize * 0.4,
      color: Colors.white,
    );
    
    // Start drawing text content on the right side
    double currentY = overlayY + padding;
    
    // Draw GPS Map Camera header
    _drawText(
      canvas: canvas,
      text: '📍 GPS Map Camera',
      x: contentStartX,
      y: currentY,
      fontSize: titleFontSize,
      color: Colors.white70,
      fontWeight: FontWeight.w500,
    );
    
    currentY += titleFontSize + (padding * 0.5);
    
    // Draw location name with flag
    final locationText = '$city,$state,$country 🇮🇳';
    _drawText(
      canvas: canvas,
      text: locationText,
      x: contentStartX,
      y: currentY,
      fontSize: locationFontSize,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
    
    currentY += locationFontSize + (padding * 0.4);
    
    // Draw full address (with wrapping)
    _drawText(
      canvas: canvas,
      text: address.length > 60 ? '${address.substring(0, 60)}...' : address,
      x: contentStartX,
      y: currentY,
      fontSize: addressFontSize,
      color: Colors.white,
      fontWeight: FontWeight.w400,
      maxWidth: contentWidth,
    );
    
    currentY += addressFontSize + (padding * 0.4);
    
    // Draw coordinates
    final coordsText =
        'Lat ${latitude.toStringAsFixed(6)}, Long ${longitude.toStringAsFixed(6)}';
    _drawText(
      canvas: canvas,
      text: coordsText,
      x: contentStartX,
      y: currentY,
      fontSize: detailsFontSize,
      color: Colors.white,
      fontWeight: FontWeight.w400,
    );
    
    currentY += detailsFontSize + (padding * 0.35);
    
    // Draw timestamp
    final formattedDate = DateFormat('EEEE, dd/MM/yyyy hh:mm a \'GMT\'Z').format(timestamp);
    _drawText(
      canvas: canvas,
      text: formattedDate,
      x: contentStartX,
      y: currentY,
      fontSize: detailsFontSize,
      color: Colors.white,
      fontWeight: FontWeight.w400,
    );
    
    currentY += detailsFontSize + (padding * 0.3);
    
    // Draw note
    _drawText(
      canvas: canvas,
      text: 'Note : Captured by GPS Map Camera',
      x: contentStartX,
      y: currentY,
      fontSize: noteFontSize,
      color: Colors.white70,
      fontWeight: FontWeight.w400,
    );
  }

  /// Draw text on canvas
  static void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double? maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: maxWidth != null ? 2 : 1,
      ellipsis: maxWidth != null ? '...' : null,
    );
    
    if (maxWidth != null) {
      textPainter.layout(maxWidth: maxWidth);
    } else {
      textPainter.layout();
    }
    
    textPainter.paint(canvas, Offset(x, y));
  }
}
