import { useState } from 'react';
import { motion } from 'motion/react';
import type { Flashcard as FlashcardType } from '../data/flashcards';

interface FlashcardProps {
  card: any;
  isFlipped: boolean;
  setIsFlipped: (value: boolean) => void;
}

export function Flashcard({ card, isFlipped, setIsFlipped }: FlashcardProps) {
  
  return (
    <div 
      className="perspective-1000 w-full max-w-[300px] mx-auto px-4"
      onClick={() => setIsFlipped(!isFlipped)}
    >
      <motion.div
        className="relative w-full h-[350px]"
        initial={false}
        animate={{ rotateY: isFlipped ? 180 : 0 }}
        transition={{ duration: 0.6, type: "spring", stiffness: 100 }}
        style={{ transformStyle: "preserve-3d" }}
      >
        {/* Front */}
        <div
          className="absolute inset-0 bg-white rounded-3xl shadow-2xl flex flex-col items-center justify-center p-6 border-2 border-gray-100"
          style={{ backfaceVisibility: "hidden" }}
        >
          <div className="text-5xl md:text-6xl leading-none mb-6 text-center break-words">{card?.pergunta}</div>
          <div className="text-gray-400 text-sm">Toque para revelar</div>
        </div>

        {/* Back */}
        <div
          className="absolute inset-0 bg-gradient-to-br from-red-600 to-black rounded-3xl shadow-2xl flex flex-col items-center justify-center p-6 text-white"
          style={{ 
            backfaceVisibility: "hidden",
            transform: "rotateY(180deg)"
          }}
        >
          <div className="text-4xl mb-3 text-center leading-tight">{card?.resposta}</div>
          {card.romaji && (
            <div className="text-xl opacity-80 mt-2">{card.romaji}</div>
          )}
          <div className="text-white/60 text-sm mt-8">Toque para voltar</div>
        </div>
      </motion.div>
    </div>
  );
}