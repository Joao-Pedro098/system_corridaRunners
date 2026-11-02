import { Request, Response } from 'express';
import { Race } from '../models/Race';
import { AuthenticatedRequest } from '../types';

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
      page = 1,
      limit = 20,
    } = req.query;

    const filtro: any = {};

    // Filtro por cidade (case-insensitive)
    if (cidade) {
      filtro['local.cidade'] = { $regex: String(cidade), $options: 'i' };
    }

    // Filtro por estado
    if (estado) {
      filtro['local.estado'] = { $regex: String(estado), $options: 'i' };
    }

    // Filtro por distância em km (ex: 5, 10, 21, 42)
    if (distancia) {
      filtro['distancias.distanciaKm'] = Number(distancia);
    }

    // Filtro por status
    if (status) {
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
        { nome: { $regex: String(busca), $options: 'i' } },
        { descricao: { $regex: String(busca), $options: 'i' } },
        { 'local.cidade': { $regex: String(busca), $options: 'i' } },
      ];
    }

    const pageNum = Number(page);
    const limitNum = Number(limit);
    const skip = (pageNum - 1) * limitNum;

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

// @desc    Criar nova corrida (Organizador ou Admin)
// @route   POST /api/races
// @access  Privado (Organizador / Admin)
export const createRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const dadosCorrida = req.body;

    // Se o organizador não for informado, usa o nome do usuário logado
    if (!dadosCorrida.organizador?.nome && req.user) {
      dadosCorrida.organizador = {
        nome: req.user.nome,
        contato: req.user.telefone || req.user.email,
        ...dadosCorrida.organizador,
      };
    }

    const novaCorrida = await Race.create(dadosCorrida);

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
// @access  Privado (Organizador / Admin)
export const updateRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const corridaAtualizada = await Race.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    if (!corridaAtualizada) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Corrida não encontrada para atualização.',
      });
      return;
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
// @access  Privado (Admin / Organizador)
export const deleteRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const corrida = await Race.findByIdAndDelete(req.params.id);

    if (!corrida) {
      res.status(404).json({
        sucesso: false,
        mensagem: 'Corrida não encontrada.',
      });
      return;
    }

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
