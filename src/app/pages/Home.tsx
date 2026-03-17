import { useState } from 'react';
import { motion } from 'motion/react';
import { LogOut, Menu } from 'lucide-react';
import { DeckCard } from '../components/DeckCard';
import { decks } from '../data/flashcards';
import { PhoneMockup } from '../components/PhoneMockup';
import { Sidebar } from '../components/Sidebar';
import { useNavigate } from 'react-router';

export function Home() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const navigate = useNavigate();
  const userName = localStorage.getItem('userName') || 'Estudante';

  const handleLogout = () => {
    localStorage.removeItem('isAuthenticated');
    localStorage.removeItem('userName');
    navigate('/welcome');
  };

  return (
    <>
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} />
      <PhoneMockup>
        <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex flex-col">
          {/* Header */}
          <div className="p-6 pb-4">
            <div className="flex items-center justify-between mb-2">
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => setIsSidebarOpen(true)}
                className="text-white p-2 hover:bg-white/10 rounded-lg transition-colors"
              >
                <Menu className="w-6 h-6" />
              </motion.button>
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={handleLogout}
                className="text-white/80 hover:text-white p-2 hover:bg-white/10 rounded-lg transition-colors"
              >
                <LogOut className="w-5 h-5" />
              </motion.button>
            </div>
            <h1 className="text-2xl text-white mb-1">
              Olá, {userName}!
            </h1>
            <p className="text-white/80 text-sm">
              Escolha um deck para começar a estudar
            </p>
          </div>

          {/* Deck Grid */}
          <div className="flex-1 px-6 pb-6 overflow-y-auto">
            <div className="grid grid-cols-2 gap-4">
              {decks.map((deck, index) => (
                <DeckCard key={deck.id} deck={deck} index={index} />
              ))}
            </div>
          </div>
        </div>
      </PhoneMockup>
    </>
  );
}