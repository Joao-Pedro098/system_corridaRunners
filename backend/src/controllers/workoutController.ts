import { Response } from 'express';
import { WorkoutPost } from '../models/WorkoutPost';
import { User } from '../models/User';
import { AuthenticatedRequest } from '../types';
import { notify, removeNotifications } from '../services/notificationService';
import { parsePagination } from '../utils/http';
import {
  MAX_WORKOUT_PHOTOS,
  detectImageExtension,
  isOwnPhotoPath,
  removePhotos,
  savePhoto,
} from '../middlewares/uploadMiddleware';

// Função utilitária para formatar segundos em HH:MM:SS
const formatarTempo = (totalSegundos: number): string => {
  const horas = Math.floor(totalSegundos / 3600);
  const minutos = Math.floor((totalSegundos % 3600) / 60);
  const segundos = Math.floor(totalSegundos % 60);

  const pad = (n: number) => n.toString().padStart(2, '0');
  if (horas > 0) {
    return `${pad(horas)}:${pad(minutos)}:${pad(segundos)}`;
  }
  return `00:${pad(minutos)}:${pad(segundos)}`;
};

// Função utilitária para calcular pace médio (minutos e segundos por km)
const calcularPace = (distanciaKm: number, totalSegundos: number): string => {
  if (distanciaKm <= 0 || totalSegundos <= 0) return '00:00 min/km';
  const segundosPorKm = totalSegundos / distanciaKm;
  const minutos = Math.floor(segundosPorKm / 60);
  const segundos = Math.round(segundosPorKm % 60);
  return `${minutos.toString().padStart(2, '0')}:${segundos.toString().padStart(2, '0')} min/km`;
};

// @desc    Enviar fotos de um treino (retorna os caminhos para usar ao publicar)
// @route   POST /api/workouts/photos
// @access  Privado (requer login)
export const uploadWorkoutPhotos = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const files = (req.files as Express.Multer.File[] | undefined) ?? [];
    if (files.length === 0) {
      res.status(400).json({ sucesso: false, mensagem: 'Nenhuma foto enviada.' });
      return;
    }

    // Valida todas antes de gravar, para não deixar arquivos soltos no disco.
    const extensions = files.map((file) => detectImageExtension(file.buffer));
    if (extensions.includes(null)) {
      res.status(400).json({ sucesso: false, mensagem: 'Envie fotos em JPG, PNG ou WebP.' });
      return;
    }

    const userId = req.user._id.toString();
    const paths = await Promise.all(
      files.map((file, i) => savePhoto(file.buffer, extensions[i] as string, userId))
    );

    res.status(201).json({ sucesso: true, dados: paths });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao enviar fotos.',
    });
  }
};

// @desc    Criar novo treino/publicação na comunidade
// @route   POST /api/workouts
// @access  Privado (requer login)
export const createWorkout = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const {
      titulo,
      descricao,
      tipoTreino,
      distanciaKm,
      duracaoSegundos,
      altimetria,
      sensacaoEsforco,
      fotos,
      dataTreino,
    } = req.body;

    if (!titulo || !distanciaKm || !duracaoSegundos) {
      res.status(400).json({
        sucesso: false,
        mensagem: 'Título, distância (km) e duração em segundos são obrigatórios.',
      });
      return;
    }

    const listaFotos: unknown[] = Array.isArray(fotos) ? fotos : [];
    if (listaFotos.length > MAX_WORKOUT_PHOTOS) {
      res.status(400).json({
        sucesso: false,
        mensagem: `Envie no máximo ${MAX_WORKOUT_PHOTOS} fotos por treino.`,
      });
      return;
    }
    // Aceita apenas fotos enviadas pelo próprio atleta, nunca links externos.
    if (!listaFotos.every((foto) => isOwnPhotoPath(foto, req.user!._id.toString()))) {
      res.status(400).json({ sucesso: false, mensagem: 'Foto inválida.' });
      return;
    }

    const distNum = Number(distanciaKm);
    const duracaoNum = Number(duracaoSegundos);

    const tempoFormatado = formatarTempo(duracaoNum);
    const paceMedio = calcularPace(distNum, duracaoNum);

    const novoTreino = await WorkoutPost.create({
      atleta: req.user._id,
      titulo: titulo.trim(),
      descricao: descricao ? descricao.trim() : '',
      tipoTreino: tipoTreino || 'rodagem',
      distanciaKm: distNum,
      duracaoSegundos: duracaoNum,
      tempoFormatado,
      paceMedio,
      altimetria: Number(altimetria) || 0,
      sensacaoEsforco: sensacaoEsforco || 'moderado',
      fotos: listaFotos as string[],
      dataTreino: dataTreino ? new Date(dataTreino) : new Date(),
    });

    // Atualiza estatísticas acumuladas do atleta
    await User.findByIdAndUpdate(req.user._id, {
      $inc: {
        'estatisticas.totalKm': distNum,
        'estatisticas.totalTreinos': 1,
        'estatisticas.tempoTotalSegundos': duracaoNum,
      },
    });

    const treinoPopulada = await WorkoutPost.findById(novoTreino._id).populate(
      'atleta',
      'nome avatarUrl cidade tipo'
    );

    res.status(201).json({
      sucesso: true,
      mensagem: 'Treino publicado com sucesso!',
      dados: treinoPopulada,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao publicar treino.',
    });
  }
};

