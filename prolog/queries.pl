% queries.pl — Knowledge Engine BMW (nivel avancado)
:- use_module(library(lists)).

:- if(exists_file('data/processed/knowledge_base.pl')).
:- ['data/processed/knowledge_base.pl'].
:- elif(exists_file('../data/processed/knowledge_base.pl')).
:- ['../data/processed/knowledge_base.pl'].
:- elif(exists_file('knowledge_base.pl')).
:- ['knowledge_base.pl'].
:- else.
:- initialization((writeln('ERRO: knowledge_base.pl nao encontrado.'), halt(1))).
:- endif.

sum_values(Pairs, Sum) :-
    findall(V, member(_-V, Pairs), Values),
    sum_list(Values, Sum).

group_sum_by_key(Pairs, Grouped) :-
    findall(Key, member(Key-_, Pairs), Keys0),
    sort(Keys0, Keys),
    findall(Key-Sum,
        (
            member(Key, Keys),
            findall(Key-V, member(Key-V, Pairs), LocalPairs),
            sum_values(LocalPairs, Sum)
        ),
        Grouped
    ).

mean(List, Mean) :-
    List \= [],
    sum_list(List, Sum),
    length(List, N),
    Mean is Sum / N.

variance(List, Variance) :-
    mean(List, Mean),
    findall(Sq, (member(X, List), D is X - Mean, Sq is D * D), Squares),
    mean(Squares, Variance).

% Query 1: melhor modelo por regiao com politica explicita de empate.
% Politica: retorna TODOS os empatados e em ordem alfabetica.
melhor_modelo_por_regiao(Regiao, MelhoresModelos, TotalVendas) :-
    setof(Modelo, Ano^F^T^E^P^V^bmw(Modelo, Ano, Regiao, F, T, E, P, V), Modelos),
    findall(Soma-Modelo,
        (
            member(Modelo, Modelos),
            findall(V, bmw(Modelo, _, Regiao, _, _, _, _, V), Volumes),
            sum_list(Volumes, Soma)
        ),
        TotaisModelo
    ),
    findall(Soma, member(Soma-_, TotaisModelo), Somas),
    max_list(Somas, TotalVendas),
    findall(ModeloTop, member(TotalVendas-ModeloTop, TotaisModelo), Melhores0),
    sort(Melhores0, MelhoresModelos).

% Query 2: tendencia e volatilidade por modelo (nao trivial, temporal + estatistica).
% Classificacao:
% - crescente_forte: fim >= inicio * 1.20
% - decrescente_forte: fim =< inicio * 0.80
% - estavel: caso contrario
tendencia_modelo(Modelo, AnoInicial-VolInicial, AnoFinal-VolFinal, Classificacao, Variancia) :-
    setof(Ano, R^F^T^E^P^V^bmw(Modelo, Ano, R, F, T, E, P, V), Anos),
    findall(Ano-TotalAno,
        (
            member(Ano, Anos),
            findall(Vol, bmw(Modelo, Ano, _, _, _, _, _, Vol), VolsAno),
            sum_list(VolsAno, TotalAno)
        ),
        Serie
    ),
    % Serie esta em ordem crescente de Ano pois setof/3 ordena inteiros.
    Serie = [AnoInicial-VolInicial|_],
    last(Serie, AnoFinal-VolFinal),
    findall(V, member(_-V, Serie), ApenasVolumes),
    variance(ApenasVolumes, Variancia),
    ( VolFinal >= VolInicial * 1.20 -> Classificacao = crescente_forte
    ; VolFinal =< VolInicial * 0.80 -> Classificacao = decrescente_forte
    ; Classificacao = estavel
    ).

tendencia_modelo(Modelo, AnoInicial-VolInicial, AnoFinal-VolFinal, Classificacao, Variancia, ClassificacaoVolatilidade) :-
    tendencia_modelo(Modelo, AnoInicial-VolInicial, AnoFinal-VolFinal, Classificacao, Variancia),
    setof(Ano, R^F^T^E^P^V^bmw(Modelo, Ano, R, F, T, E, P, V), Anos),
    findall(TotalAno,
        (
            member(Ano, Anos),
            findall(Vol, bmw(Modelo, Ano, _, _, _, _, _, Vol), VolsAno),
            sum_list(VolsAno, TotalAno)
        ),
        Volumes
    ),
    mean(Volumes, MediaVolumes),
    DesvPad is sqrt(Variancia),
    ( MediaVolumes =:= 0 -> CV is 0.0 ; CV is DesvPad / MediaVolumes ),
    ( CV > 0.30 -> ClassificacaoVolatilidade = volatilidade_alta
    ; CV >= 0.15 -> ClassificacaoVolatilidade = volatilidade_media
    ; ClassificacaoVolatilidade = volatilidade_baixa
    ).

% Query 3: ranking regional por eficiencia comercial (vendas/preco), com filtro robusto.
% Exige volume agregado minimo para evitar ruido.
eficiencia_comercial_modelo_regiao(Regiao, Modelo, Eficiencia, VendasTotais, PrecoMedio) :-
    findall(Preco-Vol, bmw(Modelo, _, Regiao, _, _, _, Preco, Vol), Amostras),
    Amostras \= [],
    findall(Vol, member(_-Vol, Amostras), Vols),
    sum_list(Vols, VendasTotais),
    VendasTotais >= 50000,
    findall(Produto, (member(Preco-Vol, Amostras), Produto is Preco * Vol), Produtos),
    sum_list(Produtos, SomaProdutos),
    PrecoMedio is SomaProdutos / VendasTotais,
    PrecoMedio > 0,
    Eficiencia is VendasTotais / PrecoMedio.

