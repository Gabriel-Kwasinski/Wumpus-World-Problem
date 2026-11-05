
:-dynamic posicao/3.
:-dynamic memory/3.
:-dynamic visitado/2.
:-dynamic certeza/2.
:-dynamic energia/1.
:-dynamic pontuacao/1.

% Base de conhecimento do agente
:-dynamic percebido/3.   % percebido(X,Y,ListaDePercepcoes) sentida na casa visitada (X,Y)
:-dynamic tem/3.         % tem(X,Y,Coisa)     -> certeza de que Coisa esta em (X,Y)
:-dynamic nao_tem/3.     % nao_tem(X,Y,Coisa) -> certeza de que Coisa NAO esta em (X,Y)
:-consult('mapa.pl').

delete([], _, []).
delete([Elem|Tail], Del, Result) :-
    (   \+ Elem \= Del
    ->  delete(Tail, Del, Result)
    ;   Result = [Elem|Rest],
        delete(Tail, Del, Rest)
    ).


reset_game :- retractall(memory(_,_,_)),
			retractall(visitado(_,_)),
			retractall(certeza(_,_)),
			retractall(percebido(_,_,_)),
			retractall(tem(_,_,_)),
			retractall(nao_tem(_,_,_)),
			retractall(energia(_)),
			retractall(pontuacao(_)),
			retractall(posicao(_,_,_)),
			assert(energia(100)),
			assert(pontuacao(0)),
			assert(posicao(1,1, norte)).


:-reset_game.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Geometria (nao depende do conteudo do mapa)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%vizinho(X,Y,VX,VY): (VX,VY) e uma das 4 casas adjacentes a (X,Y) dentro da arena
vizinho(X,Y,VX,Y) :- map_size(MAX_X,_), X < MAX_X, VX is X + 1.
vizinho(X,Y,VX,Y) :- X > 1, VX is X - 1.
vizinho(X,Y,X,VY) :- map_size(_,MAX_Y), Y < MAX_Y, VY is Y + 1.
vizinho(X,Y,X,VY) :- Y > 1, VY is Y - 1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% AMBIENTE
%% Esta e a unica parte do programa que consulta o mapa real (tile/3).
%% O agente recebe apenas: a lista de percepcoes da casa atual (sentidos/1)
%% e o que sentiu ao chegar na casa (kb_chegada/3: nada, dano, queda, teleporte).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%sensores: percepcoes na posicao atual
sentidos(Ps) :- posicao(X,Y,_), findall(S, sentido(X,Y,S), L), sort(L, Ps).

sentido(X,Y,brisa)   :- vizinho(X,Y,VX,VY), tile(VX,VY,'P').
sentido(X,Y,palmas)  :- vizinho(X,Y,VX,VY), tile(VX,VY,'T').
sentido(X,Y,passos)  :- vizinho(X,Y,VX,VY), (tile(VX,VY,'D') ; tile(VX,VY,'d')).
sentido(X,Y,brilho)  :- tile(X,Y,'O').
sentido(X,Y,reflexo) :- tile(X,Y,'U').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Controle de Status
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%atualiza pontuacao
atualiza_pontuacao(X):- pontuacao(P), retract(pontuacao(P)), NP is P + X, assert(pontuacao(NP)),!.

%atualiza energia
atualiza_energia(N):- energia(E), retract(energia(E)), NE is E + N,
					(
					 (NE =<0, assert(energia(0)),posicao(X,Y,_),retract(posicao(_,_,_)), assert(posicao(X,Y,morto)),!);
					 (NE >100, assert(energia(100)),!);
					  (NE >0,assert(energia(NE)),!)
					 ).

