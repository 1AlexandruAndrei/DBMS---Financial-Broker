 --ex 6
create or replace procedure companii_si_actionari as
    type tabel_indexat is table of number index BY PLS_INTEGER;
    type tabel_imbricat is table of VARCHAR2(100);
    type vectorr is varray(100) of NUMBER;

    id_companii tabel_indexat;
    actionari tabel_imbricat := tabel_imbricat();
    nr_actiuni vectorr := vectorr();

    v_nr_actiuni NUMBER;

begin
    -- ID-urile pare ale companiilor le pun in tabel indexat
    FOR i IN (select id_companie from companie where mod(id_companie, 2) = 0) loop
        id_companii(id_companii.COUNT + 1) := i.id_companie;
    end loop;

    -- pun in tabelul imbricat numele actionarilor care au investit in companii cu ID-uri pare
    for j IN (select DISTINCT a.nume
              from actionar a, investeste i, companie c
              where a.id_actionar=i.id_actionar
              and i.id_companie = c.id_companie
              and mod(c.id_companie, 2) = 0) loop
        actionari.EXTEND;
        actionari(actionari.last) := j.nume;
    end loop;

    -- in array pun nr total de actiuni pt fiecare companie
    for k IN (select id_companie, COUNT(*) AS nr_total
              FROM actiune
              group by id_companie) loop
        nr_actiuni.EXTEND;
        nr_actiuni(nr_actiuni.last) := k.nr_total;
    end loop;

    -- afisez actionarii si nr de actiuni
    if actionari.COUNT > 0 then
        DBMS_OUTPUT.PUT_LINE('Actionari care au investit in companii cu ID par: ');
        for cnt IN 1..actionari.count loop
            DBMS_OUTPUT.PUT_LINE(actionari(cnt));
        END LOOP;
    END IF;

    
    DBMS_OUTPUT.PUT_LINE('------------------------------------');
    -- afisez continutul tabelului indexat
    DBMS_OUTPUT.PUT_LINE('ID-urile companiilor cu ID par: ');
    for p in 1..id_companii.count loop
        DBMS_OUTPUT.PUT_LINE('Compania cu ID ' || id_companii(p));
    end loop;

    DBMS_OUTPUT.PUT_LINE('------------------------------------');
    -- afisez nr total de actiuni pe care le are fiecare companie cu ID par
    DBMS_OUTPUT.PUT_LINE('Nr de actiuni publice pt companii cu ID par: ');
    for p in 1..id_companii.count loop
        DBMS_OUTPUT.PUT_LINE('Compania cu ID ' || id_companii(p)
                             || ' are ' || nr_actiuni(p) || ' actiuni');
    end loop;
end companii_si_actionari;
/

execute companii_si_actionari;


------------------------------------------------
------------------------------------------------
--ex 7
create or replace procedure ex7 as
    type refcursor is ref cursor;
    ordine_clnt refcursor;-- Expresie cursor
    v_balanta portofoliu.balanta%type:=6000;
    v_idclient portofoliu.id_client%type;
    v_idordin ordin.id_ordin%type;
    v_numar ordin.numar%type;
    v_pretunitate ordin.pret_unitate%type;
    v_total NUMBER;
    
    cursor info(balantaa NUMBER) is-- cursor clasic parametrizat
        select p.id_client,
            cursor ( -- cursor clasic dependent
                    select o.id_ordin, o.numar, o.pret_unitate
                    from ordin o
                    where o.id_portofoliu=p.id_portofoliu
                    )
                    from portofoliu p
                    where p.balanta=balantaa;
    begin
        open info(v_balanta);
        loop
            fetch info into v_idclient,  ordine_clnt;
            exit when info%NOTFOUND;
            dbms_output.put_line('Clientul cu ID ' || v_idclient || ' are urmatoarele ordine ');
            
            loop
                fetch ordine_clnt into v_idordin, v_numar, v_pretunitate;
                exit when ordine_clnt%NOTFOUND;
                
                v_total:=v_numar*v_pretunitate;
                dbms_output.put_line('Ordinul ' || v_idordin || ' cu valoarea de '  || v_total || ' lei ');
            end loop;
        end loop;
        close info;
