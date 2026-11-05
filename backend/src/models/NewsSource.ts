import mongoose, { Schema } from 'mongoose';
import { INewsSource } from '../types';

/** Estado de cada fonte de notícias; a lista de fontes em si fica em config/newsSources. */
const newsSourceSchema = new Schema<INewsSource>(
  {
    fonteId: { type: String, required: true, unique: true },
    ativa: { type: Boolean, default: true },
    ultimaBusca: { type: Date },
    ultimoErro: { type: String },
    ultimasNovas: { type: Number, default: 0 },
    historicoConcluido: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export const NewsSource = mongoose.model<INewsSource>('NewsSource', newsSourceSchema);
