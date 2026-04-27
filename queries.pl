% queries.pl — Knowledge Engine: BMW Global Sales (2010-2024)
% Carrega a base de conhecimento gerada pelo etl.py
:- [knowledge_base].

% =============================================================================
% Query 1 — SOFISTICADA: Resumo por região (modelos distintos + total de vendas)
%
% Pergunta: Para cada região, quantos modelos distintos foram comercializados
% e qual foi o volume total de vendas? Qual é o ranking das regiões?
%
% Lógica de Primeira Ordem:
%   resumo_regiao(R, N, T) ←
%     M_set = { M | bmw(M, _, R, _, _, _, _, _) }  ∧  M_set ≠ ∅  ∧
%     N = |M_set|  ∧
%     T = Σ{ V | bmw(_, _, R, _, _, _, _, V) }
%
%   ranking_regioes(Ranking) ←
%     Regs = { R | bmw(_, _, R, _, _, _, _, _) }  ∧
%     Ranking = sort_desc([ (T, R) | R ∈ Regs, T = Σvendas(R) ])
%
% Uso:
%   ?- resumo_regiao(europe, NumModelos, TotalVendas).
%   ?- ranking_regioes(Ranking).
% =============================================================================

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


% =============================================================================
% Query 2 — SOFISTICADA: Evolução anual de vendas de um modelo
%
% Pergunta: Como evoluiu o volume total de vendas de um modelo ao longo dos
% anos (somando todas as regiões)? Resultado ordenado cronologicamente.
%
% Lógica de Primeira Ordem:
%   vendas_modelo_ano(Mo, A, T) ←
%     T = Σ{ V | bmw(Mo, A, _, _, _, _, _, V) }  ∧  T > 0
%
%   evolucao_anual(Mo, E) ←
%     Anos = { A | bmw(Mo, A, _, _, _, _, _, _) }  ∧
%     E = [ (A, T) | A ∈ Anos, T = Σ{ V | bmw(Mo, A, _, _, _, _, _, V) } ]
%
% Uso:
%   ?- evolucao_anual(x3, Evolucao).
%   ?- evolucao_anual(m3, Evolucao).
% =============================================================================

vendas_modelo_ano(Modelo, Ano, TotalAno) :-
    findall(V, bmw(Modelo, Ano, _, _, _, _, _, V), Lista),
    Lista \= [],
    sum_list(Lista, TotalAno).

evolucao_anual(Modelo, Evolucao) :-
    findall(A, bmw(Modelo, A, _, _, _, _, _, _), Todos),
    sort(Todos, Anos),
    findall(A-T, (member(A, Anos), vendas_modelo_ano(Modelo, A, T)), Evolucao).


% =============================================================================
% Query 3 — SOFISTICADA: Total de vendas por modelo (agregação + ranking)
%
% Pergunta: Qual é o volume total de vendas de cada modelo em todo o período
% e todas as regiões? Quais são os modelos mais vendidos, em ordem decrescente?
%
% Lógica de Primeira Ordem:
%   total_vendas_modelo(Mo, T) ←
%     T = Σ{ V | bmw(Mo, _, _, _, _, _, _, V) }  ∧  T > 0
%
%   ranking_vendas(Ranking) ←
%     Mods = { M | bmw(M, _, _, _, _, _, _, _) }  ∧
%     Ranking = sort_desc([ (T, M) | M ∈ Mods, T = total_vendas_modelo(M) ])
%
% Uso:
%   ?- total_vendas_modelo(x3, Total).
%   ?- ranking_vendas(Ranking).
% =============================================================================

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


% =============================================================================
% Query 4 — SOFISTICADA: Modelo mais vendido por região
%
% Pergunta: Para cada região do mundo, qual modelo BMW acumulou o maior
% volume total de vendas?
%
% Lógica de Primeira Ordem:
%   vendas_modelo_regiao(Mo, R, T) ←
%     T = Σ{ V | bmw(Mo, _, R, _, _, _, _, V) }  ∧  T > 0
%
%   melhor_modelo_por_regiao(R, Mo*, T*) ←
%     Mods = { M | bmw(M, _, R, _, _, _, _, _) }  ∧
%     (T*, Mo*) = argmax_{M ∈ Mods} vendas_modelo_regiao(M, R)
%
% Uso:
%   ?- melhor_modelo_por_regiao(europe, Modelo, Total).
%   ?- melhor_modelo_por_regiao(south_america, Modelo, Total).
% =============================================================================

vendas_modelo_regiao(Modelo, Regiao, Total) :-
    findall(V, bmw(Modelo, _, Regiao, _, _, _, _, V), Lista),
    Lista \= [],
    sum_list(Lista, Total).

melhor_modelo_por_regiao(Regiao, MelhorModelo, Total) :-
    findall(M, bmw(M, _, Regiao, _, _, _, _, _), Todos),
    sort(Todos, Modelos),
    findall(T-M, (member(M, Modelos), vendas_modelo_regiao(M, Regiao, T)), Pares),
    max_member(Total-MelhorModelo, Pares).


% =============================================================================
% Query 5 — SOFISTICADA: Preço médio por tipo de combustível
%
% Pergunta: Qual é o preço médio de venda dos modelos BMW agrupado por tipo
% de combustível (petrol, diesel, hybrid, electric)?
%
% Lógica de Primeira Ordem:
%   preco_medio_combustivel(F, μ) ←
%     L = { P | bmw(_, _, _, F, _, _, P, _) }  ∧  |L| > 0  ∧
%     μ = Σ(L) / |L|
%
% Uso:
%   ?- preco_medio_combustivel(electric, Media).
%   ?- preco_medio_combustivel(hybrid, Media).
%   ?- forall(member(F, [petrol, diesel, hybrid, electric]),
%             (preco_medio_combustivel(F, M), format("~w: ~2f~n", [F, M]))).
% =============================================================================

preco_medio_combustivel(FuelType, Media) :-
    findall(P, bmw(_, _, _, FuelType, _, _, P, _), Lista),
    Lista \= [],
    sum_list(Lista, Soma),
    length(Lista, N),
    Media is Soma / N.
