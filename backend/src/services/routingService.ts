export interface LatLng {
  lat: number;
  lng: number;
}

export interface WalkingSegment {
  coordenadas: number[][];
  subidaM: number;
}

export type RoutingErrorCode = 'sem_chave' | 'sem_caminho' | 'limite' | 'indisponivel';

export class RoutingError extends Error {
  constructor(
    public readonly codigo: RoutingErrorCode,
    message: string
  ) {
    super(message);
  }
}

const TIMEOUT_MS = 10_000;
const EARTH_RADIUS_M = 6_371_000;

const toRadians = (degrees: number) => (degrees * Math.PI) / 180;

/** Distância em metros entre dois pontos [longitude, latitude]. */
export const haversine = (a: number[], b: number[]): number => {
  const dLat = toRadians(b[1] - a[1]);
  const dLng = toRadians(b[0] - a[0]);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRadians(a[1])) * Math.cos(toRadians(b[1])) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
};

const round = (value: number, digits: number) => Number(value.toFixed(digits));

/** Pede ao OpenRouteService o caminho a pé entre dois pontos. */
export const fetchWalkingSegment = async (from: LatLng, to: LatLng): Promise<WalkingSegment> => {
  const key = process.env.ORS_API_KEY;
  if (!key) throw new RoutingError('sem_chave', 'O traçado pelas ruas ainda não foi configurado no servidor.');

  const base = process.env.ORS_BASE_URL || 'https://api.openrouteservice.org';
  let response: Response;
  let data: any;
  try {
    response = await fetch(`${base}/v2/directions/foot-walking/geojson`, {
      method: 'POST',
      headers: {
        Authorization: key,
        'Content-Type': 'application/json',
        Accept: 'application/geo+json, application/json',
        'User-Agent': 'RunnersRun/1.0',
      },
      body: JSON.stringify({
        coordinates: [
          [from.lng, from.lat],
          [to.lng, to.lat],
        ],
        elevation: true,
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    data = await response.json().catch(() => null);
  } catch {
    throw new RoutingError('indisponivel', 'O serviço de rotas não respondeu.');
  }

  if (response.status === 429) {
    throw new RoutingError('limite', 'O limite de rotas do serviço foi atingido por agora.');
  }
  const code = data?.error?.code;
  if (response.status === 404 || code === 2009 || code === 2010) {
    throw new RoutingError('sem_caminho', 'Não há caminho a pé conhecido até esse ponto.');
  }
  if (!response.ok) {
    throw new RoutingError('indisponivel', 'O serviço de rotas não está disponível agora.');
  }

  const feature = data?.features?.[0];
  const coordinates = feature?.geometry?.coordinates;
  const valid =
    Array.isArray(coordinates) &&
    coordinates.length >= 2 &&
    coordinates.every((c: unknown) => Array.isArray(c) && c.length >= 2 && c.every(Number.isFinite));
  if (!valid) throw new RoutingError('indisponivel', 'O serviço de rotas devolveu uma resposta inesperada.');

  const ascent = feature.properties?.ascent;
  return {
    coordenadas: coordinates.map((c: number[]) => [
      round(c[0], 6),
      round(c[1], 6),
      ...(c.length > 2 ? [round(c[2], 1)] : []),
    ]),
    subidaM: Number.isFinite(ascent) && ascent > 0 ? round(ascent, 1) : 0,
  };
};