// @desc    Obter feed da comunidade (treinos recentes com paginação)
// @route   GET /api/workouts/feed
// @access  Público ou Privado
export const getFeed = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { tipoTreino } = req.query;

    const filtro: any = {};
    if (typeof tipoTreino === 'string') {
      filtro.tipoTreino = tipoTreino;
    }

    const { page: pageNum, limit: limitNum, skip } = parsePagination(req.query);

    const [treinos, total] = await Promise.all([
      WorkoutPost.find(filtro)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .populate('atleta', 'nome avatarUrl cidade tipo')
        .populate('comentarios.autor', 'nome avatarUrl'),
      WorkoutPost.countDocuments(filtro),
    ]);

    res.status(200).json({
      sucesso: true,
      total,
      pagina: pageNum,
      paginasTotal: Math.ceil(total / limitNum),
      dados: treinos,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar o feed.',
    });
  }
};

// @desc    Obter um treino pelo id
// @route   GET /api/workouts/:id
// @access  Público
export const getWorkoutById = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const treino = await WorkoutPost.findById(req.params.id)
      .populate('atleta', 'nome avatarUrl cidade tipo')
      .populate('comentarios.autor', 'nome avatarUrl');

    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }

    res.status(200).json({ sucesso: true, dados: treino });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar treino.',
    });
  }
};

// @desc    Obter treinos de um atleta específico (Perfil)
// @route   GET /api/workouts/user/:userId
// @access  Público
export const getWorkoutsByUserId = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;

    const treinos = await WorkoutPost.find({ atleta: userId })
      .sort({ dataTreino: -1 })
      .populate('atleta', 'nome avatarUrl cidade tipo')
      .populate('comentarios.autor', 'nome avatarUrl');

    res.status(200).json({
      sucesso: true,
      total: treinos.length,
      dados: treinos,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar treinos do atleta.',
    });
  }
};

// @desc    Curtir / Descurtir um treino (Toggle Like / Kudos)
// @route   POST /api/workouts/:id/like
// @access  Privado
export const toggleLike = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const { id } = req.params;
    const treino = await WorkoutPost.findById(id);

    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }

    const userIdStr = req.user._id.toString();
    const jaCurtiu = treino.curtidas.some((uid) => uid.toString() === userIdStr);

    if (jaCurtiu) {
      // Remove curtida
      treino.curtidas = treino.curtidas.filter((uid) => uid.toString() !== userIdStr);
    } else {
      // Adiciona curtida
      treino.curtidas.push(req.user._id);
    }

    await treino.save();

    const aviso = { destinatario: treino.atleta, autor: req.user._id, tipo: 'curtida' as const, treino: treino._id };
    if (jaCurtiu) {
      await removeNotifications(aviso);
    } else {
      await notify(aviso);
    }

    res.status(200).json({
      sucesso: true,
      curtido: !jaCurtiu,
      totalCurtidas: treino.curtidas.length,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao curtir treino.',
    });
  }
};