%verifica situacao da nova posicao, atualiza energia e pontos
%e informa ao agente o que ele sentiu ao chegar (percepcao de evento)
verifica_player :- posicao(X,Y,_), tile(X,Y,'P'), kb_chegada(X,Y,queda), atualiza_energia(-100), atualiza_pontuacao(-1000),!.
verifica_player :- posicao(X,Y,_), tile(X,Y,'D'), kb_chegada(X,Y,dano), random_between(-80,-50,D), atualiza_energia(D),!.
verifica_player :- posicao(X,Y,_), tile(X,Y,'d'), kb_chegada(X,Y,dano), random_between(-50,-25,D), atualiza_energia(D),!.
verifica_player :- posicao(X,Y,Z), tile(X,Y,'T'), kb_chegada(X,Y,teleporte),
					map_size(SX,SY), random_between(1,SX,NX), random_between(1,SY,NY),
				retract(posicao(X,Y,Z)), assert(posicao(NX,NY,Z)), atualiza_obs, verifica_player,!.
verifica_player :- posicao(X,Y,_), kb_chegada(X,Y,nada),!
verifica_player :- true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Comandos
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%virar direita
virar_direita :- posicao(X,Y, norte), retract(posicao(_,_,_)), assert(posicao(X, Y, leste)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, oeste), retract(posicao(_,_,_)), assert(posicao(X, Y, norte)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, sul), retract(posicao(_,_,_)), assert(posicao(X, Y, oeste)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, leste), retract(posicao(_,_,_)), assert(posicao(X, Y, sul)),atualiza_pontuacao(-1),!.

%virar esquerda
virar_esquerda :- posicao(X,Y, norte), retract(posicao(_,_,_)), assert(posicao(X, Y, oeste)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, oeste), retract(posicao(_,_,_)), assert(posicao(X, Y, sul)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, sul), retract(posicao(_,_,_)), assert(posicao(X, Y, leste)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, leste), retract(posicao(_,_,_)), assert(posicao(X, Y, norte)),atualiza_pontuacao(-1),!.

%andar (a KB e atualizada depois, por atualiza_obs e verifica_player)
andar :- posicao(X,Y,P), P = norte, map_size(_,MAX_Y), Y < MAX_Y, YY is Y + 1,
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), atualiza_pontuacao(-1),!.
andar :- posicao(X,Y,P), P = sul,  Y > 1, YY is Y - 1,
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), atualiza_pontuacao(-1),!.
andar :- posicao(X,Y,P), P = leste, map_size(MAX_X,_), X < MAX_X, XX is X + 1,
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), atualiza_pontuacao(-1),!.
andar :- posicao(X,Y,P), P = oeste,  X > 1, XX is X - 1,
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), atualiza_pontuacao(-1),!.

