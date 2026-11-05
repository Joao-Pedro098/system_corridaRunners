import { Router } from 'express';
import {
  getAllRaces,
  getMyRaces,
  uploadRaceCover,
  getFeaturedRaces,
  getRaceById,
  createRace,
  updateRace,
  deleteRace,
} from '../controllers/raceController';
import { protect, authorize } from '../middlewares/authMiddleware';
import { receiveRaceCover } from '../middlewares/uploadMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

// Rotas públicas
router.get('/', getAllRaces);
router.get('/featured', getFeaturedRaces);
router.get('/mine', protect, authorize('organizador', 'admin'), getMyRaces);
router.get('/:id', validateObjectId('id'), getRaceById);

// Rotas protegidas (apenas Organizadores ou Admins podem gerenciar corridas)
router.post('/cover', protect, authorize('organizador', 'admin'), receiveRaceCover, uploadRaceCover);
router.post('/', protect, authorize('organizador', 'admin'), createRace);
router.put('/:id', protect, authorize('organizador', 'admin'), validateObjectId('id'), updateRace);
router.delete('/:id', protect, authorize('organizador', 'admin'), validateObjectId('id'), deleteRace);

export default router;
