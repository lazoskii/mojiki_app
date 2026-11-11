// OCR no navegador (RF12 — foto → cards), usado pelo app Flutter web.
//
// Usa o Tesseract.js (o Tesseract compilado pra WebAssembly), carregado no
// index.html. Na primeira foto ele baixa os pacotes de japonês (jpn) e
// português (por) — alguns MB — e o navegador guarda em cache; depois
// funciona sem internet. O "worker" é criado uma vez só e reaproveitado.
//
// O Dart chama window.mojikiOcr(bytes) (ver lib/services/ocr_web.dart) e
// recebe o texto lido; a separação japonês/português é feita no backend.
(function () {
  let workerPromise = null;

  function obterWorker() {
    if (!workerPromise) {
      // 'por' ANTES de 'jpn': na ordem contrária o Tesseract perde os
      // acentos do português ("água" saía "agua") — testado
      workerPromise = Tesseract.createWorker(['por', 'jpn']).catch(function (erro) {
        workerPromise = null; // permite tentar de novo (ex.: estava sem internet)
        throw erro;
      });
    }
    return workerPromise;
  }

  window.mojikiOcr = async function (bytes) {
    if (typeof Tesseract === 'undefined') {
      throw new Error('Tesseract.js não carregou (sem internet?)');
    }
    const worker = await obterWorker();
    const resultado = await worker.recognize(new Blob([bytes]));
    return resultado.data.text || '';
  };
})();
