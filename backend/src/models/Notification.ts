import mongoose, { Schema } from 'mongoose';
import { INotification } from '../types';

const notificationSchema = new Schema<INotification>(
  {
    destinatario: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    autor: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    tipo: {
      type: String,
      enum: ['curtida', 'comentario', 'seguidor'],
      required: true,
    },
    treino: {
      type: Schema.Types.ObjectId,
      ref: 'WorkoutPost',
    },
    // Id do comentário dentro do treino: se ele for excluído, o aviso também sai.
    comentario: {
      type: Schema.Types.ObjectId,
    },
    lida: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

notificationSchema.index({ destinatario: 1, createdAt: -1 });
notificationSchema.index({ treino: 1 });

export const Notification = mongoose.model<INotification>('Notification', notificationSchema);