// @desc    Adicionar comentário a um treino
// @route   POST /api/workouts/:id/comments
// @access  Privado
export const addComment = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const { id } = req.params;
    const { texto } = req.body;

    if (typeof texto !== 'string' || !texto.trim()) {
      res.status(400).json({ sucesso: false, mensagem: 'O comentário não pode ser vazio.' });
      return;
    }

    const treino = await WorkoutPost.findById(id);
    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }

    treino.comentarios.push({
      autor: req.user._id,
      texto: texto.trim(),
      createdAt: new Date(),
    });

    await treino.save();

    await notify({
      destinatario: treino.atleta,
      autor: req.user._id,
      tipo: 'comentario',
      treino: treino._id,
      comentario: treino.comentarios[treino.comentarios.length - 1]._id,
    });

    const treinoAtualizado = await WorkoutPost.findById(id).populate(
      'comentarios.autor',
      'nome avatarUrl'
    );

    res.status(201).json({
      sucesso: true,
      mensagem: 'Comentário enviado!',
      dados: treinoAtualizado?.comentarios,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao adicionar comentário.',
    });
  }
};

// @desc    Excluir um comentário
// @route   DELETE /api/workouts/:id/comments/:commentId
// @access  Privado (autor do comentário, dono do treino ou admin)
export const deleteComment = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const { id, commentId } = req.params;
    const treino = await WorkoutPost.findById(id);
    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }

    const index = treino.comentarios.findIndex((c) => c._id?.toString() === commentId);
    if (index === -1) {
      res.status(404).json({ sucesso: false, mensagem: 'Comentário não encontrado.' });
      return;
    }

    const userId = req.user._id.toString();
    const podeExcluir =
      treino.comentarios[index].autor.toString() === userId ||
      treino.atleta.toString() === userId ||
      req.user.tipo === 'admin';
    if (!podeExcluir) {
      res.status(403).json({ sucesso: false, mensagem: 'Sem permissão para excluir este comentário.' });
      return;
    }

    const comentarioId = treino.comentarios[index]._id;
    treino.comentarios.splice(index, 1);
    await treino.save();
    await removeNotifications({ comentario: comentarioId });

    const treinoAtualizado = await WorkoutPost.findById(id).populate(
      'comentarios.autor',
      'nome avatarUrl'
    );

    res.status(200).json({
      sucesso: true,
      mensagem: 'Comentário excluído.',
      dados: treinoAtualizado?.comentarios,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao excluir comentário.',
    });
  }
};

// Confere só o que veio no pedido e devolve uma mensagem que o atleta entenda.
const validateWorkoutChanges = (body: any): string | null => {
  const isNumberFrom = (value: unknown, min: number) => Number.isFinite(Number(value)) && Number(value) >= min;

  if ('titulo' in body && (typeof body.titulo !== 'string' || !body.titulo.trim())) return 'Dê um título ao treino.';
  if ('descricao' in body && typeof body.descricao !== 'string') return 'Descrição inválida.';
  if ('distanciaKm' in body && !isNumberFrom(body.distanciaKm, 0.1)) return 'Informe uma distância válida.';
  if ('duracaoSegundos' in body && !isNumberFrom(body.duracaoSegundos, 1)) return 'Informe o tempo do treino.';
  if ('altimetria' in body && !isNumberFrom(body.altimetria, 0)) return 'A elevação não pode ser negativa.';
  if ('dataTreino' in body && Number.isNaN(new Date(body.dataTreino).getTime())) return 'Informe uma data válida.';
  return null;
};

