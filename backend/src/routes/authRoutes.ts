import { Router } from 'express';
import {
  register,
  login,
  getMe,
  getProfileById,
  updateProfile,
  toggleSaveRace,
  togglePresence,
} from '../controllers/authController';
import { protect } from '../middlewares/authMiddleware';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.get('/me', protect, getMe);
router.get('/profile/:id', getProfileById);
router.put('/profile', protect, updateProfile);
router.post('/races/:raceId/toggle-save', protect, toggleSaveRace);
router.post('/races/:raceId/toggle-presence', protect, togglePresence);

export default router;
