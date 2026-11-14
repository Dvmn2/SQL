CREATE TABLE spec (
    id          INT,
    table_name  TEXT,
    column_name TEXT,
    max_value   INT
);
INSERT INTO spec VALUES (1, 'spec', 'id', 1);

-- Триггерная функция
CREATE FUNCTION spec_trg() RETURNS TRIGGER AS $$
DECLARE
    v INT;
BEGIN
    v := (to_jsonb(NEW) ->> TG_ARGV[0])::INT;
    UPDATE spec SET max_value = v
    WHERE table_name = TG_TABLE_NAME
      AND column_name = TG_ARGV[0]
      AND max_value < v;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ХП
CREATE FUNCTION next_id(t TEXT, c TEXT) RETURNS INT AS $$
DECLARE
    v        INT;
    new_id   INT;
    col_type TEXT;
    n        INT;
    base     TEXT;
    trg_name TEXT;
    i        INT := 0;
BEGIN
    -- существование таблицы
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = current_schema() AND table_name = t) THEN
        RAISE EXCEPTION 'Таблица "%" не существует', t USING ERRCODE = 'U0001';
    END IF;

    -- существование столбца
    SELECT data_type INTO col_type FROM information_schema.columns
    WHERE table_schema = current_schema() AND table_name = t AND column_name = c;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Столбец "%" в таблице "%" не существует', c, t
            USING ERRCODE = 'U0002';
    END IF;

    -- целокислинность типа
    IF col_type NOT IN ('smallint', 'integer', 'bigint') THEN
        RAISE EXCEPTION 'Столбец "%"."%" имеет тип %, а не целочисленный', t, c, col_type
            USING ERRCODE = 'U0003';
    END IF;


    UPDATE spec SET max_value = max_value + 1
    WHERE table_name = t AND column_name = c
    RETURNING max_value INTO v;
    IF FOUND THEN
        RETURN v;
    END IF;

    EXECUTE format('SELECT COALESCE(MAX(%I), 0) + 1 FROM %I', c, t) INTO v;

    new_id := next_id('spec', 'id');
    INSERT INTO spec VALUES (new_id, t, c, v);

    SELECT count(*) INTO n FROM pg_trigger
    WHERE tgrelid = quote_ident(t)::regclass AND NOT tgisinternal;

    base := t || '_' || c || '_' || (n + 1);
    trg_name := base;

    WHILE EXISTS (SELECT 1 FROM pg_class WHERE relname = trg_name)
       OR EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgname = trg_name AND tgrelid = quote_ident(t)::regclass)
       OR EXISTS (SELECT 1 FROM pg_proc WHERE proname = trg_name)
    LOOP
        i := i + 1;
        trg_name := base || '_' || i;
    END LOOP;

    EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT OR UPDATE ON %I
         FOR EACH ROW EXECUTE FUNCTION spec_trg(%L)',
        trg_name, t, c);

    RETURN v;
END;
$$ LANGUAGE plpgsql;




CREATE TABLE test (id INT);
INSERT INTO test VALUES (10);

SELECT next_id('test', 'id');
SELECT * FROM spec ORDER BY id; 

DO $$ BEGIN
    PERFORM next_id('no_table', 'id');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '% : %', SQLSTATE, SQLERRM;
END $$;

DO $$ BEGIN
    PERFORM next_id('test', 'no_col');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '% : %', SQLSTATE, SQLERRM;
END $$;

CREATE TABLE test3 (name TEXT, val INT);
DO $$ BEGIN
    PERFORM next_id('test3', 'name');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '% : %', SQLSTATE, SQLERRM;
END $$;

SELECT * FROM spec ORDER BY id;  

CREATE TABLE test2 (num_value1 INT, num_value2 INT);
SELECT next_id('test2', 'num_value1');   
SELECT next_id('test2', 'num_value2');  

CREATE TABLE test3_val_1 (x INT);
SELECT next_id('test3', 'val');       

INSERT INTO test3 (val) VALUES (40);
SELECT * FROM spec ORDER BY id;

SELECT c.relname AS table_name, t.tgname AS trigger_name
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
WHERE NOT t.tgisinternal
ORDER BY 1, 2;



DROP TABLE test, test2, test3, test3_val_1, spec;
DROP FUNCTION next_id(TEXT, TEXT);
DROP FUNCTION spec_trg();