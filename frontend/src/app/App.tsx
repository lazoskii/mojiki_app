import { RouterProvider } from 'react-router';
import { router } from './routes';
import { PhoneMockup } from './components/PhoneMockup';

export default function App() {
  return (
    <PhoneMockup>
      <RouterProvider router={router} />
    </PhoneMockup>
  );
}