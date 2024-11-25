import 'dart:io';
import 'dart:ui' as ui;
import 'package:doddle/domain/models/stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../domain/models/draw_controller.dart';
import '../../../../domain/models/point.dart';

final canvasProvider =
    StateNotifierProvider<CanvasNotifier, DrawController>((ref) {
  return CanvasNotifier();
});

class CanvasNotifier extends StateNotifier<DrawController> {
  CanvasNotifier()
      : super(const DrawController(
          isPanActive: true,
          points: [],
          stamp: [],
          stampUndo: [],
          currentColor: Colors.white,
          isRandomColor: false,
          symmetryLines: 20,
          penTool: PenTool.glowPen,
          penSize: 2,
        ));

  void clearPoints() {
    state = state.copyWith(points: []);
  }

  void clearStamps() {
    if (state.stamp?.isEmpty ?? true) return;
    state = state.copyWith(stamp: []);
  }

  void addPoint(Point point, {bool end = false}) async {
    if (!state.isPanActive) return;

    List<Point?>? newPoints = [...state.points ?? [], point];
    state = state.copyWith(points: newPoints);

    if (end) {
      await takePageStamp(state.globalKey!);
    }
  }

  void undoStamp() {
    if (state.stamp?.isEmpty ?? true) return;

    final stamps = List<Stamp?>.from(state.stamp ?? []);
    final undoS = stamps.removeLast();

    final undoStamps = List<Stamp?>.from(state.stampUndo ?? [])..add(undoS);
    state = state.copyWith(stamp: stamps, stampUndo: undoStamps);
  }

  void redoStamp() {
    if (state.stampUndo?.isEmpty ?? true) return;

    final stampUndo = List<Stamp?>.from(state.stampUndo ?? []);
    final toRedo = stampUndo.removeLast();

    final stamps = List<Stamp?>.from(state.stamp ?? [])..add(toRedo);
    state = state.copyWith(stamp: stamps, stampUndo: stampUndo);
  }

  void changeColor(Color color, bool isRandomColor) {
    state = state.copyWith(
      currentColor: color,
      isRandomColor: isRandomColor,
    );
  }

  void changePenTool(PenTool penTool) {
    state = state.copyWith(penTool: penTool);
  }

  void changePenSize(double size) {
    state = state.copyWith(penSize: size);
  }

  void setGlobalKey(GlobalKey key) {
    state = state.copyWith(globalKey: key);
  }

  void updateSymmetryLines(double lines) {
    state = state.copyWith(symmetryLines: lines);
  }

  Future<void> takePageStamp(GlobalKey globalKey) async {
    try {
      ui.Image image = await canvasToImage(globalKey);
      final stamps = List<Stamp?>.from(state.stamp ?? [])
        ..add(Stamp(image: image));
      state = state.copyWith(stamp: stamps);
      clearPoints();
    } catch (e) {
      debugPrint('Error taking page stamp: $e');
    }
  }

  Future<ui.Image> canvasToImage(GlobalKey globalKey) async {
    final boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return await boundary.toImage();
  }

  Future<void> saveToGallery(GlobalKey globalKey) async {
    try {
      final boundary =
          globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "${DateTime.now().toIso8601String()}.jpeg",
        isReturnImagePathOfIOS: true,
      );
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
    }
  }

  Future<void> shareImage(GlobalKey globalKey, BuildContext context) async {
    try {
      final boundary =
          globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final directory = (await getExternalStorageDirectory())?.path;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final imgFile = File('$directory/screenshot.png');
      await imgFile.writeAsBytes(pngBytes);

      final box = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [XFile(imgFile.path)],
        subject: 'Doddle App',
        text: 'Hey, check out My Amazing Doddle!',
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }
}