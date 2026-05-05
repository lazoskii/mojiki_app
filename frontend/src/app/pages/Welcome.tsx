import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Mail, Lock, User, ArrowRight } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { AppIcon } from '../components/AppIcon';

export function Welcome() {
  const navigate = useNavigate();
  const [isLogin, setIsLogin] = useState(true);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Simulação de autenticação (apenas frontend)
    localStorage.setItem('isAuthenticated', 'true');
    if (!isLogin) {
      localStorage.setItem('userName', formData.name);
    }
    navigate('/home');
  };

  return (
    <div className="min-h-full bg-gradient-to-br from-red-600 via-red-800 to-black flex flex-col">
      {/* Header */}
      <div className="pt-16 pb-8 px-6 text-center text-white">
        <div className="inline-flex items-center justify-center w-20 h-20 bg-white/20 backdrop-blur-sm rounded-3xl mb-6">
          <AppIcon className="w-12 h-12" />
        </div>
        <h1 className="text-4xl mb-3">Komoji</h1>
        <h2 className="text-3xl mb-2">古文字</h2>
        <p className="text-white/90 text-lg">
          Aprenda japonês de forma interativa
        </p>
      </div>

      {/* Form Card */}
      <div className="flex-1 bg-white rounded-t-[2.5rem] px-6 pt-8 pb-6">
        <div className="mb-6">
          <h3 className="text-2xl mb-2">
            {isLogin ? 'Bem-vindo de volta!' : 'Criar conta'}
          </h3>
          <p className="text-gray-600">
            {isLogin 
              ? 'Entre para continuar seus estudos' 
              : 'Comece sua jornada no japonês'}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {!isLogin && (
            <div className="space-y-2">
              <label className="text-sm text-gray-700">Nome</label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <Input
                  type="text"
                  placeholder="Seu nome"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="pl-11 h-14 bg-gray-50 border-gray-200"
                  required={!isLogin}
                />
              </div>
            </div>
          )}

          <div className="space-y-2">
            <label className="text-sm text-gray-700">Email</label>
            <div className="relative">
              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <Input
                type="email"
                placeholder="seu@email.com"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                className="pl-11 h-14 bg-gray-50 border-gray-200"
                required
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-sm text-gray-700">Senha</label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <Input
                type="password"
                placeholder="••••••••"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                className="pl-11 h-14 bg-gray-50 border-gray-200"
                required
              />
            </div>
          </div>

          <Button
            type="submit"
            className="w-full h-14 bg-gradient-to-r from-red-600 to-black hover:from-red-700 hover:to-gray-900 text-base mt-6"
          >
            {isLogin ? 'Entrar' : 'Criar conta'}
            <ArrowRight className="w-5 h-5 ml-2" />
          </Button>
        </form>

        <div className="mt-6 text-center">
          <button
            onClick={() => setIsLogin(!isLogin)}
            className="text-red-600 text-sm"
          >
            {isLogin 
              ? 'Não tem uma conta? Cadastre-se' 
              : 'Já tem uma conta? Entre'}
          </button>
        </div>

        {/* Features */}
        <div className="mt-8 space-y-3">
          <div className="flex items-center gap-3 text-sm text-gray-600">
            <div className="w-8 h-8 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
              <span>🎌</span>
            </div>
            <span>4 decks completos de vocabulário</span>
          </div>
          <div className="flex items-center gap-3 text-sm text-gray-600">
            <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0">
              <span>✨</span>
            </div>
            <span>Flashcards interativos com animações</span>
          </div>
          <div className="flex items-center gap-3 text-sm text-gray-600">
            <div className="w-8 h-8 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
              <span>📊</span>
            </div>
            <span>Acompanhe seu progresso</span>
          </div>
        </div>
      </div>
    </div>
  );
}