end;
/
execute ex7;
select * from portofoliu;
select * from portofoliu p, ordin o
where o.id_portofoliu=p.id_portofoliu;
------------------------------------------------
------------------------------------------------
select * from dba_users where username='MYUSER1';


SELECT profile FROM dba_users WHERE username = 'SYSTEM';
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED; 
alter user SYSTEM identified by "system";
-----------------------------------------------------

--ex 8
-- se da numele unui client
--sa se afle cate companii (evident, dintre cele pe care clientul le detine) ofera cel putin un dividend cu valoare in lei,
--iar luna platii dividendului sa fie octombrie sau mai devreme

--Pentru prima exceptie, trebuie ca prima conditie sa fie indeplinita (dividendul>0) dar a doua conditie sa fie neindeplinita (deci luna>10). (in cursorul c_data)
--Pentru a doua exceptie, prima conditie nu e indeplinita(dividend.valoare is null), dar a doua este. (cursorul c_dividend)
---------------------------------------
CREATE OR REPLACE FUNCTION div_si_clnt(p_client_name client.nume%type) RETURN NUMBER IS
    v_dividend_countt NUMBER := 0;
    v_id client.id_client%type;

    CURSOR c_data IS
        SELECT clnt.id_client, COUNT(*)
        FROM companie c, dividend d, actiune a, detine de, client clnt
        WHERE c.id_companie = d.id_companie
            AND a.id_companie = c.id_companie
            AND de.id_actiune = a.id_actiune
            AND clnt.id_client = de.id_client
            AND d.valoare > 0
            AND INITCAP(clnt.nume) = INITCAP(p_client_name)
            AND EXTRACT(MONTH FROM d.data_plata) > 10
        GROUP BY clnt.id_client;

    CURSOR c_dividend IS
        SELECT clnt.id_client, COUNT(*)
        FROM companie c, dividend d, actiune a, detine de, client clnt
        WHERE c.id_companie = d.id_companie
            AND a.id_companie = c.id_companie
            AND de.id_actiune = a.id_actiune
            AND clnt.id_client = de.id_client
            AND d.valoare IS NULL
            AND INITCAP(clnt.nume) = INITCAP(p_client_name)
            AND EXTRACT(MONTH FROM d.data_plata) < 10
        GROUP BY clnt.id_client;

BEGIN
    OPEN c_data;
    FETCH c_data INTO v_id, v_dividend_countt;

    IF c_data%FOUND THEN
        CLOSE c_data;
        RAISE_APPLICATION_ERROR(-20009, 'DIVIDENDUL ESTE PLATIT ABIA DUPA LUNA OCTOMBRIE');
    END IF;

    CLOSE c_data;

    OPEN c_dividend;
    FETCH c_dividend INTO v_id, v_dividend_countt;

    IF c_dividend%FOUND THEN
        CLOSE c_dividend;
        RAISE_APPLICATION_ERROR(-20009, 'DIVIDENDUL ESTE NULL');
    END IF;

    CLOSE c_dividend;

    SELECT clnt.id_client, COUNT(*)
    INTO v_id, v_dividend_countt
    FROM companie c, dividend d, actiune a, detine de, client clnt
    WHERE c.id_companie = d.id_companie
        AND a.id_companie = c.id_companie
        AND de.id_actiune = a.id_actiune
        AND clnt.id_client = de.id_client
        AND d.valoare > 0
        AND INITCAP(clnt.nume) = INITCAP(p_client_name)
        AND EXTRACT(MONTH FROM d.data_plata) < 10
    GROUP BY clnt.id_client;

    RETURN v_dividend_countt;

EXCEPTION
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20007, 'Sunt prea multi clienti cu acelasi nume.');
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20008, 'Nu s-a returnat nimic');
END div_si_clnt;
/


select div_si_clnt('Popescu') from dual;
select div_si_clnt('Toma') from dual;
select div_si_clnt('Casian') from dual;
select div_si_clnt('Porumbescu') from dual;


