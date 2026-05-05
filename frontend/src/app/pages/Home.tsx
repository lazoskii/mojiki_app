import { useEffect, useState } from 'react'; //adicionei useeffect
import { motion } from 'motion/react';
import { LogOut, Menu } from 'lucide-react';
import { DeckCard } from '../components/DeckCard';
import { PhoneMockup } from '../components/PhoneMockup';
import { Sidebar } from '../components/Sidebar';
import { useNavigate } from 'react-router';

export function Home() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const navigate = useNavigate();
  const userName = localStorage.getItem('userName') || 'Estudante';
  const [decksData, setDecksData] = useState<any[]>([]);              //nova const
  const [novoDeck, setNovoDeck] = useState("");                      //guardar o texto digitado

function deletarDeck(id: number) {
  fetch(`http://127.0.0.1:8000/decks/${id}`, {
    method: "DELETE",
  }).then(() => {
    setDecksData((prev) => prev.filter((deck) => deck.id !== id));
  });
}


  function criarDeck() {
  console.log("ANTES:", novoDeck); // 👈 aqui

  if (!novoDeck) return;

  fetch("http://127.0.0.1:8000/decks", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      nome: novoDeck,
      user_id: 1,
    }),
  })
    .then(res => res.json())
    .then(data => {
      console.log("RESPOSTA BACK:", data); // 👈 aqui

      setDecksData(prev => [...prev, data]);
      setNovoDeck("");
    });
}


  useEffect(() => {                                
  fetch("http://127.0.0.1:8000/decks")                           //buscar da api
    .then(res => res.json())
    .then(data => {
      console.log("decks da API:", data);
      setDecksData(data);
    });
}, []);

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

        <div className="px-6 mb-4">                 
          <input                                      //adiciona botao e input
            value={novoDeck}
            onChange={(e) => setNovoDeck(e.target.value)}
            placeholder="Nome do deck"
            className="w-full p-2 rounded"
          />

          <button
            onClick={criarDeck}
            className="mt-2 w-full bg-white text-black p-2 rounded"
          >
            Criar Deck
          </button>
        </div>


          {/* Deck Grid */}
          <div className="flex-1 px-6 pb-6 overflow-y-auto">
            <div className="grid grid-cols-2 gap-4">
             {decksData.map((deck) => (
  <div key={deck.id}>
    <DeckCard deck={deck} />

    <button
      onClick={() => deletarDeck(deck.id)}
      className="mt-2 w-full bg-red-600 text-white p-2 rounded"
    >
      Deletar Deck
    </button>
  </div>
))}
            </div>
          </div>
        </div>
      </PhoneMockup>
    </>
  );
}