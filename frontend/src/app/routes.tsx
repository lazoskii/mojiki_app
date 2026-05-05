import { createBrowserRouter } from 'react-router';
import { Splash } from './pages/Splash';
import { Onboarding } from './pages/Onboarding';
import { Welcome } from './pages/Welcome';
import { Home } from './pages/Home';
import { Study } from './pages/Study';
import { StudySession } from './pages/StudySession';
import { Progress } from './pages/Progress';
import { ProtectedRoute } from './components/ProtectedRoute';

export const router = createBrowserRouter([
  {
    path: '/',
    Component: Splash,
  },
  {
    path: '/onboarding',
    Component: Onboarding,
  },
  {
    path: '/welcome',
    Component: Welcome,
  },
  {
    path: '/home',
    element: (
      <ProtectedRoute>
        <Home />
      </ProtectedRoute>
    ),
  },
  {
    path: '/study-session',
    element: (
      <ProtectedRoute>
        <StudySession />
      </ProtectedRoute>
    ),
  },
  {
    path: '/progress',
    element: (
      <ProtectedRoute>
        <Progress />
      </ProtectedRoute>
    ),
  },
  {
    path: '/deck/:deckId',
    element: (
      <ProtectedRoute>
        <Study />
      </ProtectedRoute>
    ),
  },
]);