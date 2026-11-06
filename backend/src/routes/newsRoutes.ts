import { Router } from 'express';
import {
  getAllNews,
  getHiddenNews,
  getNewsById,
  getNewsSources,
  createNews,
  deleteNews,
  updateNews,
  setNewsSourceActive,
  setNewsVisibility,
  syncNews,
} from '../controllers/newsController';
import { protect, authorize } from '../middlewares/authMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

router.get('/', getAllNews);
router.post('/', protect, authorize('admin', 'organizador'), createNews);

router.get('/hidden', protect, authorize('admin'), getHiddenNews);
router.get('/sources', protect, authorize('admin'), getNewsSources);
router.post('/sources/sync', protect, authorize('admin'), syncNews);
router.put('/sources/:id', protect, authorize('admin'), setNewsSourceActive);

router.get('/:id', validateObjectId('id'), getNewsById);
router.put('/:id', protect, authorize('admin', 'organizador'), validateObjectId('id'), updateNews);
router.delete('/:id', protect, authorize('admin', 'organizador'), validateObjectId('id'), deleteNews);
router.put('/:id/visibility', protect, authorize('admin'), validateObjectId('id'), setNewsVisibility);

export default router;
