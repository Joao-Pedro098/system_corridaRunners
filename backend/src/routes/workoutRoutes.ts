import { Router } from 'express';
import {
  createWorkout,
  getFeed,
  getWorkoutsByUserId,
  toggleLike,
  addComment,
  deleteComment,
  deleteWorkout,
  uploadWorkoutPhotos,
} from '../controllers/workoutController';
import { protect } from '../middlewares/authMiddleware';
import { receiveWorkoutPhotos } from '../middlewares/uploadMiddleware';

const router = Router();

// Feed geral da comunidade
router.get('/feed', getFeed);

// Treinos de um atleta específico (Perfil)
router.get('/user/:userId', getWorkoutsByUserId);

// Criar novo treino (requer autenticação)
router.post('/', protect, createWorkout);

// Enviar fotos do treino (antes de publicar)
router.post('/photos', protect, receiveWorkoutPhotos, uploadWorkoutPhotos);

// Curtir / Descurtir treino
router.post('/:id/like', protect, toggleLike);

// Adicionar comentário
router.post('/:id/comments', protect, addComment);

// Excluir comentário
router.delete('/:id/comments/:commentId', protect, deleteComment);

// Excluir treino
router.delete('/:id', protect, deleteWorkout);

export default router;
