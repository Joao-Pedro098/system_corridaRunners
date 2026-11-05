import { Request, Response } from 'express';
import { Race } from '../models/Race';
import { User } from '../models/User';
import { detectImageExtension, isOwnPhotoPath, removePhotos, savePhoto } from '../middlewares/uploadMiddleware';
import { AuthenticatedRequest, IRace } from '../types';
import { escapeRegex, parsePagination, pick } from '../utils/http';

// Campos que quem cadastra pode preencher. Dono e confirmados nunca vêm do cliente.
const RACE_FIELDS = [
  'nome',
  'descricao',
  'data',
  'horarioLargada',
  'local',
  'distancias',
  'linkInscricao',
  'preco',
  'retiradaKit',
  'regulamentoUrl',
  'bannerUrl',
  'posCorrida',
  'organizador',
  'status',
] as const;

const canManage = (req: AuthenticatedRequest, race: IRace): boolean =>
  req.user?.tipo === 'admin' || race.criadoPor?.toString() === req.user?._id.toString();

// @desc    Listar todas as corridas com filtros avançados
// @route   GET /api/races
// @access  Público
export const getAllRaces = async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      cidade,
      estado,
      distancia,
      mes,
      ano,
      status,
      busca,
    } = req.query;

    const filtro: any = {};

    // Filtro por cidade (case-insensitive)
    if (cidade) {
      filtro['local.cidade'] = { $regex: escapeRegex(cidade), $options: 'i' };
    }

    // Filtro por estado
    if (estado) {
      filtro['local.estado'] = { $regex: escapeRegex(estado), $options: 'i' };
    }

    // Filtro por distância em km (ex: 5, 10, 21, 42)
    if (distancia) {
      filtro['distancias.distanciaKm'] = Number(distancia);
    }

    // Filtro por status
    if (typeof status === 'string') {
      filtro.status = status;
    }

    // Filtro por data (Mês e Ano)
    if (mes && ano) {
      const mesNum = Number(mes) - 1; // 0-indexed em JS
      const anoNum = Number(ano);
      const dataInicio = new Date(anoNum, mesNum, 1);
      const dataFim = new Date(anoNum, mesNum + 1, 0, 23, 59, 59, 999);
      filtro.data = { $gte: dataInicio, $lte: dataFim };
    } else if (ano) {
      const anoNum = Number(ano);
      filtro.data = {
        $gte: new Date(anoNum, 0, 1),
        $lte: new Date(anoNum, 11, 31, 23, 59, 59, 999),
      };
    }

    // Busca textual por nome ou descrição
    if (busca) {
      filtro.$or = [
        { nome: { $regex: escapeRegex(busca), $options: 'i' } },
        { descricao: { $regex: escapeRegex(busca), $options: 'i' } },
        { 'local.cidade': { $regex: escapeRegex(busca), $options: 'i' } },
      ];
    }

    const { page: pageNum, limit: limitNum, skip } = parsePagination(req.query);

    const [corridas, total] = await Promise.all([
      Race.find(filtro)
        .sort({ data: 1 }) // Mais próximas primeiro
        .skip(skip)
        .limit(limitNum)
        .populate('participantesConfirmados', 'nome avatarUrl cidade'),
      Race.countDocuments(filtro),
    ]);

    res.status(200).json({
      sucesso: true,
      total,
      pagina: pageNum,
      paginasTotal: Math.ceil(total / limitNum),
      dados: corridas,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao buscar corridas.',
    });
  }
};

// @desc    Obter detalhes de uma corrida por ID
// @route   GET /api/races/:id
// @access  Público
export const getRaceById = async (req: Request, res: Response): Promise<void> => {
  try {
    const corrida = await Race.findById(req.params.id)
      .populate('participantesConfirmados', 'nome avatarUrl cidade');

    if (!corrida) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Corrida não encontrada.',
      });
      return;
    }

    res.status(200).json({
      sucesso: true,
      dados: corrida,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar detalhes da corrida.',
    });
  }
};

