import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class CryptoService {
  static const _keyB64 = String.fromEnvironment('STONKS_AES_KEY', defaultValue: 'c3RvbmtzLWFlcy1rZXktMzItYnl0ZXMhISE=');

  late final Key _key;

  CryptoService() {
    _key = Key(base64.decode(_keyB64));
  }

  String encrypt(String plaintext) {
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final combined = Uint8List(16 + encrypted.bytes.length)
      ..setRange(0, 16, iv.bytes)
      ..setRange(16, 16 + encrypted.bytes.length, encrypted.bytes);
    return base64.encode(combined);
  }

  String decrypt(String ciphertext) {
    final combined = base64.decode(ciphertext);
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final data = Encrypted(Uint8List.fromList(combined.sublist(16)));
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    return encrypter.decrypt(data, iv: iv);
  }
}
