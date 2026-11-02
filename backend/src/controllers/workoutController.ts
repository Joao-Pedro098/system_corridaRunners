import { Response } from 'express';
import { WorkoutPost } from '../models/WorkoutPost';
import { User } from '../models/User';
import { AuthenticatedRequest } from '../types';

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
      fotos: Array.isArray(fotos) ? fotos : [],
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
    const { page = 1, limit = 20, tipoTreino } = req.query;

    const filtro: any = {};
    if (tipoTreino) {
      filtro.tipoTreino = tipoTreino;
    }

    const pageNum = Number(page);
    const limitNum = Number(limit);
    const skip = (pageNum - 1) * limitNum;

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

    if (!texto || !texto.trim()) {
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
