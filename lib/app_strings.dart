import 'package:material_ui/material_ui.dart';

/// UI text in English and Indonesian, picked from the device language.
///
/// The app has only a handful of strings, so a plain lookup table keeps
/// this simpler than generated localizations.
class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;

  static const List<Locale> supportedLocales = [Locale('en'), Locale('id')];

  static AppStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode;
    return AppStrings(_values.containsKey(code) ? code! : 'en');
  }

  String _t(String key) => _values[languageCode]![key] ?? _values['en']![key]!;

  String get appTitle => _t('appTitle');
  String get resultTitle => _t('resultTitle');
  String get emptySignature => _t('emptySignature');
  String get exportFailed => _t('exportFailed');
  String get shareFailed => _t('shareFailed');
  String get shareText => _t('shareText');
  String get saved => _t('saved');
  String get saveCancelled => _t('saveCancelled');
  String get saveFailed => _t('saveFailed');
  String get save => _t('save');
  String get share => _t('share');
  String get next => _t('next');
  String get undo => _t('undo');
  String get redo => _t('redo');
  String get clear => _t('clear');
  String get penColor => _t('penColor');
  String get penTip => _t('penTip');
  String get penSize => _t('penSize');
  String get privacySettings => _t('privacySettings');
  String get transparent => _t('transparent');
  String get white => _t('white');

  /// Translates a pen color or stroke cap name from [penColorOptions] or
  /// [strokeCapOptions].
  String option(String englishName) => _t('option.$englishName');

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Signature',
      'resultTitle': 'Result',
      'emptySignature': 'Your signature is empty',
      'exportFailed': 'Unable to export your signature',
      'shareFailed': 'Unable to share your signature',
      'shareText': 'Here is my signature!',
      'saved': 'Signature successfully saved!',
      'saveCancelled': 'Save cancelled',
      'saveFailed': 'Failed to save signature',
      'save': 'Save',
      'share': 'Share Signature',
      'next': 'Next',
      'undo': 'Undo',
      'redo': 'Redo',
      'clear': 'Clear',
      'penColor': 'Pen color',
      'penTip': 'Pen tip',
      'penSize': 'Pen size',
      'privacySettings': 'Privacy settings',
      'transparent': 'Transparent',
      'white': 'White',
      'option.Black': 'Black',
      'option.Red': 'Red',
      'option.Green': 'Green',
      'option.Blue': 'Blue',
      'option.Yellow': 'Yellow',
      'option.Brown': 'Brown',
      'option.Round': 'Round',
      'option.Butt': 'Butt',
      'option.Square': 'Square',
    },
    'id': {
      'appTitle': 'Tanda Tangan',
      'resultTitle': 'Hasil',
      'emptySignature': 'Tanda tangan masih kosong',
      'exportFailed': 'Gagal memproses tanda tangan',
      'shareFailed': 'Gagal membagikan tanda tangan',
      'shareText': 'Ini tanda tangan saya!',
      'saved': 'Tanda tangan berhasil disimpan!',
      'saveCancelled': 'Penyimpanan dibatalkan',
      'saveFailed': 'Gagal menyimpan tanda tangan',
      'save': 'Simpan',
      'share': 'Bagikan',
      'next': 'Lanjut',
      'undo': 'Urungkan',
      'redo': 'Ulangi',
      'clear': 'Hapus',
      'penColor': 'Warna pena',
      'penTip': 'Ujung pena',
      'penSize': 'Ukuran pena',
      'privacySettings': 'Pengaturan privasi',
      'transparent': 'Transparan',
      'white': 'Putih',
      'option.Black': 'Hitam',
      'option.Red': 'Merah',
      'option.Green': 'Hijau',
      'option.Blue': 'Biru',
      'option.Yellow': 'Kuning',
      'option.Brown': 'Cokelat',
      'option.Round': 'Bulat',
      'option.Butt': 'Datar',
      'option.Square': 'Kotak',
    },
  };
}
