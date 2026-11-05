// Texto do usuário vira literal numa busca: evita filtros maliciosos ou lentos.
export const escapeRegex = (value: unknown): string =>
  String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Página e limite sempre válidos, com teto para ninguém pedir a coleção inteira.
export const parsePagination = (
  query: { page?: unknown; limit?: unknown },
  defaultLimit = 20,
  maxLimit = 100
): { page: number; limit: number; skip: number } => {
  const page = Math.max(Math.floor(Number(query.page)) || 1, 1);
  const requested = Math.floor(Number(query.limit)) || defaultLimit;
  const limit = Math.min(Math.max(requested, 1), maxLimit);
  return { page, limit, skip: (page - 1) * limit };
};

// Links abertos pelo app só podem ser http ou https (nunca javascript: e afins).
export const isOptionalHttpUrl = (value?: string | null): boolean => {
  if (!value) return true;
  try {
    return ['http:', 'https:'].includes(new URL(value).protocol);
  } catch {
    return false;
  }
};

// Copia só os campos permitidos: o cliente não escolhe o que pode ser gravado.
export const pick = <T extends object>(source: T, fields: readonly string[]): Partial<T> => {
  const result: Record<string, unknown> = {};
  for (const field of fields) {
    if (field in source) result[field] = (source as Record<string, unknown>)[field];
  }
  return result as Partial<T>;
};
