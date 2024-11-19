library flutter_sheet_localization;

export 'package:template_string/template_string.dart';

class SheetLocalization {
  final String docId;
  final String sheetId;
  final int version;
  final bool jsonSerializers;
  final String? langFallback;
  const SheetLocalization(
    this.docId,
    this.sheetId,
    this.version, {
    this.jsonSerializers = true,
    this.langFallback,
  });
}
