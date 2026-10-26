import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_signature/app_strings.dart';
import 'package:simple_signature/banner_ad_widget.dart';
import 'package:simple_signature/signature_storage.dart';

typedef SaveSignatureFile = Future<String> Function({
  required String fileName,
  required Uint8List bytes,
});

typedef ShareSignatureFile = Future<void> Function(File file, String text);

enum SaveResult { saved, cancelled, failed }

Future<String> _saveWithFileSaver({
  required String fileName,
  required Uint8List bytes,
}) {
  return FlutterFileSaver().writeFileAsBytes(fileName: fileName, bytes: bytes);
}

Future<void> _shareWithSharePlus(File file, String text) async {
  await SharePlus.instance.share(
    ShareParams(
      previewThumbnail: XFile(file.path),
      files: [XFile(file.path)],
      text: text,
    ),
  );
}

/// Saves [bytes] through [saveFile] and maps the outcome, treating the user
/// dismissing the system "save as" dialog as a cancellation.
Future<SaveResult> saveSignature(
  Uint8List bytes, {
  SaveSignatureFile saveFile = _saveWithFileSaver,
  DateTime? now,
}) async {
  try {
    await saveFile(fileName: signatureFileName(now), bytes: bytes);
    return SaveResult.saved;
  } on PlatformException catch (e) {
    return e.code == 'CANCELLED' ? SaveResult.cancelled : SaveResult.failed;
  } catch (_) {
    return SaveResult.failed;
  }
}

String saveResultMessage(SaveResult result, AppStrings strings) {
  switch (result) {
    case SaveResult.saved:
      return strings.saved;
    case SaveResult.cancelled:
      return strings.saveCancelled;
    case SaveResult.failed:
      return strings.saveFailed;
  }
}

class ResultSignature extends StatefulWidget {
  /// The signature on a transparent background.
  final Uint8List image;

  /// The same signature on a white background, for apps that show
  /// transparency as black.
  final Uint8List whiteImage;

  /// Overridable for tests; defaults to the system "save as" dialog.
  final SaveSignatureFile saveFile;

  /// Overridable for tests; defaults to the system share sheet.
  final ShareSignatureFile shareFile;

  /// Overridable for tests; defaults to the app's signature cache folder.
  final Future<File> Function(Uint8List bytes) writeTempFile;

  /// Whether to show a banner ad. Disabled in tests.
  final bool showAd;

  const ResultSignature({
    super.key,
    required this.image,
    required this.whiteImage,
    this.saveFile = _saveWithFileSaver,
    this.shareFile = _shareWithSharePlus,
    this.writeTempFile = writeSignatureToTemp,
    this.showAd = true,
  });

  @override
  State<ResultSignature> createState() => _ResultSignatureState();
}

class _ResultSignatureState extends State<ResultSignature> {
  bool _whiteBackground = false;
  bool _saving = false;
  bool _sharing = false;

  Uint8List get _selectedImage =>
      _whiteBackground ? widget.whiteImage : widget.image;

  Future<void> _save() async {
    if (_saving) return;
    final strings = AppStrings.of(context);
    setState(() => _saving = true);
    final result = await saveSignature(
      _selectedImage,
      saveFile: widget.saveFile,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Fluttertoast.showToast(msg: saveResultMessage(result, strings));
  }

  Future<void> _share() async {
    if (_sharing) return;
    final strings = AppStrings.of(context);
    setState(() => _sharing = true);
    try {
      final file = await widget.writeTempFile(_selectedImage);
      await widget.shareFile(file, strings.shareText);
    } catch (_) {
      Fluttertoast.showToast(msg: strings.shareFailed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final color = onTap == null ? Colors.grey : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 1), // changes position of shadow
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backgroundChoice(AppStrings strings) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(strings.transparent),
          selected: !_whiteBackground,
          onSelected: (_) => setState(() => _whiteBackground = false),
        ),
        ChoiceChip(
          label: Text(strings.white),
          selected: _whiteBackground,
          onSelected: (_) => setState(() => _whiteBackground = true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.resultTitle,
          style: GoogleFonts.pacifico(color: Colors.black, fontSize: 23),
        ),
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 18),
          if (widget.showAd)
            const Center(
              child: BannerAdWidget(placement: BannerPlacement.resultPage),
            ),
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(15),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(_selectedImage, gaplessPlayback: true),
              ),
            ),
          ),
          _backgroundChoice(strings),
          Padding(
            padding: const EdgeInsets.only(top: 15, bottom: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.save,
                  label: strings.save,
                  onTap: _saving ? null : _save,
                ),
                const SizedBox(width: 15),
                _actionButton(
                  icon: Icons.share,
                  label: strings.share,
                  onTap: _sharing ? null : _share,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
