# Knowledge Engine — BMW Global Sales (2010–2024)

## Descrição do Projeto

Este projeto implementa um **Knowledge Engine** em Prolog como trabalho acadêmico da disciplina de Lógica e Matemática Discreta. A ideia central é transformar um dataset tabular do mundo real em uma **base de conhecimento declarativa**, explorando o paradigma de programação lógica para responder perguntas analíticas por meio de inferência.

O dataset escolhido registra as vendas globais da BMW entre 2010 e 2024, com informações sobre modelos, regiões, tipos de combustível, transmissão, preço e volume de vendas. A partir desses dados, construímos fatos Prolog e regras de consulta que permitem responder perguntas como *"Qual modelo foi mais vendido na Europa?"* ou *"Qual é o preço médio dos carros elétricos da BMW?"*.

---

## Dataset

- **Fonte:** [Kaggle — BMW Global Sales Dataset (2010–2024)](https://www.kaggle.com/)
- **Arquivo original:** `BMW sales data (2010-2024).csv`
- **Campos utilizados:** `Model`, `Year`, `Region`, `Fuel_Type`, `Transmission`, `Engine_Size_L`, `Price_USD`, `Sales_Volume`
- **Total de registros:** 50.000 fatos Prolog gerados

### Campos descartados

| Campo | Motivo |
|---|---|
| `Color` | Atributo estético sem relevância para análises de vendas e preço |
| `Mileage_KM` | Grandeza derivada do uso, não da venda em si |
| `Sales_Classification` | Rótulo redundante derivável do volume (`Sales_Volume`) |

---

## Estrutura do Repositório

```
knowledge-engine-bmw/
├── README.md            # Documentação do projeto
├── etl.py               # Script Python que gera a base de conhecimento
├── knowledge_base.pl    # Base de conhecimento Prolog (50.000 fatos)
└── queries.pl           # Regras e consultas Prolog
```

| Arquivo | Descrição |
|---|---|
| `etl.py` | Lê o CSV (ou `archive.zip`), normaliza os dados e escreve `knowledge_base.pl` |
| `knowledge_base.pl` | Conjunto de fatos no formato `bmw/8` gerados pelo ETL |
| `queries.pl` | Carrega a base e define as 5 regras de consulta |
| `README.md` | Esta documentação |

---

## Como Rodar

### Pré-requisitos

- **Python 3.8+** (sem dependências externas — o ETL usa apenas stdlib: `csv`, `zipfile`, `re`, `os`)
- **SWI-Prolog** instalado localmente, **ou** use o ambiente online [SWISH](https://swish.swi-prolog.org/)

### Passo 1 — Gerar a base de conhecimento

Coloque `BMW sales data (2010-2024).csv` (ou `archive.zip` do Kaggle) na raiz do projeto e execute:

```bash
python etl.py
```

Isso gera o arquivo `knowledge_base.pl` com todos os fatos.

### Passo 2 — Carregar no Prolog (SWI-Prolog local)

```bash
swipl queries.pl
```

O arquivo `queries.pl` já carrega `knowledge_base` automaticamente com a diretiva `:- [knowledge_base].`

### Passo 2 (alternativo) — SWISH online

1. Acesse [swish.swi-prolog.org](https://swish.swi-prolog.org/)
2. Cole o conteúdo de `knowledge_base.pl` e depois o de `queries.pl` no editor
3. Execute as queries no painel direito

---

## Predicado Base

Todos os fatos seguem o formato:

```prolog
bmw(Model, Year, Region, FuelType, Transmission, EngineSize, PriceUSD, SalesVolume).
```

**Exemplos:**

```prolog
bmw(5_series, 2016, asia, petrol, manual, 3.5, 98740, 8300).
bmw(i8, 2013, north_america, hybrid, automatic, 1.6, 79219, 3428).
bmw(x3, 2024, middle_east, petrol, automatic, 1.7, 60971, 4047).
```

**Domínios:**

| Argumento | Valores possíveis |
|---|---|
| Model | `3_series`, `5_series`, `7_series`, `m3`, `m5`, `x1`, `x3`, `x6`, `i3`, `i8` |
| Region | `asia`, `europe`, `north_america`, `south_america`, `middle_east`, `africa` |
| FuelType | `petrol`, `diesel`, `hybrid`, `electric` |
| Transmission | `manual`, `automatic` |

---

## Perguntas e Queries

### Query 1 — Resumo por região: modelos distintos e total de vendas (Sofisticada)

**Pergunta:** Para cada região, quantos modelos distintos foram comercializados e qual foi o volume total de vendas? Qual é o ranking das regiões por volume?

```prolog
resumo_regiao(Regiao, NumModelos, TotalVendas) :-
    findall(M, bmw(M, _, Regiao, _, _, _, _, _), Todos),
    Todos \= [],
    sort(Todos, Modelos),
    length(Modelos, NumModelos),
    findall(V, bmw(_, _, Regiao, _, _, _, _, V), Volumes),
    sum_list(Volumes, TotalVendas).

ranking_regioes(Ranking) :-
    findall(R, bmw(_, _, R, _, _, _, _, _), TodasR),
    sort(TodasR, Regioes),
    findall(T-R, (member(R, Regioes), resumo_regiao(R, _, T)), Pares),
    msort(Pares, Sorted),
    reverse(Sorted, Ranking).
```

**Exemplo de uso:**

```prolog
?- resumo_regiao(europe, NumModelos, TotalVendas).
NumModelos = 10, TotalVendas = 8350000

?- ranking_regioes(Ranking).
Ranking = [8350000-europe, 7200000-asia, 6100000-north_america, ...]
```

**Por que é sofisticada:** combina dois `findall/3` sobre a mesma região — um para coletar modelos únicos (com `sort/2` e `length/2`) e outro para agregar volumes; depois `ranking_regioes/1` compõe esse predicado auxiliar para construir e ordenar o ranking completo.

---

### Query 2 — Evolução anual de vendas de um modelo (Sofisticada)

**Pergunta:** Como evoluiu o volume total de vendas de um modelo ao longo dos anos, somando todas as regiões? Resultado ordenado cronologicamente.

```prolog
vendas_modelo_ano(Modelo, Ano, TotalAno) :-
    findall(V, bmw(Modelo, Ano, _, _, _, _, _, V), Lista),
    Lista \= [],
    sum_list(Lista, TotalAno).

evolucao_anual(Modelo, Evolucao) :-
    findall(A, bmw(Modelo, A, _, _, _, _, _, _), Todos),
    sort(Todos, Anos),
    findall(A-T, (member(A, Anos), vendas_modelo_ano(Modelo, A, T)), Evolucao).
```

**Exemplo de uso:**

```prolog
?- evolucao_anual(x3, Evolucao).
Evolucao = [2010-18500, 2011-21300, 2012-24800, ..., 2024-41200]

?- evolucao_anual(i3, Evolucao).
Evolucao = [2013-4200, 2014-6800, ..., 2024-9100]
```

**Por que é sofisticada:** usa `sort/2` para deduzir automaticamente o conjunto de anos em que o modelo aparece na base, depois agrega o volume total de cada ano com `vendas_modelo_ano/3` (predicado auxiliar) via `findall/3`, produzindo uma série temporal ordenada cronologicamente.

---

### Query 3 — Total de vendas por modelo / Ranking (Sofisticada)

**Pergunta:** Qual é o volume total de vendas de cada modelo ao longo de todo o período e em todas as regiões? Qual é o ranking dos modelos mais vendidos?

```prolog
total_vendas_modelo(Modelo, Total) :-
    findall(V, bmw(Modelo, _, _, _, _, _, _, V), Lista),
    Lista \= [],
    sum_list(Lista, Total).

ranking_vendas(Ranking) :-
    findall(M, bmw(M, _, _, _, _, _, _, _), Todos),
    sort(Todos, Modelos),
    findall(T-M, (member(M, Modelos), total_vendas_modelo(M, T)), Pares),
    msort(Pares, Sorted),
    reverse(Sorted, Ranking).
```

**Exemplo de uso:**

```prolog
?- ranking_vendas(Ranking).
Ranking = [4200000-x3, 3950000-5_series, 3100000-3_series, ...]
```

**Por que é sofisticada:** usa `findall/3` duas vezes — uma para coletar os modelos únicos (com `sort/2` para deduplicar) e outra para construir os pares (total, modelo); depois `msort/2` ordena mantendo duplicatas numéricas e `reverse/1` inverte para ordem decrescente.

---

### Query 4 — Modelo mais vendido por região (Sofisticada)

**Pergunta:** Para cada região do mundo, qual modelo BMW acumulou o maior volume total de vendas?

```prolog
vendas_modelo_regiao(Modelo, Regiao, Total) :-
    findall(V, bmw(Modelo, _, Regiao, _, _, _, _, V), Lista),
    Lista \= [],
    sum_list(Lista, Total).

melhor_modelo_por_regiao(Regiao, MelhorModelo, Total) :-
    findall(M, bmw(M, _, Regiao, _, _, _, _, _), Todos),
    sort(Todos, Modelos),
    findall(T-M, (member(M, Modelos), vendas_modelo_regiao(M, Regiao, T)), Pares),
    max_member(Total-MelhorModelo, Pares).
```

**Exemplo de uso:**

```prolog
?- melhor_modelo_por_regiao(europe, Modelo, Total).
Modelo = x3, Total = 1850000
```

**Por que é sofisticada:** encadeia dois níveis de agregação — primeiro `vendas_modelo_regiao/3` agrega por modelo+região com `findall/3` e `sum_list/2`; depois `melhor_modelo_por_regiao/3` elimina duplicatas com `sort/2`, coleta todos os pares (total, modelo) e usa `max_member/2` para extrair o maior.

---

### Query 5 — Preço médio por tipo de combustível (Sofisticada)

**Pergunta:** Qual é o preço médio de venda dos modelos BMW agrupado por tipo de combustível?

```prolog
preco_medio_combustivel(FuelType, Media) :-
    findall(P, bmw(_, _, _, FuelType, _, _, P, _), Lista),
    Lista \= [],
    sum_list(Lista, Soma),
    length(Lista, N),
    Media is Soma / N.
```

**Exemplo de uso:**

```prolog
?- preco_medio_combustivel(electric, Media).
Media = 72450.3

?- preco_medio_combustivel(hybrid, Media).
Media = 68120.7
```

**Para comparar todos os combustíveis de uma vez:**

```prolog
?- forall(member(F, [petrol, diesel, hybrid, electric]),
          (preco_medio_combustivel(F, M), format("~w: ~2f~n", [F, M]))).
```

**Por que é sofisticada:** combina `findall/3`, `sum_list/2`, `length/2` e aritmética (`is`) para computar uma estatística descritiva (média) diretamente no motor de inferência Prolog, sem nenhuma linguagem auxiliar.

---

## Decisões de Projeto

### Por que esse dataset?

O dataset de vendas globais da BMW cobre 15 anos e 6 regiões, oferecendo variedade suficiente para demonstrar múltiplas técnicas de consulta sofisticada: agregação, ordenação, séries temporais e composição de predicados auxiliares. Dados de vendas de automóveis são intuitivos para qualquer leitor, facilitando a avaliação dos resultados.

### Normalização dos átomos Prolog

O ETL aplica as seguintes transformações a todos os campos textuais:

1. Converter para minúsculas (`"North America"` → `"north america"`)
2. Substituir qualquer sequência de caracteres não-alfanuméricos por `_` (`"north america"` → `"north_america"`)
3. Remover underscores nas bordas

Isso garante que todos os valores se tornem **átomos Prolog válidos** (sem aspas, sem espaços), seguindo a convenção de que átomos começam com letra minúscula ou são delimitados por aspas simples.

### Por que `findall` em vez de recursão manual?

`findall/3` é o predicado idiomático do SWI-Prolog para agregação — é eficiente, legível e não falha quando a lista está vazia (retorna `[]`). A recursão manual seria mais verbosa e propensa a erros de corte.

### Por que `msort` em vez de `sort` nos rankings?

`sort/2` remove duplicatas além de ordenar. Nos rankings de modelos e regiões, os pares têm formato `Total-Nome` — se dois itens tivessem o mesmo volume total, `sort` descartaria um deles silenciosamente. `msort/2` ordena sem remover duplicatas, garantindo que todos os itens apareçam no ranking mesmo em caso de empate.

### Separação entre `knowledge_base.pl` e `queries.pl`

Manter a base de fatos separada das regras permite:
- Regenerar a base (via ETL) sem tocar nas queries
- Carregar apenas a base em outros contextos (ex.: outros projetos Prolog)
- Reduzir o tempo de parse no SWISH ao trabalhar interativamente nas regras

---

## Autores

Projeto desenvolvido para a disciplina de **Lógica e Matemática Discreta** — Insper, 2025.