ranking_eficiencia_regiao(Regiao, Ranking) :-
    setof(Modelo, A^F^T^E^P^V^bmw(Modelo, A, Regiao, F, T, E, P, V), Modelos),
    findall(Ef-Modelo-Vendas-Preco,
        (
            member(Modelo, Modelos),
            eficiencia_comercial_modelo_regiao(Regiao, Modelo, Ef, Vendas, Preco)
        ),
        Pares
    ),
    msort(Pares, OrdenadoAsc),
    reverse(OrdenadoAsc, Ranking).

% Query 4: dominancia de combustivel por regiao com concentracao.
% Retorna share do combustivel lider e indice HHI (concentracao).
dominancia_combustivel_regiao(Regiao, CombustivelLider, ShareLider, HHI) :-
    findall(Fuel-Vol, bmw(_, _, Regiao, Fuel, _, _, _, Vol), Pares),
    group_sum_by_key(Pares, CombustivelTotais),
    CombustivelTotais \= [],
    findall(Total, member(_-Total, CombustivelTotais), Totais),
    sum_list(Totais, SomaRegiao),
    SomaRegiao > 0,
    findall(Share-Fuel,
        (
            member(Fuel-TotalFuel, CombustivelTotais),
            Share is TotalFuel / SomaRegiao
        ),
        Shares
    ),
    max_member(ShareLider-CombustivelLider, Shares),
    findall(Sq, (member(S-_, Shares), Sq is S * S), Squares),
    sum_list(Squares, HHI).

% Query 5: desvio de preco por transmissao dentro de combustivel.
% Compara automatico vs manual para cada combustivel com dados suficientes.
desvio_preco_transmissao_combustivel(Fuel, DifAbs, DifRel, MediaAuto, MediaManual) :-
    findall(P, bmw(_, _, _, Fuel, automatic, _, P, _), PrecosAuto),
    findall(P, bmw(_, _, _, Fuel, manual, _, P, _), PrecosManual),
    length(PrecosAuto, NAuto),
    length(PrecosManual, NManual),
    NAuto >= 30,
    NManual >= 30,
    mean(PrecosAuto, MediaAuto),
    mean(PrecosManual, MediaManual),
    DifAbs is MediaAuto - MediaManual,
    MediaManual =\= 0,
    DifRel is DifAbs / MediaManual.

demo :-
    format("=== Query 1: Melhor modelo por regiao ===~n"),
    forall(member(R1, [europe, asia, north_america]), demo_q1(R1)),
    nl,
    format("=== Query 2: Tendencia temporal por modelo ===~n"),
    forall(member(M2, [x3, m5, '5_series']), demo_q2(M2)),
    nl,
    format("=== Query 3: Ranking eficiencia regiao (top-3) ===~n"),
    forall(member(R3, [europe, asia]), demo_q3(R3)),
    nl,
    format("=== Query 4: Dominancia combustivel por regiao ===~n"),
    forall(member(R4, [europe, asia, north_america, south_america, africa, middle_east]), demo_q4(R4)),
    nl,
    format("=== Query 5: Desvio preco transmissao por combustivel ===~n"),
    forall(member(F5, [petrol, diesel, hybrid, electric]), demo_q5(F5)).

demo_q1(R) :-
    ( melhor_modelo_por_regiao(R, Modelos, Total)
    -> format("  ~w -> ~w | total vendas: ~d~n", [R, Modelos, Total])
    ;  format("  ~w -> sem dados~n", [R])
    ).

demo_q2(M) :-
    ( tendencia_modelo(M, AI-VI, AF-VF, C, V, CV)
    -> ( Vf is V + 0.0,
         format("  ~w: ~d-~d -> ~d-~d | ~w | variancia: ~2e | ~w~n",
                [M, AI, VI, AF, VF, C, Vf, CV])
       )
    ;  format("  ~w: sem dados~n", [M])
    ).

demo_q3(R) :-
    ( ranking_eficiencia_regiao(R, Ranking), Ranking \= []
    -> ( format("  Regiao ~w:~n", [R]),
         length(Ranking, NR),
         ( NR >= 3 -> NTop = 3 ; NTop = NR ),
         length(Top, NTop),
         append(Top, _, Ranking),
         forall(
           member(Ef-Mod-Vendas-Preco, Top),
           ( EfF is Ef + 0.0, PrecoF is Preco + 0.0,
             format("    ~w -> ef=~4f vendas=~d preco_medio=~2f~n",
                    [Mod, EfF, Vendas, PrecoF])
           )
         )
       )
    ;  format("  ~w -> sem ranking~n", [R])
    ).

demo_q4(R) :-
    ( dominancia_combustivel_regiao(R, Lider, Share, HHI)
    -> ( ShareF is Share + 0.0, HHIF is HHI + 0.0,
         format("  ~w -> lider=~w share=~3f hhi=~3f~n", [R, Lider, ShareF, HHIF])
       )
    ;  format("  ~w -> sem dados~n", [R])
    ).

demo_q5(F) :-
    ( desvio_preco_transmissao_combustivel(F, DAbs, DRel, MA, MM)
    -> ( MAf is MA + 0.0, MMf is MM + 0.0,
         DAbsf is DAbs + 0.0, DRelf is DRel + 0.0,
         format("  ~w -> auto=~2f manual=~2f difAbs=~2f difRel=~3f~n",
                [F, MAf, MMf, DAbsf, DRelf])
       )
    ;  format("  ~w -> amostras insuficientes~n", [F])
    ).

:- initialization(demo, main).
