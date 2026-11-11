import 'dart:typed_data';

// Plataformas sem OCR no aparelho (ver ocr_service.dart).
bool get ocrNoAparelhoDisponivel => false;

Future<String> lerTextoDaFoto({required Uint8List bytes, String? caminho}) =>
    throw UnsupportedError('Leitura de foto no aparelho indisponível aqui');
