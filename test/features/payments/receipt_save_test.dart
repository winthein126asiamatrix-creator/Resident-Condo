import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test/features/payments/presentation/controllers/payment_controller.dart';

void main() {
  group('receipt file detection', () {
    test('detects a PDF from its signature', () {
      final bytes = Uint8List.fromList('%PDF-1.7'.codeUnits);

      expect(
        detectReceiptFileFormat('application/octet-stream', bytes),
        ReceiptFileFormat.pdf,
      );
    });

    test('rejects an HTML page that claims to be a PDF', () {
      final bytes = Uint8List.fromList('<html>error</html>'.codeUnits);

      expect(detectReceiptFileFormat('application/pdf', bytes), isNull);
    });

    test('detects PNG and JPEG images', () {
      expect(
        detectReceiptFileFormat(
          null,
          Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]),
        ),
        ReceiptFileFormat.image,
      );
      expect(
        detectReceiptFileFormat(
          null,
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF]),
        ),
        ReceiptFileFormat.image,
      );
    });

    test('uses an image content type when the bytes are unfamiliar', () {
      expect(
        detectReceiptFileFormat(
          'image/heic',
          Uint8List.fromList(<int>[0x01, 0x02, 0x03]),
        ),
        ReceiptFileFormat.image,
      );
    });

    test('rejects unknown binary data', () {
      expect(
        detectReceiptFileFormat(
          'application/octet-stream',
          Uint8List.fromList(<int>[0x01, 0x02, 0x03]),
        ),
        isNull,
      );
    });
  });

  group('receipt file naming', () {
    test('prefixes the receipt number', () {
      expect(receiptFileBaseName('PAY-2026-005'), 'Receipt_PAY-2026-005');
    });

    test('removes characters that are unsafe in a file name', () {
      expect(receiptFileBaseName('RCT/2026 5'), 'Receipt_RCT_2026_5');
    });

    test('falls back when the receipt number is missing', () {
      expect(receiptFileBaseName('  '), 'Receipt');
    });
  });

  group('receipt save result', () {
    test('names the gallery for images', () {
      const result = ReceiptSaveResult(
        format: ReceiptFileFormat.image,
        fileName: 'Receipt_PAY-2026-005.jpg',
        location: 'Gallery',
      );

      expect(
        result.message,
        'Receipt saved to Gallery as Receipt_PAY-2026-005.jpg.',
      );
    });

    test('names the real Downloads path for PDFs', () {
      const result = ReceiptSaveResult(
        format: ReceiptFileFormat.pdf,
        fileName: 'Receipt_PAY-2026-005.pdf',
        location: 'Downloads/Receipt_PAY-2026-005.pdf',
      );

      expect(
        result.message,
        'Receipt saved to Downloads/Receipt_PAY-2026-005.pdf.',
      );
    });
  });
}
