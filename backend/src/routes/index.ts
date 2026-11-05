import { Router } from 'express';
import authRoutes from './authRoutes';
import raceRoutes from './raceRoutes';
import newsRoutes from './newsRoutes';
import workoutRoutes from './workoutRoutes';
import notificationRoutes from './notificationRoutes';
import routeRoutes from './routeRoutes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/races', raceRoutes);
router.use('/news', newsRoutes);
router.use('/workouts', workoutRoutes);
router.use('/notifications', notificationRoutes);
router.use('/routes', routeRoutes);

// Endpoint de verificação de status da API
router.get('/health', (req, res) => {
  res.status(200).json({
    sucesso: true,
    status: 'API do RunnersRun rodando perfeitamente!',
    timestamp: new Date().toISOString(),
  });
});

export default router;
