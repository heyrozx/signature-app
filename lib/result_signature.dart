import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_signature/banner_ad_widget.dart';
import 'package:simple_signature/signature_storage.dart';

typedef SaveSignatureFile = Future<String> Function({
  required String fileName,
  required Uint8List bytes,
});

typedef ShareSignatureFile = Future<void> Function(File file);

enum SaveResult { saved, cancelled, failed }

Future<String> _saveWithFileSaver({
  required String fileName,
  required Uint8List bytes,
}) {
  return FlutterFileSaver().writeFileAsBytes(fileName: fileName, bytes: bytes);
}

Future<void> _shareWithSharePlus(File file) async {
  await SharePlus.instance.share(
    ShareParams(
      previewThumbnail: XFile(file.path),
      files: [XFile(file.path)],
      text: 'Here is my signature!',
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

String saveResultMessage(SaveResult result) {
  switch (result) {
    case SaveResult.saved:
      return 'Signature successfully saved!';
    case SaveResult.cancelled:
      return 'Save cancelled';
    case SaveResult.failed:
      return 'Failed to save signature';
  }
}

class ResultSignature extends StatefulWidget {
  final Uint8List image;

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
    this.saveFile = _saveWithFileSaver,
    this.shareFile = _shareWithSharePlus,
    this.writeTempFile = writeSignatureToTemp,
    this.showAd = true,
  });

  @override
  State<ResultSignature> createState() => _ResultSignatureState();
}

class _ResultSignatureState extends State<ResultSignature> {
  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // Opening this page is the user's "save" action, so start saving at once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await saveSignature(widget.image, saveFile: widget.saveFile);
    if (!mounted) return;
    setState(() => _saving = false);
    Fluttertoast.showToast(msg: saveResultMessage(result));
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await widget.writeTempFile(widget.image);
      await widget.shareFile(file);
    } catch (_) {
      Fluttertoast.showToast(msg: 'Unable to share your signature');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
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
            Icon(icon, color: onTap == null ? Colors.grey : Colors.black),
            const SizedBox(width: 5),
            Text(
              ' $label',
              style: TextStyle(
                color: onTap == null ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Result',
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
                padding: const EdgeInsets.all(15),
                child: Image.memory(widget.image),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.save,
                  label: 'Save',
                  onTap: _saving ? null : _save,
                ),
                const SizedBox(width: 15),
                _actionButton(
                  icon: Icons.share,
                  label: 'Share Signature',
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
