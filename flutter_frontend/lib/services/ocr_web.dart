import 'dart:js_interop';
import 'dart:typed_data';

// OCR no navegador (ver ocr_service.dart). Chama a função JavaScript
// window.mojikiOcr, definida em web/ocr.js, que usa o Tesseract.js.

@JS('mojikiOcr')
external JSPromise<JSString> _mojikiOcr(JSUint8Array bytes);

bool get ocrNoAparelhoDisponivel => true;

Future<String> lerTextoDaFoto({required Uint8List bytes, String? caminho}) async {
  try {
    final texto = await _mojikiOcr(bytes.toJS).toDart;
    return texto.toDart;
  } catch (_) {
    // erro típico: primeira vez sem internet (não baixou o pacote de japonês)
    throw Exception(
        'Não consegui ler a foto no navegador. Na primeira vez é preciso '
        'internet para baixar o pacote de japonês.');
  }
}