// Confere os dados antes de gravar e devolve uma mensagem que o organizador entenda.
const validateRaceInput = (body: any, creating: boolean): string | null => {
  const has = (field: string) => creating || field in body;

  if (has('nome') && (typeof body.nome !== 'string' || body.nome.trim().length < 3)) {
    return 'Informe o nome da prova, com pelo menos 3 letras.';
  }
  if (has('data')) {
    const data = new Date(body.data);
    if (!body.data || Number.isNaN(data.getTime())) return 'Informe uma data válida.';
    const hoje = new Date();
    hoje.setHours(0, 0, 0, 0);
    if (creating && data < hoje) return 'A data da prova não pode estar no passado.';
  }
  if (has('local')) {
    const { cidade, estado } = body.local ?? {};
    if (typeof cidade !== 'string' || !cidade.trim()) return 'Informe a cidade da prova.';
    if (typeof estado !== 'string' || !/^[A-Za-z]{2}$/.test(estado.trim())) return 'Informe a UF com 2 letras.';
  }
  if (has('distancias')) {
    const lista = body.distancias;
    if (!Array.isArray(lista) || lista.length === 0) return 'Informe ao menos uma distância.';
    const kms = lista.map((d: any) => Number(d?.distanciaKm));
    if (kms.some((km) => !(km > 0 && km <= 500))) return 'Use distâncias entre 0,1 e 500 km.';
    if (new Set(kms).size !== kms.length) return 'Há distâncias repetidas.';
    if (lista.some((d: any) => d?.altimetria !== undefined && !(Number(d.altimetria) >= 0))) {
      return 'A elevação não pode ser negativa.';
    }
  }
  if (body.horarioLargada && !/^([01]\d|2[0-3]):[0-5]\d$/.test(String(body.horarioLargada))) {
    return 'Use o horário no formato 06:00.';
  }
  return null;
};

// Só aceita como capa uma imagem enviada pela própria pessoa, ou manter a atual.
const isAllowedCover = (value: unknown, userId: string, current?: string): boolean =>
  !value || value === current || isOwnPhotoPath(value, userId, 'races');

// @desc    Enviar a imagem de capa de uma prova
// @route   POST /api/races/cover
// @access  Privado (Organizador / Admin)
export const uploadRaceCover = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const file = req.file;
    if (!file) {
      res.status(400).json({ sucesso: false, mensagem: 'Nenhuma imagem enviada.' });
      return;
    }
    const extension = detectImageExtension(file.buffer);
    if (!extension) {
      res.status(400).json({ sucesso: false, mensagem: 'Envie a capa em JPG, PNG ou WebP.' });
      return;
    }
    const caminho = await savePhoto(file.buffer, extension, req.user!._id.toString(), 'races');
    res.status(201).json({ sucesso: true, dados: caminho });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao enviar a capa.' });
  }
};

// @desc    Listar as provas cadastradas pelo usuário logado
// @route   GET /api/races/mine
// @access  Privado (Organizador / Admin)
export const getMyRaces = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const corridas = await Race.find({ criadoPor: req.user!._id }).sort({ data: 1 });
    res.status(200).json({ sucesso: true, total: corridas.length, dados: corridas });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao buscar suas provas.' });
  }
};

// @desc    Criar nova corrida (Organizador ou Admin)
// @route   POST /api/races
// @access  Privado (Organizador / Admin)
export const createRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const dadosCorrida: any = pick(req.body, RACE_FIELDS);

    const erro = validateRaceInput(dadosCorrida, true);
    if (erro) {
      res.status(400).json({ sucesso: false, mensagem: erro });
      return;
    }
    if (!isAllowedCover(dadosCorrida.bannerUrl, req.user!._id.toString())) {
      res.status(400).json({ sucesso: false, mensagem: 'Capa inválida.' });
      return;
    }

    // Se o organizador não for informado, usa o nome do usuário logado
    if (!dadosCorrida.organizador?.nome && req.user) {
      dadosCorrida.organizador = {
        contato: req.user.telefone || req.user.email,
        ...dadosCorrida.organizador,
        nome: req.user.nome,
      };
    }

    const novaCorrida = await Race.create({ ...dadosCorrida, criadoPor: req.user?._id });

    res.status(201).json({
      sucesso: true,
      mensagem: 'Corrida cadastrada com sucesso!',
      dados: novaCorrida,
    });
  } catch (error: any) {
    res.status(400).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao criar corrida.',
    });
  }
};

