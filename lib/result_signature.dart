import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_signature/banner_ad_widget.dart';

class ResultSignature extends StatefulWidget {
  final Uint8List? image;
  const ResultSignature({
    super.key,
    this.image,
  });

  @override
  State<ResultSignature> createState() => _ResultSignatureState();
}

class _ResultSignatureState extends State<ResultSignature> {
  String? imagePath;
  File? image;

  Future saveToGalery() async {
    Random random = Random();
    int randomNumber = random.nextInt(10000);

    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    File file = File('$tempPath/signature-$randomNumber.png');
    await file.writeAsBytes(widget.image!);
    image = file;
    setState(() {});
    if (kDebugMode) print(image!.path);
    await FlutterFileSaver().writeFileAsBytes(
      fileName: "signature-${Random().nextInt(10000)}.png",
      bytes: widget.image!,
    );

    Fluttertoast.showToast(msg: 'Signature successfully saved!');
  }

  Future shareImage() async {
    // ignore: deprecated_member_use
    await SharePlus.instance.share(
      ShareParams(
          previewThumbnail: XFile(image!.path),
          files: [XFile(image!.path)],
          text: 'Here is my signature!'),
    );
  }

  @override
  void initState() {
    saveToGalery();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Result',
            style: GoogleFonts.pacifico(color: Colors.black, fontSize: 23)),
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 18,
          ),
          Center(
            child: BannerAdWidget(
              placement: BannerPlacement.resultPage,
            ),
          ),
          Expanded(
            child: Center(
              child: image != null
                  ? Container(
                      padding: const EdgeInsets.all(15),
                      // child: Image.file(image!),
                      child: Image.file(image!),
                    )
                  : SizedBox(
                      child: Text('Kosong'),
                    ),
            ),
          ),
          GestureDetector(
            onTap: () {
              shareImage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              margin: const EdgeInsets.only(bottom: 25),
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
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.share,
                    color: Colors.black,
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    ' Share Signature',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
