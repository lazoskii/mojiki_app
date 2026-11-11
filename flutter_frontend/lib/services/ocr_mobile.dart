import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// OCR no celular (ver ocr_service.dart) com o Google ML Kit: roda no
// próprio aparelho, offline e grátis. O modelo "japanese" lê kanji/kana e
// também letras latinas (o português). Este arquivo também é compilado no
// Windows (tem dart:io), mas lá o ML Kit não existe — por isso o
// ocrNoAparelhoDisponivel só é true no Android e no iOS.

bool get ocrNoAparelhoDisponivel => Platform.isAndroid || Platform.isIOS;

Future<String> lerTextoDaFoto({required Uint8List bytes, String? caminho}) async {
  // o ML Kit lê de um arquivo; se a foto não veio com caminho, grava uma
  // cópia temporária
  var arquivo = caminho;
  File? temporario;
  if (arquivo == null || !File(arquivo).existsSync()) {
    temporario = File(
        '${Directory.systemTemp.path}/mojiki_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await temporario.writeAsBytes(bytes);
    arquivo = temporario.path;
  }

  final reconhecedor = TextRecognizer(script: TextRecognitionScript.japanese);
  try {
    final resultado =
        await reconhecedor.processImage(InputImage.fromFilePath(arquivo));
    // uma linha do ML Kit = uma linha do texto (o backend pareia por linha)
    return resultado.blocks
        .expand((bloco) => bloco.lines)
        .map((linha) => linha.text)
        .join('\n');
  } finally {
    await reconhecedor.close();
    if (temporario != null && temporario.existsSync()) {
      await temporario.delete();
    }
  }
}
