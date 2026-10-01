import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import IndexRoute from '../routes/index';
import './styles.css';

const root = document.getElementById('root');
if (!root) throw new Error('Missing application root.');

createRoot(root).render(
  <StrictMode>
    {window.location.pathname === '/' ? (
      <IndexRoute />
    ) : (
      <main className="home">
        <h1>Page not found.</h1>
        <a href="/">Back to TrackingTrucks</a>
      </main>
    )}
  </StrictMode>,
);
