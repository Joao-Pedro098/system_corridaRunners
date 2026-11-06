import path from 'path';
import dotenv from 'dotenv';
import app from './app';
import { connectDatabase } from './config/database';
import { startNewsSync } from './services/newsSyncService';

// Carrega o .env localizado na raiz do backend independentemente do diretório de onde o comando for executado
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const PORT = process.env.PORT || 3000;

const startServer = async () => {
  await connectDatabase();

  app.listen(PORT, () => {
    console.log(`🚀 Servidor rodando na porta ${PORT} no modo ${process.env.NODE_ENV || 'development'}`);
    console.log(`📡 Endpoints disponíveis em: http://localhost:${PORT}/api`);
    startNewsSync();
  });
};

startServer();
