import { useState, useEffect } from 'react';  //busca o deck no back
import { useParams, useNavigate } from 'react-router';
import { motion } from 'motion/react';
import { ArrowLeft, RotateCcw, Menu } from 'lucide-react';
import { Flashcard } from '../components/Flashcard';
import { decks } from '../data/flashcards';
import { PhoneMockup } from '../components/PhoneMockup';
import { Sidebar } from '../components/Sidebar';
import { Button } from '../components/ui/button';


export function Study() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const { deckId } = useParams();
  const navigate = useNavigate();
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isFlipped, setIsFlipped] = useState(false);
  const [deck, setDeck] = useState<any>(null);
  const [pergunta, setPergunta] = useState("");
  const [resposta, setResposta] = useState("");

  function deletarFlashcard(id: number) {
  fetch(`http://127.0.0.1:8000/flashcards/${id}`, {
    method: "DELETE",
  }).then(() => {
    setDeck((prev: any) => ({
      ...prev,
      cards: prev.cards.filter((card: any) => card.id !== id),
    }));

    setCurrentIndex(0);
    setIsFlipped(false);
  });
}

  function criarFlashcard() {
  if (!pergunta || !resposta) return;

  fetch("http://127.0.0.1:8000/flashcards", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      pergunta: pergunta,
      resposta: resposta,
      deck_id: Number(deckId),
    }),
  })
    .then(res => res.json())
    .then(data => {
      setDeck((prev: any) => ({
        ...prev,
        cards: [...(prev.cards || []), data],
      }));

      setPergunta("");
      setResposta("");
      setIsFlipped(false);
      
      setCurrentIndex((prev: any) => (deck?.cards?.length || 0));
    });
}


  useEffect(() => {
  fetch(`http://127.0.0.1:8000/decks/${deckId}`)
    .then(res => res.json())
    .then(data => {
      console.log("DECK COMPLETO:", data);
      setDeck(data);
    });
}, [deckId]);

  

  if (!deck) {
    return (
  <PhoneMockup>
    <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex items-center justify-center">
      <p className="text-white text-lg">Carregando...</p>
    </div>
  </PhoneMockup>
);
  }

  const currentCard = deck.cards?.[currentIndex];
  

  const progress = deck.cards?.length
  ? ((currentIndex + 1) / deck.cards.length) * 100
  : 0;

  const handleNext = () => {
    if (currentIndex < deck.cards.length - 1) {
      setCurrentIndex(currentIndex + 1);
    }
  };

  const handlePrevious = () => {
    if (currentIndex > 0) {
      setCurrentIndex(currentIndex - 1);
    }
  };

  const handleReset = () => {
    setCurrentIndex(0);
    setIsFlipped(false);
  };

  return (            //JSX
    <>
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} />
      <PhoneMockup>
        <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex flex-col">
          {/* Header */}
          <div className="p-6 pb-4">
            <div className="flex items-center justify-between mb-4">
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => setIsSidebarOpen(true)}
                className="text-white p-2 hover:bg-white/10 rounded-lg transition-colors"
              >
                <Menu className="w-6 h-6" />
              </motion.button>
              <h1 className="text-xl text-white">{deck.nome}</h1>
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={handleReset}
                className="text-white p-2 hover:bg-white/10 rounded-lg transition-colors"
              >
                <RotateCcw className="w-5 h-5" />
              </motion.button>
            </div>

            {/* Progress */}
            <div className="space-y-2">
              <div className="flex items-center justify-between text-white/80 text-sm">
                <span>Progresso</span>
                <span>{currentIndex + 1} / {deck.cards.length}</span>
              </div>
              <div className="w-full h-2 bg-white/10 rounded-full overflow-hidden">
                <motion.div
                  className="h-full bg-gradient-to-r from-yellow-400 to-white"
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  transition={{ duration: 0.3 }}
                />
              </div>
            </div>
          </div>


          {/* Criar flashcard */}
<div className="px-6 mb-4 flex flex-col gap-2">
  <input
    value={pergunta}
    onChange={(e) => setPergunta(e.target.value)}
    placeholder="Pergunta"
    className="p-2 rounded"
  />

  <input
    value={resposta}
    onChange={(e) => setResposta(e.target.value)}
    placeholder="Resposta"
    className="p-2 rounded"
  />

  <button
  onClick={criarFlashcard}
  className="bg-white text-black p-3 rounded-lg font-semibold shadow-md active:scale-95 transition"
>
  + Criar Flashcard
</button>
</div>

<div className="flex-1 flex items-center justify-center px-6 py-6">
  {currentCard ? (
    <div className="w-full flex flex-col items-center gap-4">
      <Flashcard
        card={currentCard}
        isFlipped={isFlipped}
        setIsFlipped={setIsFlipped}
      />

      <button
        onClick={() => deletarFlashcard(currentCard.id)}
        className="bg-red-600 text-white p-2 rounded"
      >
        Deletar Card
      </button>
    </div>
  ) : (
    <p className="text-white text-lg">Sem cards ainda</p>
  )}
</div>          
) : (
            

          {/* Navigation */}
          <div className="p-6 pt-4">
            <div className="flex items-center gap-3">
              <Button
                onClick={handlePrevious}
                disabled={currentIndex === 0}
                className="flex-1 h-14 text-base bg-white/10 hover:bg-white/20 text-white border border-white/20 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <ArrowLeft className="w-5 h-5 mr-1" />
                Anterior
              </Button>
              <Button
                onClick={handleNext}
                disabled={currentIndex === deck.cards.length - 1}
                className="flex-1 h-14 bg-white hover:bg-white/90 text-red-600 text-base disabled:opacity-30 disabled:cursor-not-allowed"
              >
                {currentIndex === deck.cards.length - 1 ? 'Concluído' : 'Próximo'}
                {currentIndex < deck.cards.length - 1 && <ArrowLeft className="w-5 h-5 ml-1 rotate-180" />}
              </Button>
            </div>
          </div>
        </div>
      </PhoneMockup>
    </>
  );
}


