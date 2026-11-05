import { Router } from 'express';
import {
  createRoute,
  deleteRoute,
  getMyRoutes,
  getRouteById,
  getSegment,
  updateRoute,
} from '../controllers/routeController';
import { protect } from '../middlewares/authMiddleware';
import { validateObjectId } from '../middlewares/validateObjectId';

const router = Router();

router.use(protect);

router.post('/segment', getSegment);
router.route('/').get(getMyRoutes).post(createRoute);
router
  .route('/:id')
  .all(validateObjectId('id'))
  .get(getRouteById)
  .put(updateRoute)
  .delete(deleteRoute);

export default router;
