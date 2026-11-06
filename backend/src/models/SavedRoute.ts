import mongoose, { Schema } from 'mongoose';
import { ISavedRoute } from '../types';

const pointSchema = new Schema({ lat: { type: Number, required: true }, lng: { type: Number, required: true } }, { _id: false });

const segmentSchema = new Schema(
  {
    // [longitude, latitude] ou [longitude, latitude, altitude], como no GeoJSON
    coordenadas: { type: [[Number]], required: true },
    subidaM: { type: Number, default: 0 },
    emLinhaReta: { type: Boolean, default: false },
  },
  { _id: false }
);

const routeShapeFields = {
  pontos: { type: [pointSchema], required: true },
  trechos: { type: [segmentSchema], required: true },
  distanciaM: { type: Number, required: true },
  subidaM: { type: Number, default: 0 },
  temLinhaReta: { type: Boolean, default: false },
};

/** Traçado guardado dentro de outro documento, como o percurso de uma prova. */
export const routeShapeSchema = new Schema(routeShapeFields, { _id: false });

/** Rota planejada no mapa. É sempre privada: só o dono consegue ver. */
const savedRouteSchema = new Schema<ISavedRoute>(
  {
    dono: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    nome: { type: String, required: true, trim: true },
    ...routeShapeFields,
  },
  { timestamps: true }
);

export const SavedRoute = mongoose.model<ISavedRoute>('SavedRoute', savedRouteSchema);
