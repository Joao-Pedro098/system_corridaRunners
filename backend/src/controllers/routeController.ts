import { Response } from 'express';
import { SavedRoute } from '../models/SavedRoute';
import { fetchWalkingSegment, haversine, LatLng, RoutingError } from '../services/routingService';
import { AuthenticatedRequest } from '../types';

const MAX_POINTS = 100;
const MAX_COORDINATES = 20_000;
const MAX_ROUTES_PER_USER = 100;
const MAX_SEGMENT_M = 50_000;
const MAX_NAME = 60;
const SEGMENT_REQUESTS_PER_MINUTE = 30;

const isLatitude = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 90;
const isLongitude = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 180;
const isPoint = (value: any): value is LatLng => isLatitude(value?.lat) && isLongitude(value?.lng);

const isCoordinate = (value: unknown): value is number[] =>
  Array.isArray(value) &&
  (value.length === 2 || value.length === 3) &&
  isLongitude(value[0]) &&
  isLatitude(value[1]) &&
  (value.length === 2 || (typeof value[2] === 'number' && Number.isFinite(value[2])));

interface RouteInput {
  nome: string;
  pontos: LatLng[];
  trechos: { coordenadas: number[][]; subidaM: number; emLinhaReta: boolean }[];
  distanciaM: number;
  subidaM: number;
  temLinhaReta: boolean;
}

/** Copia só os campos conhecidos. A distância e a subida são sempre recalculadas aqui. */
const parseRoute = (body: any): { erro: string } | { dados: RouteInput } => {
  const nome = typeof body?.nome === 'string' ? body.nome.trim() : '';
  if (nome.length < 3 || nome.length > MAX_NAME) return { erro: `Dê à rota um nome de 3 a ${MAX_NAME} letras.` };

  const { pontos, trechos } = body;
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
  const parsed: RouteInput['trechos'] = [];
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
      nome,
      pontos: pontos.map(({ lat, lng }: LatLng) => ({ lat, lng })),
      trechos: parsed,
      distanciaM: Math.round(distanciaM),
      subidaM: Math.round(subidaM),
      temLinhaReta,
    },
  };
};

// Cada usuário pede poucos trechos por minuto: a cota do serviço é dividida entre todos.
const recentRequests = new Map<string, number[]>();

const isOverLimit = (userId: string, now = Date.now()): boolean => {
  const recent = (recentRequests.get(userId) ?? []).filter((time) => now - time < 60_000);
  if (recent.length >= SEGMENT_REQUESTS_PER_MINUTE) {
    recentRequests.set(userId, recent);
    return true;
  }
  recent.push(now);
  recentRequests.set(userId, recent);
  // A lista só cresce com quem está usando agora; limpa quem já parou.
  if (recentRequests.size > 1000) {
    for (const [id, times] of recentRequests) {
      if (times.every((time) => now - time >= 60_000)) recentRequests.delete(id);
    }
  }
  return false;
};

const ROUTING_STATUS = { sem_chave: 503, indisponivel: 503, sem_caminho: 422, limite: 429 } as const;

// @desc    Calcular o caminho a pé entre dois pontos
// @route   POST /api/routes/segment
// @access  Privado
export const getSegment = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const { de, para } = req.body ?? {};
  if (!isPoint(de) || !isPoint(para)) {
    res.status(400).json({ sucesso: false, mensagem: 'Informe os dois pontos do trecho.' });
    return;
  }
  if (haversine([de.lng, de.lat], [para.lng, para.lat]) > MAX_SEGMENT_M) {
    res.status(400).json({ sucesso: false, mensagem: 'Os pontos estão longe demais. Marque um ponto mais perto.' });
    return;
  }
  if (isOverLimit(String(req.user?._id))) {
    res.status(429).json({ sucesso: false, codigo: 'limite', mensagem: 'Muitos pontos em pouco tempo. Aguarde um minuto.' });
    return;
  }

  try {
    res.status(200).json({ sucesso: true, dados: await fetchWalkingSegment(de, para) });
  } catch (error) {
    if (error instanceof RoutingError) {
      res.status(ROUTING_STATUS[error.codigo]).json({ sucesso: false, codigo: error.codigo, mensagem: error.message });
      return;
    }
    res.status(500).json({ sucesso: false, mensagem: 'Erro ao calcular o trecho.' });
  }
};

// @desc    Listar as rotas do usuário logado
// @route   GET /api/routes
// @access  Privado
export const getMyRoutes = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rotas = await SavedRoute.find({ dono: req.user?._id }).select('-trechos -pontos').sort({ updatedAt: -1 });
    res.status(200).json({ sucesso: true, total: rotas.length, dados: rotas });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao carregar as rotas.' });
  }
};

// @desc    Abrir uma rota própria
// @route   GET /api/routes/:id
// @access  Privado
export const getRouteById = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rota = await SavedRoute.findOne({ _id: req.params.id, dono: req.user?._id });
    if (!rota) {
      res.status(404).json({ sucesso: false, mensagem: 'Rota não encontrada.' });
      return;
    }
    res.status(200).json({ sucesso: true, dados: rota });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao carregar a rota.' });
  }
};

// @desc    Salvar uma rota nova
// @route   POST /api/routes
// @access  Privado
export const createRoute = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const parsed = parseRoute(req.body);
    if ('erro' in parsed) {
      res.status(400).json({ sucesso: false, mensagem: parsed.erro });
      return;
    }
    if ((await SavedRoute.countDocuments({ dono: req.user?._id })) >= MAX_ROUTES_PER_USER) {
      res.status(409).json({ sucesso: false, mensagem: `Você chegou ao limite de ${MAX_ROUTES_PER_USER} rotas. Exclua alguma para salvar.` });
      return;
    }
    const rota = await SavedRoute.create({ ...parsed.dados, dono: req.user?._id });
    res.status(201).json({ sucesso: true, mensagem: 'Rota salva!', dados: rota });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao salvar a rota.' });
  }
};

// @desc    Alterar uma rota própria
// @route   PUT /api/routes/:id
// @access  Privado
export const updateRoute = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const parsed = parseRoute(req.body);
    if ('erro' in parsed) {
      res.status(400).json({ sucesso: false, mensagem: parsed.erro });
      return;
    }
    const rota = await SavedRoute.findOneAndUpdate({ _id: req.params.id, dono: req.user?._id }, parsed.dados, {
      new: true,
    });
    if (!rota) {
      res.status(404).json({ sucesso: false, mensagem: 'Rota não encontrada.' });
      return;
    }
    res.status(200).json({ sucesso: true, mensagem: 'Rota atualizada!', dados: rota });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao salvar a rota.' });
  }
};

// @desc    Excluir uma rota própria
// @route   DELETE /api/routes/:id
// @access  Privado
export const deleteRoute = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rota = await SavedRoute.findOneAndDelete({ _id: req.params.id, dono: req.user?._id });
    if (!rota) {
      res.status(404).json({ sucesso: false, mensagem: 'Rota não encontrada.' });
      return;
    }
    res.status(200).json({ sucesso: true, mensagem: 'Rota excluída.' });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao excluir a rota.' });
  }
};
