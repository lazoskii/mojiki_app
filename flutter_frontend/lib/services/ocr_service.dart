// Leitura do texto de uma foto NO PRÓPRIO APARELHO (RF12 — foto → cards),
// sem precisar instalar nada no computador do backend.
//
// O Dart escolhe, na hora de compilar, qual arquivo usar:
//   - navegador (Edge/Chrome)  → ocr_web.dart    (Tesseract.js, web/ocr.js)
//   - celular Android / iOS    → ocr_mobile.dart (Google ML Kit, japonês)
//   - outros (Windows, testes) → ocr_stub.dart   (indisponível)
//
// Todos expõem a mesma coisa:
//   bool ocrNoAparelhoDisponivel
//   Future<String> lerTextoDaFoto({bytes, caminho})
// Quando não está disponível, a importação manda a foto pro backend, que
// tenta o Tesseract instalado lá (plano B).
export 'ocr_stub.dart'
    if (dart.library.js_interop) 'ocr_web.dart'
    if (dart.library.io) 'ocr_mobile.dart';