select * from client;
------------------------------------------------
-- ex 9
---numele si prenumele la clientul a carui nume se citeste din inputcare detin actiuni la companii 
---care ofera macar un dividend de peste 1 leu 
---si au capitalizarea mai mare decat cea citita din input

--Pentru prima exceptie, trebuie ca prima conditie sa fie indeplinita (valoare>1) dar a doua conditie sa fie neindeplinita (deci capitalizare<number). 
--(in cursorul c_cap)
--Pentru a doua exceptie, prima conditie nu e indeplinita(valoare<1), dar a doua este. (cursorul c_dividend)

CREATE OR REPLACE PROCEDURE raport_clienti(p_number IN NUMBER, p_client_name IN VARCHAR2) AS
    TYPE tabel_clienti IS TABLE OF VARCHAR2(100);
    clienti tabel_clienti := tabel_clienti();
    v_client_count NUMBER := 0;
    v_id client.id_client%type;
    v_dividend_countt NUMBER := 0;

    CURSOR c_cap IS
        SELECT clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare < p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare > 1;

    CURSOR c_dividend IS
        SELECT clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare > p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare < 1;

BEGIN
    BEGIN
        OPEN c_cap;
        FETCH c_cap INTO v_id; 
        IF c_cap%FOUND THEN
            CLOSE c_cap;
            RAISE_APPLICATION_ERROR(-20009, 'PRIMAE XC');
        END IF;
        CLOSE c_cap;

        OPEN c_dividend;
        FETCH c_dividend INTO v_id;
        IF c_dividend%FOUND THEN
            CLOSE c_dividend;
            RAISE_APPLICATION_ERROR(-20009, 'a doau exc');
        END IF;
        CLOSE c_dividend;

        SELECT COUNT(*)
        INTO v_client_count
        FROM client clnt
        WHERE clnt.nume = p_client_name;

        IF v_client_count > 1 THEN
            RAISE TOO_MANY_ROWS;
        ELSIF v_client_count = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;
        
        FOR rec_client IN (
            SELECT distinct clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
            FROM client clnt, detine d, actiune a, companie c, dividend dv 
            WHERE clnt.id_client = d.id_client 
                AND d.id_actiune = a.id_actiune
                AND a.id_companie = c.id_companie
                AND clnt.nume = p_client_name
                AND c.capitalizare > p_number
                AND c.id_companie = dv.id_companie
                AND dv.valoare > 1
        ) LOOP
            clienti.EXTEND;
            clienti(clienti.LAST) := rec_client.nume_si_prenume;
        END LOOP;

        IF clienti.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Clientul care respecta criteriile este:');
            FOR i IN 1..clienti.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(clienti(i));
            END LOOP;
        ELSIF clienti.count = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nu exista niciun rezultat pentru query');
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('Au fost returnate prea multe randuri pentru clientul ' || p_client_name);
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Alta eroare');
    END;
END;
/

------------------------------------------

------- AIA DE SUS E BUNA DAR VECHE
CREATE OR REPLACE PROCEDURE raport_clienti(p_number IN NUMBER, p_client_name IN VARCHAR2) AS
    TYPE tabel_clienti IS TABLE OF VARCHAR2(100);
    clienti tabel_clienti := tabel_clienti();
    v_client_count NUMBER := 0;
    v_id client.id_client%type;
    v_dividend_countt NUMBER := 0;


    CURSOR c_cap IS
        SELECT clnt.id_client
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare < p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare > 1;

    CURSOR c_dividend IS
        SELECT clnt.id_client
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare > p_number
            AND c.id_companie = dv.id_companie
            AND NVL(dv.valoare, 0) < 1;

