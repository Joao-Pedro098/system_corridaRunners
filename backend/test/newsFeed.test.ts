// Leitura dos feeds de notícias, sem rede e sem banco.
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  extractCover,
  isAboutRunning,
  MAX_EXCERPT,
  normalizeArticleLink,
  normalizeImageUrl,
  parseFeed,
  toCategory,
  toExcerpt,
} from '../src/services/newsFeedParser';

const NOW = new Date('2026-11-05T12:00:00Z');

const feed = (items: string) => `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:media="http://search.yahoo.com/mrss/">
<channel><title>Site</title><link>https://site.com</link><description>Descrição do site</description>${items}</channel></rss>`;

describe('leitura do feed', () => {
  it('lê título, link, autor, data e categorias, e decodifica o texto', () => {
    const [item] = parseFeed(
      feed(`<item>
        <title>Treino &#038; descanso</title>
        <link>https://site.com/a?x=1&amp;y=2</link>
        <dc:creator><![CDATA[Ana Lima]]></dc:creator>
        <pubDate>Wed, 04 Nov 2026 20:05:15 +0000</pubDate>
        <category><![CDATA[Treinamento]]></category>
        <category><![CDATA[Corrida]]></category>
        <description><![CDATA[<p>Será &#8220;mesmo&#8221; que funciona [&#8230;]</p>
<p>The post <a href="https://site.com/a">Treino</a> appeared first on <a href="https://site.com">Site</a>.</p>]]></description>
      </item>`),
      NOW
    );
    assert.equal(item.titulo, 'Treino & descanso');
    assert.equal(item.link, 'https://site.com/a?x=1&y=2');
    assert.equal(item.autor, 'Ana Lima');
    assert.equal(item.publicadoEm.toISOString(), '2026-11-04T20:05:15.000Z');
    assert.deepEqual(item.categorias, ['Treinamento', 'Corrida']);
    assert.equal(item.resumo, 'Será “mesmo” que funciona…');
  });

  it('nunca usa o texto completo da matéria', () => {
    const [item] = parseFeed(
      feed(`<item><title>T</title><link>https://site.com/a</link><description>Resumo curto</description>
        <content:encoded><![CDATA[<p>TEXTO COMPLETO DA MATERIA</p>]]></content:encoded></item>`),
      NOW
    );
    assert.equal(item.resumo, 'Resumo curto');
    assert.equal(JSON.stringify(item).includes('TEXTO COMPLETO'), false);
  });

  it('corta o resumo no fim de uma palavra', () => {
    const excerpt = toExcerpt(Array(200).fill('palavra').join(' '));
    assert.ok(excerpt.length <= MAX_EXCERPT);
    assert.ok(excerpt.endsWith('palavra…'));
  });

  it('remove HTML, inclusive o que vem escapado', () => {
    assert.equal(toExcerpt('<script>alert(1)</script>Olá &lt;b&gt;mundo&lt;/b&gt;'), 'Olá mundo');
  });

  it('aceita um único item, ignora item incompleto e conteúdo que não é RSS', () => {
    assert.equal(parseFeed(feed('<item><title>T</title><link>https://site.com/a</link><description>R</description></item>'), NOW).length, 1);
    assert.equal(parseFeed(feed('<item><title>Sem link</title><description>R</description></item>'), NOW).length, 0);
    assert.deepEqual(parseFeed('<html><body>Página</body></html>', NOW), []);
    assert.deepEqual(parseFeed('', NOW), []);
  });

  it('não aceita data futura nem inválida', () => {
    const items = parseFeed(
      feed(`<item><title>A</title><link>https://site.com/a</link><description>R</description><pubDate>Mon, 01 Jan 2035 00:00:00 +0000</pubDate></item>
            <item><title>B</title><link>https://site.com/b</link><description>R</description><pubDate>ontem</pubDate></item>`),
      NOW
    );
    assert.deepEqual(items.map((i) => i.publicadoEm), [NOW, NOW]);
  });

  it('lê a imagem do próprio feed, ignorando anexo que não é imagem', () => {
    const [withImage, withAudio] = parseFeed(
      feed(`<item><title>A</title><link>https://site.com/a</link><description>R</description><media:content url="https://site.com/a.jpg" medium="image"/></item>
            <item><title>B</title><link>https://site.com/b</link><description>R</description><enclosure url="https://site.com/b.mp3" type="audio/mpeg"/></item>`),
      NOW
    );
    assert.equal(withImage.imagem, 'https://site.com/a.jpg');
    assert.equal(withAudio.imagem, undefined);
  });
});

