export interface Flashcard {
  id: string;
  front: string;
  back: string;
  romaji?: string;
}

export interface Deck {
  id: string;
  name: string;
  description: string;
  cards: Flashcard[];
  color: string;
}

export const decks: Deck[] = [
  {
    id: 'hiragana',
    name: 'Hiragana',
    description: 'Alfabeto básico japonês',
    color: 'from-red-500 to-red-700',
    cards: [
      { id: '1', front: 'あ', back: 'A', romaji: 'a' },
      { id: '2', front: 'い', back: 'I', romaji: 'i' },
      { id: '3', front: 'う', back: 'U', romaji: 'u' },
      { id: '4', front: 'え', back: 'E', romaji: 'e' },
      { id: '5', front: 'お', back: 'O', romaji: 'o' },
      { id: '6', front: 'か', back: 'KA', romaji: 'ka' },
      { id: '7', front: 'き', back: 'KI', romaji: 'ki' },
      { id: '8', front: 'く', back: 'KU', romaji: 'ku' },
      { id: '9', front: 'け', back: 'KE', romaji: 'ke' },
      { id: '10', front: 'こ', back: 'KO', romaji: 'ko' },
      { id: '11', front: 'さ', back: 'SA', romaji: 'sa' },
      { id: '12', front: 'し', back: 'SHI', romaji: 'shi' },
      { id: '13', front: 'す', back: 'SU', romaji: 'su' },
      { id: '14', front: 'せ', back: 'SE', romaji: 'se' },
      { id: '15', front: 'そ', back: 'SO', romaji: 'so' },
    ],
  },
  {
    id: 'katakana',
    name: 'Katakana',
    description: 'Para palavras estrangeiras',
    color: 'from-gray-700 to-black',
    cards: [
      { id: '1', front: 'ア', back: 'A', romaji: 'a' },
      { id: '2', front: 'イ', back: 'I', romaji: 'i' },
      { id: '3', front: 'ウ', back: 'U', romaji: 'u' },
      { id: '4', front: 'エ', back: 'E', romaji: 'e' },
      { id: '5', front: 'オ', back: 'O', romaji: 'o' },
      { id: '6', front: 'カ', back: 'KA', romaji: 'ka' },
      { id: '7', front: 'キ', back: 'KI', romaji: 'ki' },
      { id: '8', front: 'ク', back: 'KU', romaji: 'ku' },
      { id: '9', front: 'ケ', back: 'KE', romaji: 'ke' },
      { id: '10', front: 'コ', back: 'KO', romaji: 'ko' },
      { id: '11', front: 'サ', back: 'SA', romaji: 'sa' },
      { id: '12', front: 'シ', back: 'SHI', romaji: 'shi' },
      { id: '13', front: 'ス', back: 'SU', romaji: 'su' },
      { id: '14', front: 'セ', back: 'SE', romaji: 'se' },
      { id: '15', front: 'ソ', back: 'SO', romaji: 'so' },
    ],
  },
  {
    id: 'kanji',
    name: 'Kanji Básico',
    description: 'Primeiros caracteres',
    color: 'from-red-600 to-gray-900',
    cards: [
      { id: '1', front: '日', back: 'Sol / Dia', romaji: 'nichi / hi' },
      { id: '2', front: '月', back: 'Lua / Mês', romaji: 'getsu / tsuki' },
      { id: '3', front: '火', back: 'Fogo', romaji: 'ka / hi' },
      { id: '4', front: '水', back: 'Água', romaji: 'sui / mizu' },
      { id: '5', front: '木', back: 'Árvore', romaji: 'moku / ki' },
      { id: '6', front: '金', back: 'Ouro / Dinheiro', romaji: 'kin / kane' },
      { id: '7', front: '土', back: 'Terra', romaji: 'do / tsuchi' },
      { id: '8', front: '人', back: 'Pessoa', romaji: 'jin / hito' },
      { id: '9', front: '山', back: 'Montanha', romaji: 'san / yama' },
      { id: '10', front: '川', back: 'Rio', romaji: 'sen / kawa' },
      { id: '11', front: '一', back: 'Um', romaji: 'ichi' },
      { id: '12', front: '二', back: 'Dois', romaji: 'ni' },
      { id: '13', front: '三', back: 'Três', romaji: 'san' },
      { id: '14', front: '四', back: 'Quatro', romaji: 'shi / yon' },
      { id: '15', front: '五', back: 'Cinco', romaji: 'go' },
    ],
  },
  {
    id: 'phrases',
    name: 'Frases Comuns',
    description: 'Expressões do dia a dia',
    color: 'from-red-500 to-black',
    cards: [
      { id: '1', front: 'こんにちは', back: 'Olá', romaji: 'konnichiwa' },
      { id: '2', front: 'おはよう', back: 'Bom dia', romaji: 'ohayou' },
      { id: '3', front: 'こんばんは', back: 'Boa noite', romaji: 'konbanwa' },
      { id: '4', front: 'ありがとう', back: 'Obrigado', romaji: 'arigatou' },
      { id: '5', front: 'すみません', back: 'Desculpe', romaji: 'sumimasen' },
      { id: '6', front: 'さようなら', back: 'Adeus', romaji: 'sayounara' },
      { id: '7', front: 'はい', back: 'Sim', romaji: 'hai' },
      { id: '8', front: 'いいえ', back: 'Não', romaji: 'iie' },
      { id: '9', front: 'お元気ですか', back: 'Como você está?', romaji: 'ogenki desu ka' },
      { id: '10', front: 'わかりません', back: 'Não entendo', romaji: 'wakarimasen' },
      { id: '11', front: 'いただきます', back: 'Bom apetite', romaji: 'itadakimasu' },
      { id: '12', front: 'ごちそうさま', back: 'Obrigado pela comida', romaji: 'gochisousama' },
      { id: '13', front: 'おやすみ', back: 'Boa noite (dormir)', romaji: 'oyasumi' },
      { id: '14', front: 'お願いします', back: 'Por favor', romaji: 'onegaishimasu' },
      { id: '15', front: 'どういたしまして', back: 'De nada', romaji: 'douitashimashite' },
    ],
  },
];