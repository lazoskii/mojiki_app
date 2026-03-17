import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { motion } from 'motion/react';
import { ArrowRight } from 'lucide-react';
import { Button } from '../components/ui/button';

const appName = [
  { kanji: '古', romaji: 'ko', hiragana: 'こ' },
  { kanji: '文', romaji: 'mo', hiragana: 'も' },
  { kanji: '字', romaji: 'ji', hiragana: 'じ' },
];

interface MiniFlashcardProps {
  romaji: string;
  hiragana: string;
  delay: number;
}

function MiniFlashcard({ romaji, hiragana, delay }: MiniFlashcardProps) {
  const [isFlipped, setIsFlipped] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsFlipped(true);
      const flipBackTimer = setTimeout(() => {
        setIsFlipped(false);
      }, 2000);
      
      const intervalId = setInterval(() => {
        setIsFlipped(prev => !prev);
      }, 4000);

      return () => {
        clearTimeout(flipBackTimer);
        clearInterval(intervalId);
      };
    }, delay);

    return () => clearTimeout(timer);
  }, [delay]);

  return (
    <motion.div
      className="perspective-1000"
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: delay / 1000, duration: 0.5 }}
    >
      <motion.div
        className="relative w-16 h-20"
        animate={{ rotateY: isFlipped ? 180 : 0 }}
        transition={{ duration: 0.6, type: "spring", stiffness: 100 }}
        style={{ transformStyle: "preserve-3d" }}
      >
        {/* Front - Romaji */}
        <div
          className="absolute inset-0 bg-white rounded-xl shadow-lg flex items-center justify-center border-2 border-red-200"
          style={{ backfaceVisibility: "hidden" }}
        >
          <span className="text-lg font-medium text-gray-800">{romaji}</span>
        </div>

        {/* Back - Hiragana */}
        <div
          className="absolute inset-0 bg-gradient-to-br from-red-600 to-black rounded-xl shadow-lg flex items-center justify-center text-white"
          style={{
            backfaceVisibility: "hidden",
            transform: "rotateY(180deg)"
          }}
        >
          <span className="text-2xl">{hiragana}</span>
        </div>
      </motion.div>
    </motion.div>
  );
}

export function Onboarding() {
  const navigate = useNavigate();

  return (
    <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex flex-col items-center justify-between p-8 overflow-hidden relative">
      {/* Background Decoration */}
      <motion.div
        className="absolute inset-0 opacity-5"
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.05 }}
        transition={{ duration: 2 }}
      >
        <div className="absolute top-10 left-10 text-white text-9xl">あ</div>
        <div className="absolute bottom-20 right-10 text-white text-9xl">字</div>
      </motion.div>

      {/* Main Content */}
      <div className="flex-1 flex items-center justify-center relative z-10">
        <div className="flex items-center gap-8">
          {/* Vertical Kanji */}
          <motion.div
            className="flex flex-col gap-4 writing-mode-vertical-rl"
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.3 }}
          >
            {appName.map((char, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, scale: 0 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{
                  delay: 0.5 + index * 0.3,
                  duration: 0.5,
                  type: "spring",
                  stiffness: 200
                }}
                className="text-white text-7xl font-light tracking-wider"
              >
                {char.kanji}
              </motion.div>
            ))}
          </motion.div>

          {/* Mini Flashcards */}
          <div className="flex flex-col gap-4">
            {appName.map((char, index) => (
              <MiniFlashcard
                key={index}
                romaji={char.romaji}
                hiragana={char.hiragana}
                delay={1000 + index * 300}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Bottom Section */}
      <motion.div
        className="w-full space-y-6 relative z-10"
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 2, duration: 0.8 }}
      >
        <div className="text-center text-white">
          <h2 className="text-2xl mb-2">Bem-vindo ao Komoji</h2>
          <p className="text-white/80 text-sm">
            Aprenda japonês com flashcards interativos
          </p>
        </div>

        <Button
          onClick={() => navigate('/welcome')}
          className="w-full h-14 bg-white text-red-600 hover:bg-red-50 text-base shadow-xl"
        >
          Começar
          <ArrowRight className="w-5 h-5 ml-2" />
        </Button>

        <div className="flex items-center justify-center gap-2">
          {[0, 1, 2].map((i) => (
            <motion.div
              key={i}
              className="w-2 h-2 bg-white rounded-full"
              animate={{
                scale: [1, 1.5, 1],
                opacity: [0.5, 1, 0.5],
              }}
              transition={{
                duration: 1.5,
                repeat: Infinity,
                delay: i * 0.2,
              }}
            />
          ))}
        </div>
      </motion.div>
    </div>
  );
}
