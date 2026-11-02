import { Router } from 'express';
import {
  createWorkout,
  getFeed,
  getWorkoutsByUserId,
  toggleLike,
  addComment,
  deleteWorkout,
} from '../controllers/workoutController';
import { protect } from '../middlewares/authMiddleware';

const router = Router();

// Feed geral da comunidade
router.get('/feed', getFeed);

// Treinos de um atleta específico (Perfil)
router.get('/user/:userId', getWorkoutsByUserId);

// Criar novo treino (requer autenticação)
router.post('/', protect, createWorkout);

// Curtir / Descurtir treino
router.post('/:id/like', protect, toggleLike);

// Adicionar comentário
router.post('/:id/comments', protect, addComment);

// Excluir treino
router.delete('/:id', protect, deleteWorkout);

export default router;