// @desc    Editar um treino e ajustar os totais do atleta
// @route   PUT /api/workouts/:id
// @access  Privado (apenas quem publicou)
export const updateWorkout = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const treino = await WorkoutPost.findById(req.params.id);
    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }
    if (treino.atleta.toString() !== req.user._id.toString()) {
      res.status(403).json({ sucesso: false, mensagem: 'Só quem publicou pode editar este treino.' });
      return;
    }

    const body = req.body ?? {};
    const erro = validateWorkoutChanges(body);
    if (erro) {
      res.status(400).json({ sucesso: false, mensagem: erro });
      return;
    }

    const fotosAntigas = [...treino.fotos];
    if ('fotos' in body) {
      if (!Array.isArray(body.fotos) || body.fotos.length > MAX_WORKOUT_PHOTOS) {
        res.status(400).json({ sucesso: false, mensagem: `Envie no máximo ${MAX_WORKOUT_PHOTOS} fotos por treino.` });
        return;
      }
      const userId = req.user._id.toString();
      if (!body.fotos.every((foto: unknown) => fotosAntigas.includes(foto as string) || isOwnPhotoPath(foto, userId))) {
        res.status(400).json({ sucesso: false, mensagem: 'Foto inválida.' });
        return;
      }
      treino.fotos = body.fotos;
    }

    const kmAntigo = treino.distanciaKm;
    const segundosAntigos = treino.duracaoSegundos;

    if ('titulo' in body) treino.titulo = body.titulo.trim();
    if ('descricao' in body) treino.descricao = body.descricao.trim();
    if ('tipoTreino' in body) treino.tipoTreino = body.tipoTreino;
    if ('sensacaoEsforco' in body) treino.sensacaoEsforco = body.sensacaoEsforco;
    if ('altimetria' in body) treino.altimetria = Number(body.altimetria);
    if ('dataTreino' in body) treino.dataTreino = new Date(body.dataTreino);
    if ('distanciaKm' in body) treino.distanciaKm = Number(body.distanciaKm);
    if ('duracaoSegundos' in body) treino.duracaoSegundos = Number(body.duracaoSegundos);
    treino.tempoFormatado = formatarTempo(treino.duracaoSegundos);
    treino.paceMedio = calcularPace(treino.distanciaKm, treino.duracaoSegundos);

    await treino.save();

    // Soma só a diferença: curtidas e comentários não mudam os totais.
    await User.findByIdAndUpdate(req.user._id, {
      $inc: {
        'estatisticas.totalKm': treino.distanciaKm - kmAntigo,
        'estatisticas.tempoTotalSegundos': treino.duracaoSegundos - segundosAntigos,
      },
    });
    await removePhotos(fotosAntigas.filter((foto) => !treino.fotos.includes(foto)));

    const atualizado = await WorkoutPost.findById(treino._id)
      .populate('atleta', 'nome avatarUrl cidade tipo')
      .populate('comentarios.autor', 'nome avatarUrl');

    res.status(200).json({ sucesso: true, mensagem: 'Treino atualizado!', dados: atualizado });
  } catch (error: any) {
    if (error.name === 'ValidationError') {
      const primeira: any = Object.values(error.errors)[0];
      res.status(400).json({ sucesso: false, mensagem: primeira?.message || 'Dados inválidos.' });
      return;
    }
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao atualizar treino.' });
  }
};

// @desc    Excluir um treino
// @route   DELETE /api/workouts/:id
// @access  Privado (apenas o autor ou admin)
export const deleteWorkout = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado.' });
      return;
    }

    const { id } = req.params;
    const treino = await WorkoutPost.findById(id);

    if (!treino) {
      res.status(404).json({ sucesso: false, mensagem: 'Treino não encontrado.' });
      return;
    }

    // Apenas o autor ou admin pode excluir
    if (treino.atleta.toString() !== req.user._id.toString() && req.user.tipo !== 'admin') {
      res.status(403).json({ sucesso: false, mensagem: 'Sem permissão para excluir este treino.' });
      return;
    }

    // Deduz das estatísticas do atleta
    await User.findByIdAndUpdate(treino.atleta, {
      $inc: {
        'estatisticas.totalKm': -treino.distanciaKm,
        'estatisticas.totalTreinos': -1,
        'estatisticas.tempoTotalSegundos': -treino.duracaoSegundos,
      },
    });

    await WorkoutPost.findByIdAndDelete(id);
    await removePhotos(treino.fotos);
    await removeNotifications({ treino: treino._id });

    res.status(200).json({
      sucesso: true,
      mensagem: 'Treino excluído com sucesso.',
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao excluir treino.',
    });
  }
};
