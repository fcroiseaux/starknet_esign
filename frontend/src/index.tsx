import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './components/App';
import './styles.css';

// Create root container
const container = document.getElementById('root');
if (!container) throw new Error('Failed to find the root element');
const root = createRoot(container);

// Render the application
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);