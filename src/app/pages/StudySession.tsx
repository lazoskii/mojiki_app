import { useState } from 'react';
import { motion } from 'motion/react';
import { Menu, Clock, Target, Zap } from 'lucide-react';
import { PhoneMockup } from '../components/PhoneMockup';
import { Sidebar } from '../components/Sidebar';
import { Button } from '../components/ui/button';
import { useNavigate } from 'react-router';
import { decks } from '../data/flashcards';

export function StudySession() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const navigate = useNavigate();

  const studyModes = [
    {
      id: 'quick',
      title: 'Sessão Rápida',
      description: '5 minutos de prática',
      icon: Zap,
      duration: '5 min',
      color: 'from-yellow-500 to-orange-600'
    },
    {
      id: 'daily',
      title: 'Prática Diária',
      description: '15 minutos recomendados',
      icon: Target,
      duration: '15 min',
      color: 'from-red-500 to-red-700'
    },
    {
      id: 'intensive',
      title: 'Sessão Intensiva',
      description: '30 minutos focados',
      icon: Clock,
      duration: '30 min',
      color: 'from-purple-600 to-red-900'
    },
  ];

  const handleStartSession = (deckId: string) => {
    navigate(`/deck/${deckId}`);
  };

  return (
    <>
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} />
      <PhoneMockup>
        <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex flex-col">
          {/* Header */}
          <div className="p-6 pb-4">
            <div className="flex items-center justify-between mb-6">
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => setIsSidebarOpen(true)}
                className="text-white p-2 hover:bg-white/10 rounded-lg transition-colors"
              >
                <Menu className="w-6 h-6" />
              </motion.button>
              <h1 className="text-2xl text-white">Sessão de Estudo</h1>
              <div className="w-10" />
            </div>

            <p className="text-white/80 text-center text-sm">
              Escolha seu modo de estudo
            </p>
          </div>

          {/* Study Modes */}
          <div className="flex-1 px-6 pb-6 overflow-y-auto">
            <div className="space-y-4 mb-8">
              {studyModes.map((mode, index) => (
                <motion.div
                  key={mode.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.1 }}
                  className={`bg-gradient-to-r ${mode.color} rounded-2xl p-6 shadow-xl`}
                >
                  <div className="flex items-start gap-4 mb-4">
                    <div className="w-14 h-14 bg-white/20 rounded-xl flex items-center justify-center backdrop-blur-sm">
                      <mode.icon className="w-7 h-7 text-white" />
                    </div>
                    <div className="flex-1">
                      <h3 className="text-white text-lg font-medium mb-1">
                        {mode.title}
                      </h3>
                      <p className="text-white/80 text-sm">{mode.description}</p>
                    </div>
                    <div className="bg-white/20 rounded-lg px-3 py-1 backdrop-blur-sm">
                      <span className="text-white text-xs font-medium">
                        {mode.duration}
                      </span>
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>

            {/* Quick Access Decks */}
            <div className="space-y-4">
              <h2 className="text-white text-lg font-medium">
                Acesso Rápido
              </h2>
              <div className="grid grid-cols-2 gap-3">
                {decks.map((deck, index) => (
                  <motion.button
                    key={deck.id}
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: 0.3 + index * 0.05 }}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => handleStartSession(deck.id)}
                    className="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/20 text-left hover:bg-white/20 transition-all"
                  >
                    <div className="text-3xl mb-2">{deck.icon}</div>
                    <h3 className="text-white text-sm font-medium mb-1">
                      {deck.title}
                    </h3>
                    <p className="text-white/60 text-xs">
                      {deck.cards.length} cards
                    </p>
                  </motion.button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </PhoneMockup>
    </>
  );
}
