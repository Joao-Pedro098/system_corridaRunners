import { Router } from 'express';
import {
  getAllRaces,
  getFeaturedRaces,
  getRaceById,
  createRace,
  updateRace,
  deleteRace,
} from '../controllers/raceController';
import { protect, authorize } from '../middlewares/authMiddleware';

const router = Router();

// Rotas públicas
router.get('/', getAllRaces);
router.get('/featured', getFeaturedRaces);
router.get('/:id', getRaceById);

// Rotas protegidas (apenas Organizadores ou Admins podem gerenciar corridas)
router.post('/', protect, authorize('organizador', 'admin'), createRace);
router.put('/:id', protect, authorize('organizador', 'admin'), updateRace);
router.delete('/:id', protect, authorize('organizador', 'admin'), deleteRace);

export default router;
