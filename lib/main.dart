import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_signature/ad_consent.dart';
import 'package:simple_signature/pen_options.dart';
import 'package:simple_signature/result_signature.dart';
import 'package:simple_signature/signature_pad.dart';
import 'package:simple_signature/signature_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const MyApp());
  unawaited(clearSignatureCache());
  unawaited(AdConsentManager.instance.gatherConsent());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signature',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.ubuntuTextTheme(Theme.of(context).textTheme),
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  /// Consent state used to decide whether to show the privacy options button.
  final AdConsentManager? adConsentManager;

  const MyHomePage({super.key, this.adConsentManager});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _currentSliderValue = defaultStrokeWidth;
  Color penColor = Colors.black;
  StrokeCap strokeCap = StrokeCap.round;

  final SignatureController _signatureController = SignatureController(
    strokeWidth: defaultStrokeWidth,
  );
  final GlobalKey<SignaturePadState> _signaturePadKey = GlobalKey();

  AdConsentManager get _adConsent =>
      widget.adConsentManager ?? AdConsentManager.instance;

  /// Applies the current pen settings to strokes drawn from now on.
  /// Existing strokes keep the pen they were drawn with.
  void _applyPen() {
    final paint = buildPenPaint(
      color: penColor,
      strokeCap: strokeCap,
      strokeWidth: _currentSliderValue,
    );
    _signatureController
      ..color = paint.color
      ..strokeCap = paint.strokeCap
      ..strokeWidth = paint.strokeWidth;
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  /// Exports the signature, or shows a toast and returns null when empty.
  Future<Uint8List?> _exportSignature() async {
    if (_signatureController.isEmpty) {
      Fluttertoast.showToast(msg: 'Your signature is empty');
      return null;
    }
    final data = await _signaturePadKey.currentState?.exportPng();
    if (data == null) {
      Fluttertoast.showToast(msg: 'Unable to export your signature');
    }
    return data;
  }

  Future<void> _shareSignature() async {
    final data = await _exportSignature();
    if (data == null) return;
    try {
      final file = await writeSignatureToTemp(data);
      await SharePlus.instance.share(
        ShareParams(
          previewThumbnail: XFile(file.path),
          files: [XFile(file.path)],
          text: 'Here is my signature!',
        ),
      );
    } catch (_) {
      Fluttertoast.showToast(msg: 'Unable to share your signature');
    }
  }

  Future<void> _openResult() async {
    final data = await _exportSignature();
    if (data == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (builder) => ResultSignature(image: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Signature',
          style: GoogleFonts.pacifico(color: Colors.black, fontSize: 23),
        ),
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _adConsent.privacyOptionsRequired,
            builder: (context, required, _) {
              if (!required) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Privacy settings',
                onPressed: _adConsent.showPrivacyOptions,
                icon: const Icon(Icons.privacy_tip, color: Colors.black),
              );
            },
          ),
          IconButton(
            onPressed: _shareSignature,
            icon: const Icon(Icons.share, color: Colors.black),
          ),
          IconButton(
            onPressed: () {
              _updateBrushDialog();
            },
            icon: const Icon(Icons.brush, color: Colors.black),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SignaturePad(
              key: _signaturePadKey,
              controller: _signatureController,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.save),
                  color: Colors.white,
                  onPressed: _openResult,
                ),
                IconButton(
                  icon: const Icon(Icons.draw),
                  color: Colors.white,
                  onPressed: () async {
                    _strokeCapDialog();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.palette),
                  color: Colors.white,
                  onPressed: () {
                    _chooseColorsDialog();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  color: Colors.white,
                  onPressed: _signatureController.clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile({
    required bool selected,
    required String title,
    Widget? leading,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      tileColor: selected ? Colors.grey.shade100 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: leading,
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Future<void> _chooseColorsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                for (final option in penColorOptions)
                  _optionTile(
                    selected: penColor == option.color,
                    title: option.name,
                    leading: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      penColor = option.color;
                      _applyPen();
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _strokeCapDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                for (final option in strokeCapOptions)
                  _optionTile(
                    selected: strokeCap == option.strokeCap,
                    title: option.name,
                    onTap: () {
                      strokeCap = option.strokeCap;
                      _applyPen();
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateBrushDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Row(
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: penColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            activeColor: Colors.grey.shade200,
                            inactiveColor: Colors.black.withValues(alpha: 0.1),
                            value: _currentSliderValue,
                            min: minStrokeWidth,
                            max: maxStrokeWidth,
                            divisions: 10,
                            label: _currentSliderValue.round().toString(),
                            onChanged: (double value) {
                              setState(() {});
                              this.setState(() {
                                _currentSliderValue = value;
                                _applyPen();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: penColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
