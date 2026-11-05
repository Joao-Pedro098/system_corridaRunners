import { Router } from 'express';
import {
  register,
  login,
  getMe,
  getProfileById,
  updateProfile,
  toggleSaveRace,
  togglePresence,
  toggleFollow,
} from '../controllers/authController';
import { protect } from '../middlewares/authMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.get('/me', protect, getMe);
router.get('/profile/:id', validateObjectId('id'), getProfileById);
router.put('/profile', protect, updateProfile);
router.post('/races/:raceId/toggle-save', protect, validateObjectId('raceId'), toggleSaveRace);
router.post('/races/:raceId/toggle-presence', protect, validateObjectId('raceId'), togglePresence);
router.post('/users/:id/toggle-follow', protect, validateObjectId('id'), toggleFollow);

export default router;