BEGIN
    OPEN c_cap;
    FETCH c_cap INTO v_id;
    IF c_cap%FOUND THEN
        CLOSE c_cap;
        DBMS_OUTPUT.PUT_LINE('capitalizarea din input>capitalizarea companiei');
        RETURN;
    END IF;
    CLOSE c_cap;

    OPEN c_dividend;
    FETCH c_dividend INTO v_id;
    IF c_dividend%FOUND THEN
        CLOSE c_dividend;
        DBMS_OUTPUT.PUT_LINE('valaorea dividendului e < 1 leu');
        RETURN ;
    END IF;
    CLOSE c_dividend;

    SELECT COUNT(*)
    INTO v_client_count
    FROM client clnt
    WHERE clnt.nume = p_client_name;

    IF v_client_count > 1 THEN
        RAISE TOO_MANY_ROWS;
    ELSIF v_client_count = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

    FOR rec_client IN (
        SELECT distinct clnt.id_client, clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare > p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare > 1
    ) LOOP
        clienti.EXTEND;
        clienti(clienti.LAST) := rec_client.nume_si_prenume;
    END LOOP;

    IF clienti.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Clientul care respecta criteriile este:');
        FOR i IN 1..clienti.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(clienti(i));
        END LOOP;
    ELSIF clienti.count = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nu exista niciun rezultat pentru query');
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Au fost returnate prea multe randuri pentru clientul ' || p_client_name);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Alta eroare');
END;
/


SELECT clnt.id_client, clnt.nume, NVL(dv.valoare, 0), c.capitalizare AS valoare
FROM client clnt, detine d, actiune a, companie c, dividend dv 
WHERE clnt.id_client = d.id_client 
    AND d.id_actiune = a.id_actiune
    AND a.id_companie = c.id_companie
    AND c.id_companie = dv.id_companie
    AND NVL(dv.valoare, 0) < 1;


BEGIN
    raport_clienti(1000, 'Porumbescu');
END;

BEGIN
    raport_clienti(500000000099, 'Gheorghe');
END;

BEGIN
    raport_clienti(100, 'Toma'); --am prea multi clienti cu numele de familie toma care respecta conditia
END;

SELECT clnt.nume, clnt.id_client, c.capitalizare, dv.valoare
            FROM client clnt, detine d, actiune a, companie c, dividend dv 
            where clnt.id_client = d.id_client 
            and d.id_actiune = a.id_actiune
            and a.id_companie = c.id_companie
              and c.id_companie=dv.id_companie
              and dv.valoare>1;


SELECT clnt.nume, clnt.id_client, c.capitalizare, dv.valoare
            FROM client clnt, detine d, actiune a, companie c, dividend dv 
            where clnt.id_client = d.id_client 
            and d.id_actiune = a.id_actiune
            and a.id_companie = c.id_companie
              and c.id_companie=dv.id_companie;
--in loc de stefanescu cu id 1000 il fac toma

UPDATE client
SET nume= 'Stefanescu'
WHERE id_client=1000;

------------------------------------------------
-- CERINTA 10
-- nu pot modifica tabelele PORTOFOLIU si ORDIN
-- decat Luni-Vineri 10-18
create or replace trigger trig_10
    before insert or update or delete on ordin
begin
     IF TO_CHAR(SYSDATE, 'D') IN (1, 7) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Nu se pot face operatii decat in zilele lucratoare.');
    ELSIF TO_CHAR(SYSDATE, 'HH24') NOT BETWEEN 10 AND 18 THEN
        RAISE_APPLICATION_ERROR(-20009, 'Nu se pot face operatii cu ordine, decat intre orele 10 si 18.');
    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'Operatia nu este permisa in acest moment.');
    END IF;
end;
/


insert into ordin (id_ordin, id_portofoliu, tip, numar, pret_unitate, stare)
values (136, 7890, 'vanzare', 5, 1000, 'inchis');
select * from ordin order by id_ordin asc;
delete from ordin where id_ordin=136;
drop trigger trig_10;

------------------------------------------------
-- CERINTA 11
-- sa nu pot sa modific simbolul, iar pretul curent sa se poata modifica cu maxim 10% (mai mult sau mai putin)
select * from etf;

create or replace trigger trig_11
    before update of pret_curent, simbol on etf
    for each row
begin
    if (:NEW.pret_curent > :OLD.pret_curent*1.1 or :NEW.pret_curent < :OLD.pret_curent*1.1) then
        raise_application_error(-20002, 'Pretul curent al ETF-ului nu poate fluctua atat de mult');
    end if;
    
    if (:NEW.simbol <> :OLD.simbol) then
        raise_application_error(-20003, 'Simbolul ETF-ului nu poate fi schimbat');
    end if;
