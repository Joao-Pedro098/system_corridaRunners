import { Request, Response } from 'express';
import { News } from '../models/News';
import { AuthenticatedRequest } from '../types';

// @desc    Listar todas as notícias esportivas
// @route   GET /api/news
// @access  Público
export const getAllNews = async (req: Request, res: Response): Promise<void> => {
  try {
    const { categoria, destaque } = req.query;
    const filtro: any = {};

    if (categoria) {
      filtro.categoria = categoria;
    }
    if (destaque !== undefined) {
      filtro.destaque = destaque === 'true';
    }

    const noticias = await News.find(filtro).sort({ createdAt: -1 });

    res.status(200).json({
      sucesso: true,
      total: noticias.length,
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
    if (!noticia) {
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
