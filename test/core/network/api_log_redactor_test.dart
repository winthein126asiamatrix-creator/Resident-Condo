import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/core/network/interceptors/api_log_redactor.dart';

void main() {
  test('masks sensitive headers and keeps harmless ones', () {
    final headers = ApiLogRedactor.redactHeaders(<String, dynamic>{
      'Authorization': 'Bearer super-secret',
      'Cookie': 'session=abc',
      'X-Api-Key': 'key-123',
      'Content-Type': 'application/json',
    });

    expect(headers['Authorization'], ApiLogRedactor.mask);
    expect(headers['Cookie'], ApiLogRedactor.mask);
    expect(headers['X-Api-Key'], ApiLogRedactor.mask);
    expect(headers['Content-Type'], 'application/json');
  });

  test('masks sensitive keys recursively in nested bodies', () {
    final safe = ApiLogRedactor.value(<String, dynamic>{
      'user': <String, dynamic>{
        'name': 'Resident',
        'password': 'hunter2',
        'access_token': 'token',
        'cards': <dynamic>[
          <String, dynamic>{'card_number': '4242424242424242', 'cvv': '123'},
        ],
      },
    }) as Map<String, Object?>;

    final user = safe['user'] as Map<String, Object?>;
    final cards = user['cards'] as List<Object?>;
    final card = cards.single as Map<String, Object?>;

    expect(user['name'], 'Resident');
    expect(user['password'], ApiLogRedactor.mask);
    expect(user['access_token'], ApiLogRedactor.mask);
    expect(card['card_number'], ApiLogRedactor.mask);
    expect(card['cvv'], ApiLogRedactor.mask);
  });

  test('masks sensitive query values', () {
    final query = ApiLogRedactor.redactQuery(<String, dynamic>{
      'page': '2',
      'token': 'secret',
      'refresh_token': 'refresh',
      'email': 'resident@example.com',
    });

    expect(query['page'], '2');
    expect(query['token'], ApiLogRedactor.mask);
    expect(query['refresh_token'], ApiLogRedactor.mask);
    expect(query['email'], 'resident@example.com');
  });

  test('bounds long strings and large collections', () {
    final longString = ApiLogRedactor.value(
      'a' * (ApiLogRedactor.maxStringLength + 50),
    ) as String;
    final list = ApiLogRedactor.value(
      List<int>.generate(ApiLogRedactor.maxEntries + 40, (index) => index),
    );
    final map = ApiLogRedactor.value(<String, dynamic>{
      for (var i = 0; i < ApiLogRedactor.maxEntries + 40; i++) 'k$i': i,
    }) as Map<String, Object?>;

    expect(longString, contains('<truncated:'));
    expect(list, isA<String>());
    expect(map.length, ApiLogRedactor.maxEntries + 1);
    expect(map['<truncated>'], isNotNull);
  });

  test('never stringifies binary payloads', () {
    final safe = ApiLogRedactor.value(Uint8List.fromList(<int>[1, 2, 3]));

    expect(safe, '<binary 3 bytes>');
  });

  test('summarizes multipart bodies without file contents', () {
    final form = FormData();
    form.fields.add(const MapEntry<String, String>('note', 'hello'));
    form.fields.add(const MapEntry<String, String>('password', 'hunter2'));
    form.files.add(
      MapEntry<String, MultipartFile>(
        'photo',
        MultipartFile.fromBytes(<int>[1, 2, 3, 4], filename: 'photo.jpg'),
      ),
    );

    final safe = ApiLogRedactor.value(form) as Map<String, Object?>;
    final fields = safe['fields'] as Map<String, Object?>;
    final files = safe['files'] as List<Object?>;
    final file = files.single as Map<String, Object?>;

    expect(fields['note'], 'hello');
    expect(fields['password'], ApiLogRedactor.mask);
    expect(file['filename'], 'photo.jpg');
    expect(file['size'], 4);
    expect(safe.toString(), isNot(contains('hello there')));
  });

  test('masks bearer and key/value secrets in free text', () {
    final safe = ApiLogRedactor.truncateText(
      'Authorization: Bearer abc.def.ghi access_token=leak',
    );

    expect(safe, isNot(contains('abc.def.ghi')));
    expect(safe, isNot(contains('leak')));
    expect(safe, contains(ApiLogRedactor.mask));
  });
}
