// Em produção o segredo é obrigatório: com um valor conhecido, qualquer pessoa
// conseguiria forjar um token e entrar como outro usuário.
export const getJwtSecret = (): string => {
  const secret = process.env.JWT_SECRET;
  if (secret) return secret;
  if (process.env.NODE_ENV === 'production') {
    throw new Error('A variável JWT_SECRET não foi definida.');
  }
  return 'segredo-apenas-para-desenvolvimento';
};
