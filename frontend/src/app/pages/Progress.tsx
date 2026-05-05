import { useState } from 'react';
import { motion } from 'motion/react';
import { Menu, Award, Calendar, TrendingUp, Flame } from 'lucide-react';
import { PhoneMockup } from '../components/PhoneMockup';
import { Sidebar } from '../components/Sidebar';
import { decks } from '../data/flashcards';

export function Progress() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  // Mock data - em produção viria do localStorage ou backend
  const stats = {
    totalCards: decks.reduce((sum, deck) => sum + deck.cards.length, 0),
    cardsStudied: 42,
    streak: 7,
    accuracy: 85,
  };

  const deckProgress = decks.map((deck) => ({
    ...deck,
    studied: Math.floor(Math.random() * deck.cards.length),
    accuracy: Math.floor(Math.random() * 30) + 70,
  }));

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
              <h1 className="text-2xl text-white">Progresso</h1>
              <div className="w-10" />
            </div>
          </div>

          {/* Content */}
          <div className="flex-1 px-6 pb-6 overflow-y-auto">
            {/* Stats Grid */}
            <div className="grid grid-cols-2 gap-3 mb-6">
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 }}
                className="bg-white/10 backdrop-blur-sm rounded-2xl p-4 border border-white/20"
              >
                <div className="flex items-center gap-2 mb-2">
                  <Award className="w-5 h-5 text-yellow-400" />
                  <span className="text-white/80 text-xs">Precisão</span>
                </div>
                <p className="text-white text-3xl font-light">{stats.accuracy}%</p>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.15 }}
                className="bg-white/10 backdrop-blur-sm rounded-2xl p-4 border border-white/20"
              >
                <div className="flex items-center gap-2 mb-2">
                  <Flame className="w-5 h-5 text-orange-400" />
                  <span className="text-white/80 text-xs">Sequência</span>
                </div>
                <p className="text-white text-3xl font-light">{stats.streak} dias</p>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
                className="bg-white/10 backdrop-blur-sm rounded-2xl p-4 border border-white/20"
              >
                <div className="flex items-center gap-2 mb-2">
                  <TrendingUp className="w-5 h-5 text-green-400" />
                  <span className="text-white/80 text-xs">Estudados</span>
                </div>
                <p className="text-white text-3xl font-light">{stats.cardsStudied}</p>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.25 }}
                className="bg-white/10 backdrop-blur-sm rounded-2xl p-4 border border-white/20"
              >
                <div className="flex items-center gap-2 mb-2">
                  <Calendar className="w-5 h-5 text-blue-400" />
                  <span className="text-white/80 text-xs">Total</span>
                </div>
                <p className="text-white text-3xl font-light">{stats.totalCards}</p>
              </motion.div>
            </div>

            {/* Overall Progress */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="bg-white/10 backdrop-blur-sm rounded-2xl p-5 border border-white/20 mb-6"
            >
              <div className="flex items-center justify-between mb-3">
                <span className="text-white text-sm font-medium">Progresso Geral</span>
                <span className="text-white text-sm">
                  {stats.cardsStudied}/{stats.totalCards}
                </span>
              </div>
              <div className="w-full h-3 bg-white/10 rounded-full overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${(stats.cardsStudied / stats.totalCards) * 100}%` }}
                  transition={{ delay: 0.5, duration: 1, ease: "easeOut" }}
                  className="h-full bg-gradient-to-r from-yellow-400 to-red-500 rounded-full"
                />
              </div>
            </motion.div>

            {/* Deck Progress */}
            <div className="space-y-3">
              <h2 className="text-white text-lg font-medium mb-4">
                Progresso por Deck
              </h2>
              {deckProgress.map((deck, index) => (
                <motion.div
                  key={deck.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.4 + index * 0.1 }}
                  className="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/20"
                >
                  <div className="flex items-center gap-3 mb-3">
                    <div className="text-2xl">{deck.icon}</div>
                    <div className="flex-1">
                      <h3 className="text-white text-sm font-medium">
                        {deck.title}
                      </h3>
                      <p className="text-white/60 text-xs">
                        {deck.studied}/{deck.cards.length} cards
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-white text-sm font-medium">
                        {deck.accuracy}%
                      </p>
                      <p className="text-white/60 text-xs">precisão</p>
                    </div>
                  </div>
                  <div className="w-full h-2 bg-white/10 rounded-full overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${(deck.studied / deck.cards.length) * 100}%` }}
                      transition={{ delay: 0.6 + index * 0.1, duration: 0.8 }}
                      className="h-full bg-gradient-to-r from-red-400 to-red-600 rounded-full"
                    />
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </PhoneMockup>
    </>
  );
}
