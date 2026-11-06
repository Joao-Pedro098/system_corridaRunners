import { Router } from 'express';
import {
  createWorkout,
  getFeed,
  getWorkoutById,
  getWorkoutsByUserId,
  toggleLike,
  addComment,
  deleteComment,
  deleteWorkout,
  updateWorkout,
  uploadWorkoutPhotos,
} from '../controllers/workoutController';
import { protect } from '../middlewares/authMiddleware';
import { receiveWorkoutPhotos } from '../middlewares/uploadMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

// Feed geral da comunidade
router.get('/feed', getFeed);

// Treinos de um atleta específico (Perfil)
router.get('/user/:userId', validateObjectId('userId'), getWorkoutsByUserId);

// Um treino específico (usado ao abrir uma notificação)
router.get('/:id', validateObjectId('id'), getWorkoutById);

// Criar novo treino (requer autenticação)
router.post('/', protect, createWorkout);

// Enviar fotos do treino (antes de publicar)
router.post('/photos', protect, receiveWorkoutPhotos, uploadWorkoutPhotos);

// Curtir / Descurtir treino
router.post('/:id/like', protect, validateObjectId('id'), toggleLike);

// Adicionar comentário
router.post('/:id/comments', protect, validateObjectId('id'), addComment);

// Excluir comentário
router.delete('/:id/comments/:commentId', protect, validateObjectId('id', 'commentId'), deleteComment);

// Editar treino
router.put('/:id', protect, validateObjectId('id'), updateWorkout);

// Excluir treino
router.delete('/:id', protect, validateObjectId('id'), deleteWorkout);

export default router;