describe('filtro do feed geral', () => {
  it('aceita matérias claramente sobre corrida', () => {
    for (const title of ['Marabá recebe corrida de rua no domingo', 'Inscrições para a Meia-Maratona de Belém', 'Maratona de Parauapebas abre vagas', 'Evento terá corrida e caminhada']) {
      assert.equal(isAboutRunning(title), true, title);
    }
  });

  it('recusa os outros sentidos da palavra', () => {
    for (const title of ['Motorista de aplicativo é morto durante corrida', 'Corrida eleitoral esquenta em Marabá', 'Corrida contra o tempo salva paciente', 'Maratona de vacinação no sábado', 'Morador encontra ossada durante caminhada']) {
      assert.equal(isAboutRunning(title), false, title);
    }
  });
});

describe('categoria', () => {
  it('traduz os assuntos da fonte para as categorias do app', () => {
    assert.equal(toCategory(['Treinamento', 'Corrida']), 'Dica de Treino');
    assert.equal(toCategory(['Nutrição']), 'Nutrição');
    assert.equal(toCategory(['Tênis']), 'Novidade');
    assert.equal(toCategory([]), 'Novidade');
  });
});

describe('links', () => {
  it('só aceita matéria do domínio da fonte e limpa o link', () => {
    assert.equal(normalizeArticleLink('http://site.com/a?utm_source=x&id=1#topo', 'site.com'), 'https://site.com/a?id=1');
    assert.equal(normalizeArticleLink('https://www.site.com/a', 'site.com'), 'https://www.site.com/a');
    assert.equal(normalizeArticleLink('https://outrosite.com/a', 'site.com'), null);
    assert.equal(normalizeArticleLink('https://site.com.evil.io/a', 'site.com'), null);
    assert.equal(normalizeArticleLink('http://localhost/admin', 'site.com'), null);
    assert.equal(normalizeArticleLink('javascript:alert(1)', 'site.com'), null);
  });

  it('só aceita capa em https', () => {
    assert.equal(normalizeImageUrl('https://site.com/a.jpg'), 'https://site.com/a.jpg');
    assert.equal(normalizeImageUrl('http://site.com/a.jpg'), undefined);
    assert.equal(normalizeImageUrl('data:image/png;base64,AAAA'), undefined);
    assert.equal(normalizeImageUrl('/a.jpg', 'https://site.com/m'), 'https://site.com/a.jpg');
  });
});

describe('capa da matéria', () => {
  const PAGE = 'https://site.com/materia';

  it('usa a imagem de compartilhamento, com atributos em qualquer ordem', () => {
    assert.equal(extractCover('<meta property="og:image" content="https://site.com/a.jpg" />', PAGE), 'https://site.com/a.jpg');
    assert.equal(extractCover(`<meta content='https://site.com/b.jpg' property='og:image'>`, PAGE), 'https://site.com/b.jpg');
    assert.equal(extractCover('<meta name="twitter:image" content="https://site.com/c.jpg">', PAGE), 'https://site.com/c.jpg');
  });

  it('ignora página sem capa, logotipo e imagem insegura', () => {
    assert.equal(extractCover('<title>Sem capa</title>', PAGE), undefined);
    assert.equal(extractCover('<meta property="og:image" content="https://site.com/logo.png">', PAGE), undefined);
    assert.equal(extractCover('<meta property="og:image" content="http://site.com/a.jpg">', PAGE), undefined);
  });
});
