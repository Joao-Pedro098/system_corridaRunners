import { Request, Response } from 'express';
import { NEWS_SOURCES } from '../config/newsSources';
import { News } from '../models/News';
import { NewsSource } from '../models/NewsSource';
import { syncNewsSources } from '../services/newsSyncService';
import { AuthenticatedRequest } from '../types';
import { parsePagination, pick } from '../utils/http';

// Campos que quem publica pode alterar. Autor e dados da fonte nunca vêm do cliente.
const NEWS_FIELDS = ['titulo', 'subtitulo', 'conteudo', 'categoria', 'imagemUrl', 'destaque'] as const;

const disabledSources = (): Promise<string[]> => NewsSource.find({ ativa: false }).distinct('fonteId');

// @desc    Listar as notícias, as próprias e as de fontes externas, das mais novas para as mais antigas
// @route   GET /api/news
// @access  Público
export const getAllNews = async (req: Request, res: Response): Promise<void> => {
  try {
    const { categoria, destaque } = req.query;
    const { page, limit, skip } = parsePagination(req.query, 60);
    const filtro: Record<string, unknown> = {
      oculta: { $ne: true },
      fonteId: { $nin: await disabledSources() },
    };

    if (typeof categoria === 'string') {
      filtro.categoria = categoria;
    }
    if (destaque !== undefined) {
      filtro.destaque = destaque === 'true';
    }

    // Matéria externa ordena pela data da fonte; notícia própria, pela data em que foi criada.
    // Pede um item a mais só para saber se existe outra página.
    const encontradas = await News.aggregate([
      { $match: filtro },
      { $addFields: { ordem: { $ifNull: ['$publicadoEm', '$createdAt'] } } },
      { $sort: { ordem: -1, _id: -1 } },
      { $skip: skip },
      { $limit: limit + 1 },
      { $project: { ordem: 0 } },
    ]);
    const noticias = encontradas.slice(0, limit);

    res.status(200).json({
      sucesso: true,
      total: noticias.length,
      pagina: page,
      temMais: encontradas.length > limit,
      dados: noticias,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar notícias.',
    });
  }
};

// @desc    Obter notícia por ID
// @route   GET /api/news/:id
// @access  Público
export const getNewsById = async (req: Request, res: Response): Promise<void> => {
  try {
    const noticia = await News.findById(req.params.id);
    const removida =
      noticia && (noticia.oculta || (noticia.fonteId && (await disabledSources()).includes(noticia.fonteId)));
    if (!noticia || removida) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Notícia não encontrada.',
      });
      return;
    }

    res.status(200).json({
      sucesso: true,
      dados: noticia,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao carregar notícia.',
    });
  }
};

// @desc    Criar nova notícia (Admin ou Organizador)
// @route   POST /api/news
// @access  Privado (Admin / Organizador)
export const createNews = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { titulo, subtitulo, conteudo, categoria, imagemUrl, destaque } = req.body;

    const novaNoticia = await News.create({
      titulo,
      subtitulo,
      conteudo,
      categoria: categoria || 'Novidade',
      imagemUrl,
      destaque: destaque || false,
      autor: req.user?.nome || 'Comunidade de Corridas',
      criadoPor: req.user?._id,
    });

    res.status(201).json({
      sucesso: true,
      mensagem: 'Notícia publicada com sucesso!',
      dados: novaNoticia,
    });
  } catch (error: any) {
    res.status(400).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao publicar notícia.',
    });
  }
};

// Acha a notícia que a pessoa pode alterar; se não puder seguir, já responde.
const findManagedNews = async (req: AuthenticatedRequest, res: Response) => {
  const noticia = await News.findById(req.params.id);
  if (!noticia) {
    res.status(404).json({ sucesso: false, mensagem: 'Notícia não encontrada.' });
    return null;
  }
  // Uma matéria externa apagada voltaria na próxima busca: ela só pode ser ocultada.
  if (noticia.linkOriginal) {
    res.status(403).json({ sucesso: false, mensagem: 'Matérias de outros sites só podem ser ocultadas.' });
    return null;
  }
  const isOwner = noticia.criadoPor?.toString() === req.user?._id.toString();
  if (req.user?.tipo !== 'admin' && !isOwner) {
    res.status(403).json({ sucesso: false, mensagem: 'Sem permissão para alterar esta notícia.' });
    return null;
  }
  return noticia;
};