end;
/
update etf
set pret_curent='4000'
where id_etf=676;

drop trigger trig_11;

-------------------------------------------------------------------------------------
-- CERINTA 12
-- daca utilizatorul foloseste comenzi LDD le introduc in tabel
create table audit_utilizator
    (nume_utilizator varchar2(30),
    nume_bd varchar2(50),
    eveniment varchar2(20),
    nume_obiect varchar2(30),
    data_audit date);

create or replace trigger trg_audit
    after create or drop or alter on schema
begin
    insert into audit_utilizator (nume_utilizator, nume_bd, eveniment, nume_obiect, data_audit)
    values (sys.login_user, sys.database_name, sys.sysevent, sys.dictionary_obj_name, sysdate);
end;
/
create index indd on client(nume);
drop index indd;
drop trigger trg_audit;
drop table audit_utilizator;


-------------------------------------------------------------------------------------
--ex 13
create or replace package pachet_broker_financiar as
    --ex 6
    procedure companii_si_actionari;
    --ex 7
    procedure ex7;
    --ex 8 
    FUNCTION div_si_clnt(p_client_name client.nume%type) return number;
    --ex 9
     procedure raport_clienti(p_number IN NUMBER, p_client_name IN VARCHAR2);
end pachet_broker_financiar;

CREATE OR REPLACE PACKAGE BODY pachet_broker_financiar AS
    --ex6
    PROCEDURE companii_si_actionari AS
        TYPE tabel_indexat IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        TYPE tabel_imbricat IS TABLE OF VARCHAR2(100);
        TYPE vectorr IS VARRAY(100) OF NUMBER;

        id_companii tabel_indexat;
        actionari tabel_imbricat := tabel_imbricat();
        nr_actiuni vectorr := vectorr();

        v_nr_actiuni NUMBER;

    BEGIN
        -- ID-urile pare ale companiilor le pun in tabel indexat
        FOR i IN (SELECT id_companie FROM companie WHERE MOD(id_companie, 2) = 0) LOOP
            id_companii(id_companii.COUNT + 1) := i.id_companie;
        END LOOP;

        -- pun in tabelul imbricat numele actionarilor care au investit in companii cu ID-uri pare
        FOR j IN (SELECT DISTINCT a.nume
                  FROM actionar a, investeste i, companie c
                  WHERE a.id_actionar = i.id_actionar
                    AND i.id_companie = c.id_companie
                    AND MOD(c.id_companie, 2) = 0) LOOP
            actionari.EXTEND;
            actionari(actionari.LAST) := j.nume;
        END LOOP;

        -- in array pun nr total de actiuni pt fiecare companie
        FOR k IN (SELECT id_companie, COUNT(*) AS nr_total
                  FROM actiune
                  GROUP BY id_companie) LOOP
            nr_actiuni.EXTEND;
            nr_actiuni(nr_actiuni.LAST) := k.nr_total;
        END LOOP;

        -- afisez actionarii si nr de actiuni
        IF actionari.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Actionari care au investit in companii cu ID par: ');
            FOR cnt IN 1..actionari.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(actionari(cnt));
            END LOOP;
        END IF;

        DBMS_OUTPUT.PUT_LINE('------------------------------------');
        -- afisez continutul tabelului indexat
        DBMS_OUTPUT.PUT_LINE('ID-urile companiilor cu ID par: ');
        FOR p IN 1..id_companii.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Compania cu ID ' || id_companii(p));
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('------------------------------------');
        -- afisez nr total de actiuni pe care le are fiecare companie cu ID par
        DBMS_OUTPUT.PUT_LINE('Nr de actiuni publice pt companii cu ID par: ');
        FOR p IN 1..id_companii.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Compania cu ID ' || id_companii(p)
                                 || ' are ' || nr_actiuni(p) || ' actiuni');
        END LOOP;
    END companii_si_actionari;

    --ex 7
    PROCEDURE ex7 AS
        TYPE refcursor IS REF CURSOR;
        ordine_clnt refcursor;
        v_balanta portofoliu.balanta%TYPE := 6000;
        v_idclient portofoliu.id_client%TYPE;
        v_idordin ordin.id_ordin%TYPE;
        v_numar ordin.numar%TYPE;
        v_pretunitate ordin.pret_unitate%TYPE;
        v_total NUMBER;

        CURSOR info(balantaa NUMBER) IS
            SELECT p.id_client,
                   CURSOR (SELECT o.id_ordin, o.numar, o.pret_unitate
                           FROM ordin o
                           WHERE o.id_portofoliu = p.id_portofoliu)
            FROM portofoliu p
            WHERE p.balanta = balantaa;

    BEGIN
        OPEN info(v_balanta);
        LOOP
            FETCH info INTO v_idclient, ordine_clnt;
            EXIT WHEN info%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE('Clientul cu ID ' || v_idclient || ' are urmatoarele ordine ');

            LOOP
                FETCH ordine_clnt INTO v_idordin, v_numar, v_pretunitate;
                EXIT WHEN ordine_clnt%NOTFOUND;

                v_total := v_numar * v_pretunitate;
                DBMS_OUTPUT.PUT_LINE('Ordinul ' || v_idordin || ' cu valoarea de ' || v_total || ' lei ');
            END LOOP;
        END LOOP;
        CLOSE info;
    END ex7;

    --ex 8
     FUNCTION div_si_clnt(p_client_name client.nume%type) RETURN NUMBER IS
    v_dividend_countt NUMBER := 0;
    v_id client.id_client%type;

    CURSOR c_data IS
        SELECT clnt.id_client, COUNT(*)
        FROM companie c, dividend d, actiune a, detine de, client clnt
        WHERE c.id_companie = d.id_companie
            AND a.id_companie = c.id_companie
            AND de.id_actiune = a.id_actiune
            AND clnt.id_client = de.id_client
            AND d.valoare > 0
            AND INITCAP(clnt.nume) = INITCAP(p_client_name)
            AND EXTRACT(MONTH FROM d.data_plata) > 10
        GROUP BY clnt.id_client;

    CURSOR c_dividend IS
        SELECT clnt.id_client, COUNT(*)
        FROM companie c, dividend d, actiune a, detine de, client clnt
        WHERE c.id_companie = d.id_companie
            AND a.id_companie = c.id_companie
            AND de.id_actiune = a.id_actiune
            AND clnt.id_client = de.id_client
            AND d.valoare IS NULL
            AND INITCAP(clnt.nume) = INITCAP(p_client_name)
            AND EXTRACT(MONTH FROM d.data_plata) < 10
        GROUP BY clnt.id_client;

    BEGIN
    OPEN c_data;
    FETCH c_data INTO v_id, v_dividend_countt;

    IF c_data%FOUND THEN
        CLOSE c_data;
        RAISE_APPLICATION_ERROR(-20009, 'DIVIDENDUL ESTE PLATIT ABIA DUPA LUNA OCTOMBRIE');
    END IF;

    CLOSE c_data;

    OPEN c_dividend;
    FETCH c_dividend INTO v_id, v_dividend_countt;

    IF c_dividend%FOUND THEN
        CLOSE c_dividend;
        RAISE_APPLICATION_ERROR(-20009, 'DIVIDENDUL ESTE NULL');
    END IF;

    CLOSE c_dividend;

    SELECT clnt.id_client, COUNT(*)
    INTO v_id, v_dividend_countt
    FROM companie c, dividend d, actiune a, detine de, client clnt
    WHERE c.id_companie = d.id_companie
        AND a.id_companie = c.id_companie
        AND de.id_actiune = a.id_actiune
        AND clnt.id_client = de.id_client
        AND d.valoare > 0
        AND INITCAP(clnt.nume) = INITCAP(p_client_name)
        AND EXTRACT(MONTH FROM d.data_plata) < 10
    GROUP BY clnt.id_client;

    RETURN v_dividend_countt;

    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20007, 'Sunt prea multi clienti cu acelasi nume.');
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008, 'Nu s-a returnat nimic');
    END div_si_clnt;
    

    --ex 9
    PROCEDURE raport_clienti(p_number IN NUMBER, p_client_name IN VARCHAR2) AS
    TYPE tabel_clienti IS TABLE OF VARCHAR2(100);
    clienti tabel_clienti := tabel_clienti();
    v_client_count NUMBER := 0;
    v_id client.id_client%type;
    v_dividend_countt NUMBER := 0;

    CURSOR c_cap IS
        SELECT clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare < p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare > 1;

    CURSOR c_dividend IS
        SELECT clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
        FROM client clnt, detine d, actiune a, companie c, dividend dv 
        WHERE clnt.id_client = d.id_client 
            AND d.id_actiune = a.id_actiune
            AND a.id_companie = c.id_companie
            AND clnt.nume = p_client_name
            AND c.capitalizare > p_number
            AND c.id_companie = dv.id_companie
            AND dv.valoare < 1;

    BEGIN
    BEGIN
        OPEN c_cap;
        FETCH c_cap INTO v_id; 
        IF c_cap%FOUND THEN
            CLOSE c_cap;
            RAISE_APPLICATION_ERROR(-20009, 'PRIMAE XC');
        END IF;
        CLOSE c_cap;

        OPEN c_dividend;
        FETCH c_dividend INTO v_id;
        IF c_dividend%FOUND THEN
            CLOSE c_dividend;
            RAISE_APPLICATION_ERROR(-20009, 'a doau exc');
        END IF;
        CLOSE c_dividend;

        SELECT COUNT(*)
        INTO v_client_count
        FROM client clnt
        WHERE clnt.nume = p_client_name;

        IF v_client_count > 1 THEN
            RAISE TOO_MANY_ROWS;
        ELSIF v_client_count = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;
        
        FOR rec_client IN (
            SELECT distinct clnt.nume || ' ' || clnt.prenume AS nume_si_prenume
            FROM client clnt, detine d, actiune a, companie c, dividend dv 
            WHERE clnt.id_client = d.id_client 
                AND d.id_actiune = a.id_actiune
                AND a.id_companie = c.id_companie
                AND clnt.nume = p_client_name
                AND c.capitalizare > p_number
                AND c.id_companie = dv.id_companie
                AND dv.valoare > 1
        ) LOOP
            clienti.EXTEND;
            clienti(clienti.LAST) := rec_client.nume_si_prenume;
        END LOOP;

        IF clienti.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Clientul care respecta criteriile este:');
            FOR i IN 1..clienti.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(clienti(i));
            END LOOP;
        ELSIF clienti.count = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nu exista niciun rezultat pentru query');
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('Au fost returnate prea multe randuri pentru clientul ' || p_client_name);
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Alta eroare');
    END;
    END;
    
