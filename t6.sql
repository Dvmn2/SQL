
-- 1. Создание спец. таблицы
CREATE TABLE spec (
    id          INT,
    table_name  TEXT,
    column_name TEXT,
    max_value   INT
);

-- 2. Запись о самой спец. таблице
INSERT INTO spec VALUES (1, 'spec', 'id', 1);

-- 3. Создание ХП
CREATE FUNCTION next_id(t TEXT, c TEXT) RETURNS INT AS $$
DECLARE
    v      INT;
    new_id INT;
BEGIN
    -- запись есть: инкрементируем и возвращаем
    UPDATE spec SET max_value = max_value + 1
    WHERE table_name = t AND column_name = c
    RETURNING max_value INTO v;
    IF FOUND THEN
        RETURN v;
    END IF;

    -- записи нет: ищем максимум в таблице (если пусто, вернётся 1)
    EXECUTE format('SELECT COALESCE(MAX(%I), 0) + 1 FROM %I', c, t) INTO v;

    -- id новой строки получаем рекурсивным вызовом
    new_id := next_id('spec', 'id');

    INSERT INTO spec VALUES (new_id, t, c, v);
    RETURN v;
END;
$$ LANGUAGE plpgsql;

-- 4-5. Ожидается 2; (1, spec, id, 2)
SELECT next_id('spec', 'id');
SELECT * FROM spec ORDER BY id;

-- 6-7. Ожидается 3; (1, spec, id, 3)
SELECT next_id('spec', 'id');
SELECT * FROM spec ORDER BY id;

-- 8-9. Таблица test
CREATE TABLE test (id INT);
INSERT INTO test VALUES (10);

-- 10-11. Ожидается 11; (1, spec, id, 4), (4, test, id, 11)
SELECT next_id('test', 'id');
SELECT * FROM spec ORDER BY id;

-- 12-13. Ожидается 12
SELECT next_id('test', 'id');
SELECT * FROM spec ORDER BY id;

-- 14-16. Таблица test2; ожидается 1; (5, test2, num_value1, 1)
CREATE TABLE test2 (num_value1 INT, num_value2 INT);
SELECT next_id('test2', 'num_value1');
SELECT * FROM spec ORDER BY id;

-- 17-18. Ожидается 2
SELECT next_id('test2', 'num_value1');
SELECT * FROM spec ORDER BY id;

-- 19-21. Ожидается 14; (6, test2, num_value2, 14)
INSERT INTO test2 (num_value1, num_value2) VALUES (2, 13);
SELECT next_id('test2', 'num_value2');
SELECT * FROM spec ORDER BY id;

-- 22-23. 5 вызовов; (5, test2, num_value1, 7)
SELECT next_id('test2', 'num_value1') FROM generate_series(1, 5);
SELECT * FROM spec ORDER BY id;

-- 24. Удаление ХП
DROP FUNCTION next_id(TEXT, TEXT);

-- 25. Удаление таблиц
DROP TABLE spec, test, test2;