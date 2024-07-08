# SmartInvest
FIXURI
2024.01.12  - Fix pentru lateStart si Multiplier
            - Fix pentru afisarea NextLot in Dashboard  (needsTesting)



BUG cu calcularea distantei -> PriceCurrent vs Price open asta imi compara bid cu ask in loc sa compare bid cu bid si ask cu ask 399 (done)
BUG IsSessionTrade pe MQL4 -> trebuie fixata metoda ca facem spam la mql4

BUG/Upgrade la clasa cu new Candle ( si fac structuri sau clase cu lista de clase si sa verific symbolu structuri si sa fie obiecte diferite/creeate)
*/

/*
Sa am grija la DD to close
Cand calculez swapurile si comisioanele sa vad ca de fapt nu pun la socoteala swap/comision sau nu stiu exact cum face daca tre sa ma uit in history sau nu
swap cred ca ia dar comisionul il vede doar in history

*/



Hedging streategies ideas
Incep complementarea direct sau de la a doua tranzactie de complementare VARIANTE:
-> deschis cu lot fix sau cu procent din intreaga valoare a secventei
-> inchid de fiecare data cand deschid un nou trade deci profitul e garantat daca stepul este destul de mare incat sa acopere swap/comision
-> cand se intoarce medierea fie inchid toata medierea si las tradeul de complemantare si vad ce  fac de acolo
-> fie inchid toata medierea luand in calcul si minusul generat de tranzactia de complementare ( aici tre sa vad exact cum iau volumele ca sa calculez SL/TP sau daca inchid fix cand e pe plus un anumit numar de puncte
   pot sa inchid si cand e profiul =0 sau cand plusulde pe mediere + minusul de pe complementare ajunge la numarul dorit de puncte castigate
      asta inseamnca ca am profit cu 1 lot 50p si minus cu 0.1 de exemplu 400 puncte acel 1 lot trebuie sa compenseze acel 0.1
-> din profituri pot sa si inchid din volumele existente de mediere de la un anumit punct inainte si sa reduc distanta pana la TP (inchid trade pe plus, inchid volume, modific TP)
