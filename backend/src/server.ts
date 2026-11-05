import http from 'http';
import dotenv from 'dotenv';
import { Server as SocketIOServer } from 'socket.io';
import app from './app';
import { connectDatabase } from './config/database';
import { startNewsSync } from './services/newsSyncService';

dotenv.config();

const PORT = process.env.PORT || 3000;

// Cria o servidor HTTP
const httpServer = http.createServer(app);

// Configuração do Socket.io para atualizações em tempo real (ex: novo treino no feed, curtidas)
export const io = new SocketIOServer(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

io.on('connection', (socket) => {
  console.log(`🔌 Cliente conectado: ${socket.id}`);

  socket.on('join_feed', () => {
    socket.join('community_feed');
  });

  socket.on('disconnect', () => {
    console.log(`❌ Cliente desconectado: ${socket.id}`);
  });
});

const startServer = async () => {
  await connectDatabase();

  httpServer.listen(PORT, () => {
    console.log(`🚀 Servidor rodando na porta ${PORT} no modo ${process.env.NODE_ENV || 'development'}`);
    console.log(`📡 Endpoints disponíveis em: http://localhost:${PORT}/api`);
    startNewsSync();
  });
};

startServer();