%pegar
pegar :- posicao(X,Y,_), tile(X,Y,'O'), retract(tile(X,Y,'O')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_pontuacao(500),!.
pegar :- posicao(X,Y,_), tile(X,Y,'U'), retract(tile(X,Y,'U')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_energia(50),!.
pegar :- atualiza_pontuacao(-5),!.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% AGENTE - Base de conhecimento (KB)
%% Nenhum predicado desta secao consulta tile/3: tudo e deduzido das
%% percepcoes recebidas (percebido/3) e dos eventos de chegada.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%perigos e o sinal que produzem nas casas vizinhas
perigo(poco).
perigo(morcego).
perigo(inimigo).

sinal(poco, brisa).
sinal(morcego, palmas).
sinal(inimigo, passos).

%itens e o sinal que produzem na propria casa
item(ouro, brilho).
item(cura, reflexo).

%simbolo usado em memory/3 (lido pelo gmap.py)
simbolo(H, S) :- sinal(H, S).
simbolo(I, S) :- item(I, S).

%afirma um fato na KB sem duplicar
kb_afirma(F) :- ( call(F) -> true ; assertz(F) ).

%recebe as percepcoes da posicao atual e atualiza a KB
atualiza_obs :- posicao(X,Y,_), sentidos(Ps), kb_percebe(X,Y,Ps).

kb_percebe(X,Y,Ps) :-
	retractall(percebido(X,Y,_)), assertz(percebido(X,Y,Ps)),
	kb_afirma(visitado(X,Y)),
	forall(item(I,S),
	       ( memberchk(S,Ps) -> kb_afirma(tem(X,Y,I)) ; retractall(tem(X,Y,I)) )),
	kb_fecha.

%o que o agente sentiu ao entrar na casa
kb_chegada(X,Y,nada)      :- forall(perigo(H), kb_afirma(nao_tem(X,Y,H))), kb_fecha.
kb_chegada(X,Y,dano)      :- kb_afirma(tem(X,Y,inimigo)), kb_fecha.
kb_chegada(X,Y,queda)     :- kb_afirma(tem(X,Y,poco)), kb_fecha.
kb_chegada(X,Y,teleporte) :- kb_afirma(tem(X,Y,morcego)), kb_fecha.

kb_fecha :- kb_inferir, kb_atualiza_visao.

%encadeamento para frente ate nao haver fatos novos
kb_inferir :- kb_regra(F), \+ call(F), !, assertz(F), kb_inferir.
kb_inferir.

%R1: sem o sinal de H numa casa visitada -> nenhum vizinho tem H
kb_regra(nao_tem(X,Y,H)) :-
	percebido(VX,VY,Ps), sinal(H,S), \+ memberchk(S,Ps), vizinho(VX,VY,X,Y).

%R2: com o sinal de H e apenas um vizinho ainda possivel -> esse vizinho tem H
kb_regra(tem(X,Y,H)) :-
	percebido(VX,VY,Ps), sinal(H,S), memberchk(S,Ps),
	findall((CX,CY), (vizinho(VX,VY,CX,CY), \+ nao_tem(CX,CY,H)), [(X,Y)]).

%R3: cada casa contem no maximo uma coisa
kb_regra(nao_tem(X,Y,H2)) :- tem(X,Y,H), perigo(H2), H2 \== H.

%R4: dois perigos do MESMO tipo (poco, morcego ou inimigo) nunca estao
%    a 1 ou 2 passos cardinais um do outro (adjacentes, 2 casas em linha), ou seja, distancia de
%    Manhattan <= 2 -> descarta esse perigo nessas casas.
kb_regra(nao_tem(X,Y,H)) :- perigo(H), tem(PX,PY,H), perigo_proibido(PX,PY,X,Y).

perigo_proibido(PX,PY,X,Y) :-
	between(-2, 2, DX), between(-2, 2, DY),
	D is abs(DX) + abs(DY), D >= 1, D =< 2,
	X is PX + DX, Y is PY + DY,
	map_size(MAX_X,MAX_Y), X >= 1, X =< MAX_X, Y >= 1, Y =< MAX_Y.

%H e possivel em (X,Y): nao descartado e algum vizinho visitado sentiu o sinal
kb_possivel(X,Y,H) :-
	perigo(H), \+ nao_tem(X,Y,H), sinal(H,S),
	percebido(VX,VY,Ps), memberchk(S,Ps), vizinho(VX,VY,X,Y), !.

%todos os perigos da casa ja estao decididos
kb_decidida(X,Y) :- forall(perigo(H), (tem(X,Y,H) ; nao_tem(X,Y,H))).

kb_celula(X,Y) :- visitado(X,Y).
kb_celula(X,Y) :- tem(X,Y,_).
kb_celula(X,Y) :- nao_tem(X,Y,_).
kb_celula(X,Y) :- percebido(VX,VY,_), vizinho(VX,VY,X,Y).

kb_conteudo(X,Y,L) :-
	findall(S, (simbolo(C,S), once((tem(X,Y,C) ; kb_possivel(X,Y,C)))), L).

%reconstroi memory/3 e certeza/2 (visao usada pelo gmap.py e show_mem) a partir da KB
kb_atualiza_visao :-
	retractall(memory(_,_,_)), retractall(certeza(_,_)),
	( setof((X,Y), kb_celula(X,Y), Cs) -> true ; Cs = [] ),
	forall(member((X,Y), Cs),
	       ( kb_conteudo(X,Y,L), assertz(memory(X,Y,L)),
	         ( kb_decidida(X,Y) -> assertz(certeza(X,Y)) ; true ) )).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mostra mapa real
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
show_player(X,Y) :- posicao(X,Y, norte), write('^'),!.
show_player(X,Y) :- posicao(X,Y, oeste), write('<'),!.
show_player(X,Y) :- posicao(X,Y, leste), write('>'),!.
show_player(X,Y) :- posicao(X,Y, sul), write('v'),!.
show_player(X,Y) :- posicao(X,Y, morto), write('+'),!.

%show_position(X,Y) :- show_player(X,Y),!.
show_position(X,Y) :- (show_player(X,Y); write(' ')), tile(X,Y,Z), ((Z='', write(' '));write(Z)),!.

show_map :- map_size(_,MAX_Y), show_map(1,MAX_Y),!.
show_map(X,Y) :- Y >= 1, map_size(MAX_X,_), X =< MAX_X, show_position(X,Y), write(' | '), XX is X + 1, show_map(XX, Y),!.
show_map(X,Y) :- Y >= 1, map_size(X,_),YY is Y - 1, write(Y), nl, show_map(1, YY),!.
show_map(_,0) :- energia(E), pontuacao(P), write('E: '), write(E), write('   P: '), write(P),!.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mostra mapa conhecido
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

show_mem_info(X,Y) :- memory(X,Y,Z),
		((visitado(X,Y), write('.'),!); (\+certeza(X,Y), write('?'),!); (certeza(X,Y), write('!'))),
		((member(brisa, Z), write('P'));write(' ')),
		((member(palmas, Z), write('T'));write(' ')),
		((member(brilho, Z), write('O'));write(' ')),
		((member(passos, Z), write('D'));write(' ')),
		((member(reflexo, Z), write('U'));write(' ')),!.

show_mem_info(X,Y) :- \+memory(X,Y,[]),
			((visitado(X,Y), write('.'),!); (\+certeza(X,Y), write('?'),!); (certeza(X,Y), write('!'))),
			write('     '),!.



show_mem_position(X,Y) :- posicao(X,Y,_),
		((visitado(X,Y), write('.'),!); (certeza(X,Y), write('!'),!); write(' ')),
		write(' '), show_player(X,Y),
		((memory(X,Y,Z),
		((member(brilho, Z), write('O'));write(' ')),
		((member(passos, Z), write('D'));write(' ')),
		((member(reflexo, Z), write('U'));write(' ')),!);
		(write('   '),!)).

show_mem_position(X,Y) :- show_mem_info(X,Y),!.


show_mem :- map_size(_,MAX_Y), show_mem(1,MAX_Y),!.
show_mem(X,Y) :- Y >= 1, map_size(MAX_X,_), X =< MAX_X, show_mem_position(X,Y), write('|'), XX is X + 1, show_mem(XX, Y),!.
show_mem(X,Y) :- Y >= 1, map_size(X,_),YY is Y - 1, write(Y), nl, show_mem(1, YY),!.
show_mem(_,0) :- energia(E), pontuacao(P), write('E: '), write(E), write('   P: '), write(P),!.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%apagar esta linha - apenas para demonstracao aleatoria
executa_acao(X) :- L=['virar_esquerda','virar_direita','andar','pegar'],random_between(1,4,I), nth1(I, L, X),!.

%apagar linhas abaixo... sao exemplos de resposta
%executa_acao(andar) :- posicao(PX, _, oeste), PX > 1, X = andar,!.
%executa_acao(andar) :- posicao(PX, _, leste), PX < 3, X = andar,!.
%executa_acao(pegar) :- posicao(PX, PY,_), tem_ouro(PX, PY), !.
%executa_acao(voltar) :- peguei_todos_ouros,!.



