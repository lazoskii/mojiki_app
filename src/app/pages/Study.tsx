import { useState, useEffect } from 'react';
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

  const deck = decks.find((d) => d.id === deckId);

  useEffect(() => {
    setIsFlipped(false);
  }, [currentIndex]);

  if (!deck) {
    return (
      <PhoneMockup>
        <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex items-center justify-center">
          <p className="text-white">Deck não encontrado</p>
        </div>
      </PhoneMockup>
    );
  }

  const currentCard = deck.cards[currentIndex];
  const progress = ((currentIndex + 1) / deck.cards.length) * 100;

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

  return (
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
              <h1 className="text-xl text-white">{deck.title}</h1>
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

          {/* Flashcard */}
          <div className="flex-1 flex items-center justify-center px-6 py-6">
            <Flashcard card={currentCard} isFlipped={isFlipped} setIsFlipped={setIsFlipped} />
          </div>

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