END pachet_broker_financiar;
/
--------------------------
BEGIN
    pachet_broker_financiar.companii_si_actionari;
END;
/

BEGIN
    pachet_broker_financiar.ex7;
END;
/

DECLARE
    v_dividend_count NUMBER;
BEGIN
    v_dividend_count := pachet_broker_financiar.div_si_clnt('Gheorghe');
    DBMS_OUTPUT.PUT_LINE('Numarul de companii corespunzatoare clientului: ' || v_dividend_count);
END;
/

BEGIN
    pachet_broker_financiar.raport_clienti(10000, 'Gheorghe');
END;
/

-----------------------------------------------------------------
-- pt un broker dat nr de clienti
-- client dat -- sa se afiseze brokerul
--lab 1
SELECT c.id_client, b.id_broker FROM broker b, client c
where b.id_broker=c.id_broker
order by 2 asc;


DECLARE
    v_brok broker.id_broker%TYPE;
BEGIN
    SELECT b.id_broker
    INTO v_brok
    FROM broker b, client c
    WHERE b.id_broker = c.id_broker
    GROUP BY b.id_broker
    ORDER BY COUNT(*) DESC
    FETCH FIRST 1 ROW ONLY;

    dbms_output.put_line('Departamentul cu cei mai multi clienti are ID-ul: ' || v_brok);
END;
/


