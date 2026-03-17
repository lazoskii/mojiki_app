import { Link } from 'react-router';
import { BookOpen, ArrowRight } from 'lucide-react';
import type { Deck } from '../data/flashcards';

interface DeckCardProps {
  deck: Deck;
}

export function DeckCard({ deck }: DeckCardProps) {
  return (
    <Link to={`/deck/${deck.id}`}>
      <div className="group relative overflow-hidden rounded-2xl bg-white shadow-md active:shadow-lg transition-all duration-200 active:scale-[0.98] border border-gray-100">
        <div className={`absolute inset-0 bg-gradient-to-br ${deck.color} opacity-10`} />
        
        <div className="relative p-5">
          <div className="flex items-start justify-between mb-3">
            <div className={`p-2.5 rounded-xl bg-gradient-to-br ${deck.color} text-white`}>
              <BookOpen className="w-5 h-5" />
            </div>
            <div className="flex items-center gap-2">
              <div className="text-xs text-gray-500 bg-gray-100 px-2.5 py-1 rounded-full">
                {deck.cards.length} cards
              </div>
              <ArrowRight className="w-5 h-5 text-gray-400" />
            </div>
          </div>
          
          <h3 className="text-xl mb-1.5">{deck.name}</h3>
          <p className="text-sm text-gray-600">{deck.description}</p>
          
          <div className="mt-3">
            <div className="bg-gray-200 rounded-full h-1.5 overflow-hidden">
              <div className={`h-full bg-gradient-to-r ${deck.color} w-1/3`} />
            </div>
          </div>
        </div>
      </div>
    </Link>
  );
}