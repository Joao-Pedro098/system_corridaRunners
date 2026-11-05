import { Router } from 'express';
import { getNotifications, getUnreadCount, markAllAsRead } from '../controllers/notificationController';
import { protect } from '../middlewares/authMiddleware';

const router = Router();

router.use(protect);
router.get('/', getNotifications);
router.get('/unread-count', getUnreadCount);
router.post('/read-all', markAllAsRead);

export default router;
