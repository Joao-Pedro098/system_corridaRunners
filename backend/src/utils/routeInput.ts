import { haversine, LatLng } from '../services/routingService';
import { IRouteShape } from '../types';

const MAX_POINTS = 100;
const MAX_COORDINATES = 20_000;

const isLatitude = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 90;
const isLongitude = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 180;

export const isPoint = (value: any): value is LatLng => isLatitude(value?.lat) && isLongitude(value?.lng);

const isCoordinate = (value: unknown): value is number[] =>
  Array.isArray(value) &&
  (value.length === 2 || value.length === 3) &&
  isLongitude(value[0]) &&
  isLatitude(value[1]) &&
  (value.length === 2 || (typeof value[2] === 'number' && Number.isFinite(value[2])));

/** Traçado reduzido a poucos pontos [longitude, latitude], mantendo a largada e a chegada. */
export const summarizeRoute = (trechos: IRouteShape['trechos'], maxPoints = 80): number[][] => {
  const all = trechos.flatMap((trecho) => trecho.coordenadas);
  const step = Math.max(1, (all.length - 1) / (maxPoints - 1));
  const picked: number[][] = [];
  for (let i = 0; Math.round(i) < all.length - 1; i += step) picked.push(all[Math.round(i)]);
  if (all.length > 0) picked.push(all[all.length - 1]);
  return picked.map(([lng, lat]) => [Number(lng.toFixed(5)), Number(lat.toFixed(5))]);
};

/**
 * Valida o traçado de uma rota salva ou do percurso de uma prova.
 * Copia só os campos conhecidos. A distância é sempre recalculada aqui.
 */
export const parseRouteShape = (body: any): { erro: string } | { dados: IRouteShape } => {
  const { pontos, trechos } = body ?? {};
  if (!Array.isArray(pontos) || pontos.length < 2) return { erro: 'Marque ao menos dois pontos no mapa.' };
  if (pontos.length > MAX_POINTS) return { erro: `A rota pode ter até ${MAX_POINTS} pontos.` };
  if (!pontos.every(isPoint)) return { erro: 'A rota tem um ponto inválido.' };
  if (!Array.isArray(trechos) || trechos.length !== pontos.length - 1) {
    return { erro: 'Os trechos não combinam com os pontos da rota.' };
  }

  let total = 0;
  let distanciaM = 0;
  let subidaM = 0;
  let temLinhaReta = false;
  const parsed: IRouteShape['trechos'] = [];
  for (const trecho of trechos) {
    const coordenadas = trecho?.coordenadas;
    if (!Array.isArray(coordenadas) || coordenadas.length < 2 || !coordenadas.every(isCoordinate)) {
      return { erro: 'A rota tem um trecho inválido.' };
    }
    total += coordenadas.length;
    if (total > MAX_COORDINATES) return { erro: 'A rota é grande demais para salvar.' };

    const subida = Number.isFinite(trecho.subidaM) && trecho.subidaM > 0 ? trecho.subidaM : 0;
    const emLinhaReta = trecho.emLinhaReta === true;
    for (let i = 1; i < coordenadas.length; i += 1) distanciaM += haversine(coordenadas[i - 1], coordenadas[i]);
    subidaM += subida;
    temLinhaReta ||= emLinhaReta;
    parsed.push({ coordenadas, subidaM: subida, emLinhaReta });
  }

  return {
    dados: {
      pontos: pontos.map(({ lat, lng }: LatLng) => ({ lat, lng })),
      trechos: parsed,
      distanciaM: Math.round(distanciaM),
      subidaM: Math.round(subidaM),
      temLinhaReta,
    },
  };
};
