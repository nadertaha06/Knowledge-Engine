# Knowledge Engine BMW (ETL Python + Prolog)

Projeto de Knowledge Engine para Lógica e Matemática Discreta com foco em rigor técnico, reprodutibilidade e consultas Prolog realmente analíticas.

## Dataset (fonte única)

- Fonte escolhida: [BMW Sales Dataset (Kaggle)](https://www.kaggle.com/datasets/sinansm/bmw-sales-dataset)
- Arquivo usado: `BMW sales data (2010-2024) (1).csv`
- Observação importante: no Kaggle, o caminho típico é `/kaggle/input/bmw-sales-dataset/BMW sales data (2010-2024) (1).csv`; localmente o ETL usa caminho parametrizável e nao depende desse path.

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
├── queries.pl                  # wrapper de compatibilidade
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
   - razao vendas/preco medio com filtro de robustez (volume minimo)
4. `dominancia_combustivel_regiao/4`
   - lider por share + indice HHI de concentracao
5. `desvio_preco_transmissao_combustivel/5`
   - compara automatico x manual por combustivel com tamanho minimo de amostra

## Evidencias de execucao

Comandos usados:

```bash
python3 etl.py --output "data/processed/knowledge_base.pl"
swipl -q -s prolog/queries.pl -g "melhor_modelo_por_regiao(europe,M,T),writeln(M-T),halt."
swipl -q -s prolog/queries.pl -g "tendencia_modelo(x3,I,F,C,V),writeln([I,F,C,V]),halt."
swipl -q -s prolog/queries.pl -g "ranking_eficiencia_regiao(asia,R),R=[Top|_],writeln(Top),halt."
swipl -q -s prolog/queries.pl -g "dominancia_combustivel_regiao(europe,F,S,H),writeln([F,S,H]),halt."
swipl -q -s prolog/queries.pl -g "desvio_preco_transmissao_combustivel(hybrid,DAbs,DRel,MA,MM),writeln([DAbs,DRel,MA,MM]),halt."
```

Status de validacao neste ambiente:

- ETL executado com sucesso (50.000 lidas, 50.000 aceitas, 0 rejeitadas).
- SWI-Prolog (`swipl`) nao estava instalado no ambiente de execucao usado nesta revisao, entao os comandos Prolog acima devem ser executados localmente para reproduzir as respostas.

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
