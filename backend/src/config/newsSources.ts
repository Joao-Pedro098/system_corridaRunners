export interface NewsFeed {
  url: string;
  /** Feed de assuntos gerais: só entram matérias cujo título seja claramente sobre corrida. */
  apenasSobreCorrida?: boolean;
}

export interface NewsSourceConfig {
  id: string;
  nome: string;
  site: string;
  /** Único domínio de onde o coletor aceita ler feeds e matérias desta fonte. */
  host: string;
  feeds: NewsFeed[];
  /** O site recusa a exibição das imagens fora dele: a matéria entra sem capa, sem contornar o bloqueio. */
  semCapa?: boolean;
}

export const NEWS_SOURCES: NewsSourceConfig[] = [
  {
    id: 'webrun',
    nome: 'Webrun',
    site: 'https://webrun.com.br',
    host: 'webrun.com.br',
    feeds: [{ url: 'https://webrun.com.br/feed/' }],
  },
  {
    id: 'contra-relogio',
    nome: 'Contra-Relógio',
    site: 'https://contrarelogio.com.br',
    host: 'contrarelogio.com.br',
    feeds: [{ url: 'https://contrarelogio.com.br/feed/' }],
    semCapa: true,
  },
  {
    id: 'correio-de-carajas',
    nome: 'Correio de Carajás',
    site: 'https://correiodecarajas.com.br',
    host: 'correiodecarajas.com.br',
    feeds: [
      { url: 'https://correiodecarajas.com.br/tag/corrida/feed/' },
      { url: 'https://correiodecarajas.com.br/feed/', apenasSobreCorrida: true },
    ],
  },
];