// @desc    Editar uma notícia
// @route   PUT /api/news/:id
// @access  Privado (quem publicou ou Admin)
export const updateNews = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const noticia = await findManagedNews(req, res);
    if (!noticia) return;

    const alteracoes: any = pick(req.body ?? {}, NEWS_FIELDS);
    for (const campo of ['titulo', 'conteudo']) {
      if (campo in alteracoes && (typeof alteracoes[campo] !== 'string' || !alteracoes[campo].trim())) {
        res.status(400).json({ sucesso: false, mensagem: 'Informe o título e o conteúdo da notícia.' });
        return;
      }
    }
    if ('conteudo' in alteracoes) alteracoes.conteudo = alteracoes.conteudo.trim();

    noticia.set(alteracoes);
    await noticia.save();
    res.status(200).json({ sucesso: true, mensagem: 'Notícia atualizada!', dados: noticia });
  } catch (error: any) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ sucesso: false, mensagem: error.message || 'Erro ao atualizar notícia.' });
  }
};

// @desc    Excluir uma notícia
// @route   DELETE /api/news/:id
// @access  Privado (quem publicou ou Admin)
export const deleteNews = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const noticia = await findManagedNews(req, res);
    if (!noticia) return;

    await noticia.deleteOne();
    res.status(200).json({ sucesso: true, mensagem: 'Notícia excluída.' });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao excluir notícia.' });
  }
};

// @desc    Ocultar ou mostrar de novo uma notícia
// @route   PUT /api/news/:id/visibility
// @access  Privado (Admin)
export const setNewsVisibility = async (req: Request, res: Response): Promise<void> => {
  try {
    if (typeof req.body?.oculta !== 'boolean') {
      res.status(400).json({ sucesso: false, mensagem: 'Informe se a notícia fica oculta.' });
      return;
    }
    const noticia = await News.findByIdAndUpdate(req.params.id, { oculta: req.body.oculta }, { new: true });
    if (!noticia) {
      res.status(404).json({ sucesso: false, mensagem: 'Notícia não encontrada.' });
      return;
    }
    res.status(200).json({ sucesso: true, dados: noticia });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao alterar a notícia.' });
  }
};

// @desc    Listar as notícias ocultadas
// @route   GET /api/news/hidden
// @access  Privado (Admin)
export const getHiddenNews = async (_req: Request, res: Response): Promise<void> => {
  try {
    const noticias = await News.find({ oculta: true }).sort({ updatedAt: -1 }).limit(100);
    res.status(200).json({ sucesso: true, total: noticias.length, dados: noticias });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao carregar notícias.' });
  }
};

const describeSources = async () => {
  const states = await NewsSource.find({ fonteId: { $in: NEWS_SOURCES.map((s) => s.id) } }).lean();
  return Promise.all(
    NEWS_SOURCES.map(async ({ id, nome, site }) => {
      const state = states.find((s) => s.fonteId === id);
      return {
        id,
        nome,
        site,
        ativa: state?.ativa ?? true,
        ultimaBusca: state?.ultimaBusca ?? null,
        ultimoErro: state?.ultimoErro ?? null,
        ultimasNovas: state?.ultimasNovas ?? 0,
        totalMaterias: await News.countDocuments({ fonteId: id, oculta: { $ne: true } }),
      };
    })
  );
};

// @desc    Listar as fontes externas e o estado de cada uma
// @route   GET /api/news/sources
// @access  Privado (Admin)
export const getNewsSources = async (_req: Request, res: Response): Promise<void> => {
  try {
    res.status(200).json({ sucesso: true, dados: await describeSources() });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao carregar as fontes.' });
  }
};

// @desc    Ligar ou desligar uma fonte; desligada, suas matérias somem do app e ela não é mais lida
// @route   PUT /api/news/sources/:id
// @access  Privado (Admin)
export const setNewsSourceActive = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!NEWS_SOURCES.some((source) => source.id === req.params.id)) {
      res.status(404).json({ sucesso: false, mensagem: 'Fonte não encontrada.' });
      return;
    }
    if (typeof req.body?.ativa !== 'boolean') {
      res.status(400).json({ sucesso: false, mensagem: 'Informe se a fonte fica ativa.' });
      return;
    }
    await NewsSource.updateOne({ fonteId: req.params.id }, { $set: { ativa: req.body.ativa } }, { upsert: true });
    res.status(200).json({ sucesso: true, dados: await describeSources() });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao alterar a fonte.' });
  }
};

// @desc    Buscar novas matérias agora
// @route   POST /api/news/sources/sync
// @access  Privado (Admin)
export const syncNews = async (_req: Request, res: Response): Promise<void> => {
  try {
    const resultados = await syncNewsSources({ force: true });
    res.status(200).json({
      sucesso: true,
      novas: resultados.reduce((total, resultado) => total + resultado.novas, 0),
      dados: await describeSources(),
    });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao buscar notícias.' });
  }
};
