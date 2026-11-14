
-- Спец. таблица
CREATE TABLE spec (
    id          INT,
    table_name  TEXT,
    column_name TEXT,
    max_value   INT
);

-- 2. Запись о самой спец. таблице
INSERT INTO spec VALUES (1, 'spec', 'id', 1);

-- Триггерная функция: обновляет максимум в spec только если значение его превысило.
-- Имя столбца приходит аргументом триггера (TG_ARGV[0]).
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

-- ХП: то же, что раньше, + создание триггера для новой пары (таблица, столбец)
CREATE FUNCTION next_id(t TEXT, c TEXT) RETURNS INT AS $$
DECLARE
    v      INT;
    new_id INT;
BEGIN
    UPDATE spec SET max_value = max_value + 1
    WHERE table_name = t AND column_name = c
    RETURNING max_value INTO v;
    IF FOUND THEN
        RETURN v;
    END IF;

    EXECUTE format('SELECT COALESCE(MAX(%I), 0) + 1 FROM %I', c, t) INTO v;

    new_id := next_id('spec', 'id');
    INSERT INTO spec VALUES (new_id, t, c, v);

    -- автоматическое создание триггера
    EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT OR UPDATE ON %I
         FOR EACH ROW EXECUTE FUNCTION spec_trg(%L)',
        'trg_' || t || '_' || c, t, c);

    RETURN v;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------------
-- ТЕСТЫ
------------------------------------------------------------------

CREATE TABLE test (id INT);
INSERT INTO test VALUES (10);

-- 1. Ожидается 11; spec: (1,spec,id,2) (2,test,id,11)
SELECT next_id('test', 'id');
SELECT * FROM spec ORDER BY id;

-- 2. Вставка в обход ХП с превышением максимума -> (2,test,id,50)
INSERT INTO test VALUES (50);
SELECT * FROM spec ORDER BY id;

-- 3. Вставка без превышения -> максимум остаётся 50
INSERT INTO test VALUES (5);
SELECT * FROM spec ORDER BY id;

-- 4. Обновление с превышением (5 -> 100) -> максимум 100
UPDATE test SET id = 100 WHERE id = 5;
SELECT * FROM spec ORDER BY id;

-- 5. Обновление в меньшую сторону (100 -> 60) -> максимум остаётся 100
UPDATE test SET id = 60 WHERE id = 100;
SELECT * FROM spec ORDER BY id;

-- 6. ХП продолжает с актуального максимума -> 101
SELECT next_id('test', 'id');
SELECT * FROM spec ORDER BY id;

-- 7. Таблица с двумя столбцами, у каждого свой триггер
CREATE TABLE test2 (num_value1 INT, num_value2 INT);
SELECT next_id('test2', 'num_value1');   -- 1
SELECT next_id('test2', 'num_value2');   -- 1
SELECT * FROM spec ORDER BY id;
-- (1,spec,id,4) (2,test,id,101) (3,test2,num_value1,1) (4,test2,num_value2,1)

-- 8. Растёт только первый столбец -> (3,test2,num_value1,7), второй остаётся 1
INSERT INTO test2 VALUES (7, 0);
SELECT * FROM spec ORDER BY id;

-- 9. Вставка нескольких строк -> num_value1 = 9, num_value2 = 30
INSERT INTO test2 VALUES (8, 20), (9, 30);
SELECT * FROM spec ORDER BY id;

-- 10. Проверка созданных триггеров:
-- trg_test2_num_value1, trg_test2_num_value2, trg_test_id
SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg\_%' ORDER BY tgname;

------------------------------------------------------------------
-- Очистка
------------------------------------------------------------------
DROP TABLE test, test2, spec;          -- триггеры удаляются вместе с таблицами
DROP FUNCTION next_id(TEXT, TEXT);
DROP FUNCTION spec_trg();