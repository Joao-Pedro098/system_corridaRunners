import { Response } from 'express';
import { Notification } from '../models/Notification';
import { AuthenticatedRequest } from '../types';
import { parsePagination } from '../utils/http';

// @desc    Listar notificações do usuário logado
// @route   GET /api/notifications
// @access  Privado
export const getNotifications = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { page, limit, skip } = parsePagination(req.query, 30);
    const filtro = { destinatario: req.user!._id };

    const [notificacoes, total, naoLidas] = await Promise.all([
      Notification.find(filtro)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('autor', 'nome avatarUrl')
        .populate('treino', 'titulo'),
      Notification.countDocuments(filtro),
      Notification.countDocuments({ ...filtro, lida: false }),
    ]);

    res.status(200).json({
      sucesso: true,
      total,
      naoLidas,
      pagina: page,
      paginasTotal: Math.ceil(total / limit),
      dados: notificacoes,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar notificações.',
    });
  }
};

// @desc    Contar notificações não lidas (usado no sino do app)
// @route   GET /api/notifications/unread-count
// @access  Privado
export const getUnreadCount = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const naoLidas = await Notification.countDocuments({ destinatario: req.user!._id, lida: false });
    res.status(200).json({ sucesso: true, naoLidas });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao contar notificações.',
    });
  }
};

// @desc    Marcar todas as notificações como lidas
// @route   POST /api/notifications/read-all
// @access  Privado
export const markAllAsRead = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    await Notification.updateMany({ destinatario: req.user!._id, lida: false }, { lida: true });
    res.status(200).json({ sucesso: true, naoLidas: 0 });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao atualizar notificações.',
    });
  }
};
