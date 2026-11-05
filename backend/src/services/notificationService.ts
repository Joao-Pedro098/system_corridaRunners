import { Types } from 'mongoose';
import { Notification } from '../models/Notification';
import { NotificationType } from '../types';

interface NotificationData {
  destinatario: Types.ObjectId;
  autor: Types.ObjectId;
  tipo: NotificationType;
  treino?: Types.ObjectId;
  comentario?: Types.ObjectId;
}

// Avisos são complementares: uma falha aqui nunca desfaz a curtida ou o comentário.
export const notify = async (data: NotificationData): Promise<void> => {
  if (data.destinatario.toString() === data.autor.toString()) return;
  try {
    await Notification.create(data);
  } catch (error) {
    console.error('Erro ao criar notificação:', error);
  }
};

// Remove o aviso quando a ação é desfeita (descurtir, deixar de seguir, excluir).
export const removeNotifications = async (filter: Partial<NotificationData>): Promise<void> => {
  try {
    await Notification.deleteMany(filter);
  } catch (error) {
    console.error('Erro ao remover notificações:', error);
  }
};