// @desc    Atualizar informações de uma corrida
// @route   PUT /api/races/:id
// @access  Privado (quem criou a prova ou Admin)
export const updateRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const corrida = await Race.findById(req.params.id);

    if (!corrida) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Corrida não encontrada para atualização.',
      });
      return;
    }

    if (!canManage(req, corrida)) {
      res.status(403).json({ sucesso: false, mensagem: 'Sem permissão para alterar esta corrida.' });
      return;
    }

    const alteracoes: any = pick(req.body, RACE_FIELDS);
    const erro = validateRaceInput(alteracoes, false);
    if (erro) {
      res.status(400).json({ sucesso: false, mensagem: erro });
      return;
    }
    if (
      'bannerUrl' in alteracoes &&
      !isAllowedCover(alteracoes.bannerUrl, req.user!._id.toString(), corrida.bannerUrl)
    ) {
      res.status(400).json({ sucesso: false, mensagem: 'Capa inválida.' });
      return;
    }

    // O formulário não conhece o percurso: mantém o que já estava em cada distância.
    if (alteracoes.distancias) {
      const anteriores = (corrida.toObject().distancias ?? []) as any[];
      alteracoes.distancias = alteracoes.distancias.map((nova: any) => {
        const antiga = anteriores.find((d) => d.distanciaKm === Number(nova.distanciaKm));
        return {
          ...(antiga?.rotaGeoJSON?.type ? { rotaGeoJSON: antiga.rotaGeoJSON } : {}),
          ...(antiga?.arquivoPercursoUrl ? { arquivoPercursoUrl: antiga.arquivoPercursoUrl } : {}),
          ...nova,
        };
      });
    }

    const capaAnterior = corrida.bannerUrl;
    corrida.set(alteracoes);
    const corridaAtualizada = await corrida.save();

    if (capaAnterior && capaAnterior !== corridaAtualizada.bannerUrl) {
      await removePhotos([capaAnterior]);
    }

    res.status(200).json({
      sucesso: true,
      mensagem: 'Corrida atualizada com sucesso!',
      dados: corridaAtualizada,
    });
  } catch (error: any) {
    res.status(400).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao atualizar corrida.',
    });
  }
};

// @desc    Excluir corrida
// @route   DELETE /api/races/:id
// @access  Privado (quem criou a prova ou Admin)
export const deleteRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const corrida = await Race.findById(req.params.id);

    if (!corrida) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Corrida não encontrada.',
      });
      return;
    }

    if (!canManage(req, corrida)) {
      res.status(403).json({ sucesso: false, mensagem: 'Sem permissão para excluir esta corrida.' });
      return;
    }

    await corrida.deleteOne();
    // A prova também sai da lista de salvas de quem a favoritou.
    await User.updateMany({ corridasSalvas: corrida._id }, { $pull: { corridasSalvas: corrida._id } });
    if (corrida.bannerUrl) await removePhotos([corrida.bannerUrl]);

    res.status(200).json({
      sucesso: true,
      mensagem: 'Corrida excluída com sucesso.',
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao excluir corrida.',
    });
  }
};

// @desc    Obter corridas em destaque para o banner/carrossel
// @route   GET /api/races/featured
// @access  Público
export const getFeaturedRaces = async (req: Request, res: Response): Promise<void> => {
  try {
    const hoje = new Date();
    const destaques = await Race.find({
      data: { $gte: hoje },
      bannerUrl: { $exists: true, $ne: '' },
    })
      .sort({ data: 1 })
      .limit(5);

    res.status(200).json({
      sucesso: true,
      dados: destaques,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao buscar destaques.',
    });
  }
};
