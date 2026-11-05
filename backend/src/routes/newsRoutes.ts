import { Router } from 'express';
import {
  getAllNews,
  getNewsById,
  createNews,
} from '../controllers/newsController';
import { protect, authorize } from '../middlewares/authMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

router.get('/', getAllNews);
router.get('/:id', validateObjectId('id'), getNewsById);
router.post('/', protect, authorize('admin', 'organizador'), createNews);

export default router;
