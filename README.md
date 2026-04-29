# Knowledge Engine BMW (ETL Python + Prolog)

Projeto de Knowledge Engine para Lógica e Matemática Discreta com foco em rigor técnico, reprodutibilidade e consultas Prolog realmente analíticas.

## Dataset (fonte única)

- Fonte escolhida: [BMW Sales Dataset (Kaggle)](https://www.kaggle.com/code/eshummalik/bmw-sales)
- Arquivo usado: `BMW sales data (2010-2024) (1).csv`
- Observação importante: no Kaggle, o caminho típico é `/kaggle/input/bmw-sales-dataset/BMW sales data (2010-2024) (1).csv`; localmente o ETL usa caminho parametrizável e nao depende desse path.

> Nota sobre a natureza dos dados: o dataset é **sintético** — gerado artificialmente no Kaggle. Algumas combinações de modelo + combustível são fisicamente impossíveis no mundo real (ex.: BMW i3 com motor a gasolina, sendo que o i3 real só foi produzido em versões elétrica/híbrida), mas são mantidas pois fazem parte dos dados originais e não afetam a validade das análises relacionais aqui apresentadas — o foco do trabalho é a engenharia de conhecimento sobre a base, não a verossimilhança automotiva.

## Campos utilizados (8 campos, misto quali/quanti)

Predicado-base:

```prolog
bmw(Model, Year, Region, FuelType, Transmission, EngineSizeL, PriceUSD, SalesVolume).
```

Campos selecionados:

- Qualitativos: `Model`, `Region`, `Fuel_Type`, `Transmission`
- Quantitativos: `Year`, `Engine_Size_L`, `Price_USD`, `Sales_Volume`

## Estrutura do projeto

```text
Knowledge-Engine/
├── src/
│   └── etl.py
├── prolog/
│   └── queries.pl
├── data/
│   ├── raw/
│   └── processed/
│       └── knowledge_base.pl   # gerado pelo ETL (nao versionado)
├── etl.py                      # wrapper de compatibilidade
├── queries.pl
├── knowledge_base.pl           # legado (compatibilidade)
└── README.md
```

Compatibilidade preservada:

- `python etl.py` continua funcionando (delegando para `src/etl.py`)
- `swipl queries.pl` continua funcionando (delegando para `prolog/queries.pl`)

## Pipeline ETL -> Base Prolog -> Queries

1. `src/etl.py` le uma unica tabela CSV (`DictReader`)
2. valida schema e tipos
3. normaliza texto para atomos Prolog validos
4. aplica validacoes numericas
5. gera fatos `bmw/8`
6. grava `data/processed/knowledge_base.pl`
7. `prolog/queries.pl` carrega a base e executa regras analiticas

## Execucao local (recomendada)

Pre-requisitos:

- Python 3.10+
- SWI-Prolog

### 1) Preparar dataset

Coloque o CSV em `data/raw/` (ou use qualquer caminho local).

### 2) Gerar base Prolog

```bash
python3 etl.py --input "data/raw/BMW sales data (2010-2024) (1).csv" --output "data/processed/knowledge_base.pl"
```

Exemplo de saida do ETL:

```text
=== RELATORIO DE QUALIDADE ETL ===
Entrada: data/raw/BMW sales data (2010-2024) (1).csv
Saida: data/processed/knowledge_base.pl
Linhas lidas: 50000
Linhas aceitas: 50000
Linhas rejeitadas: 0
Motivos de rejeicao:
- nenhum
Alertas de dominio:
- nenhum
Possiveis colisoes de normalizacao (mesmo token para originais distintos):
- nenhuma colisao detectada
```

### 3) Rodar queries Prolog

```bash
swipl -q -s prolog/queries.pl
```

## Execucao no Kaggle

No Kaggle Notebook, com o dataset anexado:

```bash
python3 etl.py --kaggle --output "data/processed/knowledge_base.pl"
```

O `--kaggle` tenta o path:

- `/kaggle/input/bmw-sales-dataset/BMW sales data (2010-2024) (1).csv`

Se o path nao existir, o ETL falha explicitamente com mensagem de erro (sem fallback silencioso perigoso).

## Perguntas finais (todas sofisticadas)

Implementadas em `prolog/queries.pl`:

1. `melhor_modelo_por_regiao/3`
   - agrega por modelo/regiao
   - define politica explicita de empate (retorna todos os empatados)
2. `tendencia_modelo/5`
   - serie temporal anual agregada + classificacao de tendencia + variancia
3. `ranking_eficiencia_regiao/2`
   - razao vendas/preco medio (preco ponderado pelo volume) com filtro de robustez (volume minimo)
4. `dominancia_combustivel_regiao/4`
   - lider por share + indice HHI de concentracao
5. `desvio_preco_transmissao_combustivel/5`
   - compara automatico x manual por combustivel com tamanho minimo de amostra

## Como interpretar os resultados

### Query 1 — `melhor_modelo_por_regiao/3`

"Melhor modelo" significa o modelo com **maior volume total agregado** de vendas (soma de `Sales_Volume`) na regiao, considerando todos os anos do dataset (2010–2024). A politica de empate retorna **todos** os modelos empatados, em ordem alfabetica — nao escolhe arbitrariamente um vencedor.

### Query 2 — `tendencia_modelo/5` e `tendencia_modelo/6`

A serie temporal e construida agregando o volume anual em todas as regioes para o modelo. A classificacao de tendencia compara o volume do primeiro ano com o do ultimo:

- `crescente_forte`: volume final >= 1,20 × volume inicial (crescimento de pelo menos 20%)
- `decrescente_forte`: volume final <= 0,80 × volume inicial (queda de pelo menos 20%)
- `estavel`: variacao dentro da faixa de ±20%

A `variancia` mede a dispersao dos volumes anuais — quanto maior, mais o volume oscilou ano a ano. A `ClassificacaoVolatilidade` (apenas em `/6`) normaliza essa dispersao pelo coeficiente de variacao (CV = desvio_padrao / media):

- `volatilidade_alta`: CV > 0,30
- `volatilidade_media`: 0,15 <= CV <= 0,30
- `volatilidade_baixa`: CV < 0,15

A vantagem do CV sobre a variancia bruta e ser **adimensional**: permite comparar volatilidade entre modelos com volumes muito diferentes.

### Query 3 — `ranking_eficiencia_regiao/2`

A eficiencia comercial e definida como `vendas_totais / preco_medio_ponderado`, onde o preco medio e ponderado pelo volume de vendas: `sum(Preco_i * Vol_i) / sum(Vol_i)`. Isso evita que outliers de preco com baixo volume distorcam o indicador. O ranking e ordenado de forma decrescente pela eficiencia.

Limitacoes da metrica:

- nao considera margem de lucro nem custos de producao — e uma metrica de "vendas por dolar de preco", nao de rentabilidade
- modelos com volume agregado abaixo de 50.000 unidades sao filtrados para evitar resultados instaveis em amostras pequenas

### Query 4 — `dominancia_combustivel_regiao/4`

O `combustivel_lider` e o tipo de combustivel com maior fatia de mercado (volume relativo) na regiao. O **HHI** (indice de Herfindahl–Hirschman) e a soma dos quadrados das fatias de mercado, em escala 0–1:

- proximo de **1**: alto grau de concentracao (no extremo, monopolio absoluto = 1,0)
- proximo de **0**: mercado muito disperso entre os tipos de combustivel
- com 4 combustiveis em distribuicao perfeitamente uniforme, HHI = 4 × 0,25² = 0,25 (piso teorico para este dominio)

### Query 5 — `desvio_preco_transmissao_combustivel/5`

`DifRel` e o desvio relativo de preco entre transmissao automatica e manual, dentro do mesmo tipo de combustivel:

- `DifRel > 0`: automatico em media **mais caro** que manual
- `DifRel < 0`: automatico em media **mais barato** que manual
- a magnitude `|DifRel|` indica o tamanho relativo do desvio (ex.: `0,05` = 5% acima do preco manual)

A query exige no minimo 30 amostras de cada lado (auto e manual) para evitar conclusoes estatisticamente fracas.

## Evidencias de execucao

A execucao padrao roda automaticamente todas as 5 queries via `:- initialization(demo, main)` ao carregar o arquivo:

```bash
$ swipl -q -s prolog/queries.pl
=== Query 1: Melhor modelo por regiao ===
  europe -> [i8] | total vendas: 4202401
  asia -> [x1] | total vendas: 4192289
  north_america -> [7_series] | total vendas: 4087259

=== Query 2: Tendencia temporal por modelo ===
  x3: 2010-1584432 -> 2024-1664449 | estavel | variancia: 8.53e+09 | volatilidade_baixa
  m5: 2010-1594989 -> 2024-1632996 | estavel | variancia: 1.50e+10 | volatilidade_baixa
  5_series: 2010-1501229 -> 2024-1711580 | estavel | variancia: 9.54e+09 | volatilidade_baixa

=== Query 3: Ranking eficiencia regiao (top-3) ===
  Regiao europe:
    i8 -> ef=54.8030 vendas=4202401 preco_medio=76681.92
    m5 -> ef=54.4780 vendas=4002667 preco_medio=73473.09
    i3 -> ef=53.0388 vendas=3954257 preco_medio=74554.09
  Regiao asia:
    x1 -> ef=56.5157 vendas=4192289 preco_medio=74179.16
    5_series -> ef=53.0471 vendas=3935629 preco_medio=74191.22
    7_series -> ef=52.7217 vendas=4004066 preco_medio=75947.19

=== Query 4: Dominancia combustivel por regiao ===
  europe -> lider=hybrid share=0.254 hhi=0.250
  asia -> lider=hybrid share=0.266 hhi=0.250
  north_america -> lider=electric share=0.256 hhi=0.250
  south_america -> lider=diesel share=0.253 hhi=0.250
  africa -> lider=petrol share=0.254 hhi=0.250
  middle_east -> lider=petrol share=0.255 hhi=0.250

=== Query 5: Desvio preco transmissao por combustivel ===
  petrol -> auto=75237.94 manual=74748.29 difAbs=489.65 difRel=0.007
  diesel -> auto=75073.94 manual=75085.56 difAbs=-11.62 difRel=-0.000
  hybrid -> auto=75227.15 manual=74373.32 difAbs=853.83 difRel=0.011
  electric -> auto=75143.64 manual=75409.82 difAbs=-266.19 difRel=-0.004
```

Leitura cruzada das saidas acima:

- todos os modelos analisados em Q2 ficaram em `estavel` + `volatilidade_baixa`, coerente com a natureza sintetica do dataset (distribuicoes praticamente uniformes ao longo dos anos)
- HHIs de Q4 ficam todos colados em 0,250 (o piso teorico com 4 combustiveis em distribuicao uniforme), confirmando ausencia de concentracao real — nenhuma regiao tem combustivel realmente dominante
- em Q5 chama atencao o `hybrid` com `DifRel = 0,011` (~1,1% de premio para automatico) e `petrol` com 0,7%, contra `diesel` praticamente zero — diferencas pequenas em valor absoluto, mas no caso de `hybrid` ja saem do nivel de ruido puro observado em `diesel`

## Validacoes tecnicas aplicadas

- ETL:
  - sem conversao silenciosa de entrada ausente/invalida
  - relatorio de qualidade com rejeicoes por motivo
  - alertas de dominio para categorias inesperadas
  - deteccao de potenciais colisoes de normalizacao
- Prolog:
  - aridades revisadas
  - agregacoes com `findall/3` + `sum_list/2`
  - deduplicacao controlada com `setof/3`/`sort/2`
  - politica de empate documentada e implementada
  - filtros para evitar respostas instaveis por baixa amostra
