import express, { Application } from 'express';
import cors from 'cors';
import apiRoutes from './routes';
import { notFound, errorHandler } from './middlewares/errorMiddleware';
import { UPLOAD_ROOT } from './middlewares/uploadMiddleware';

const app: Application = express();

// Configurações de Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Fotos enviadas pelos atletas
app.use(
  '/uploads',
  express.static(UPLOAD_ROOT, {
    index: false,
    setHeaders: (res) => res.setHeader('X-Content-Type-Options', 'nosniff'),
  })
);

// Rotas da API
app.use('/api', apiRoutes);

// Tratamento de rotas inexistentes e erros globais
app.use(notFound);
app.use(errorHandler);

export default app;
