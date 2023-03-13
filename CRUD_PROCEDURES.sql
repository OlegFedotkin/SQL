--- 6. скрипты характерных выборок(включающие группировки, JOINы, вложенные таблицы).

--- Список всех фильмов в каждой из групп по годам.
SELECT GROUP_CONCAT(name), SUBSTRING(release_year, 1, 3) AS decade FROM movies 
	GROUP BY decade;

--- Количество фильмов в каждой из групп по годам.
SELECT COUNT(*), SUBSTRING(release_year, 1, 3) AS decade FROM movies 
	GROUP BY decade ORDER BY decade;

--- Количество фильмов в каждой из групп, где количество записей больше или равно четырем.
SELECT COUNT(*) AS total, SUBSTRING(release_year, 1, 3) AS decade 
	FROM movies GROUP BY decade HAVING total >= 4;

--- Фильмы с минимальном, максимальной и средней стоимостями.
SELECT MIN(price) AS min, MAX(price) AS max, round(AVG(price), 1) as 'avarage' FROM catalogs;

--- Отбор реквизитов с датами, выпадающими на 1 квартал 2021 года.
SELECT * FROM bank_details WHERE `year` = 2021 and `month` IN (1, 2, 3);

--- Выбор платежей с суммой больше средней.
SELECT id, amount FROM payments WHERE amount > (SELECT AVG(amount) FROM payments);

--- Отбор покупателей, сделавших хотя бы один заказ.
SELECT id, name FROM customers WHERE id IN (SELECT customer_id FROM movie_ratings); 

--- Отбор фильмов, для которых имеется рейтинг.
SELECT id, name FROM movies WHERE EXISTS (SELECT * FROM movie_ratings 
	WHERE movie_id = movies.id); 

--- Отбор группы по годам с мфксимальным количеством фильмов.
SELECT MAX(count_mov), decade FROM  (SELECT COUNT(*) AS count_mov, SUBSTRING(release_year, 1, 3) AS decade 
	FROM movies GROUP BY decade ORDER BY decade) AS new_table;

--- JOIN соединение таблиц movies и produsers.
SELECT m.name, m.release_year, p.lastname FROM movies AS m 
	JOIN produsers AS p ON p.id = m.produser_id GROUP BY p.lastname;

--- Количество активных покупателей, сделавших заказы.
SELECT COUNT(*) AS active_customers FROM customers AS c 
	JOIN payments as p ON c.id = p.customer_id WHERE c.active = 1;

--- Количество заказов фильмов, выпущенных за последние 10 лет.
SELECT COUNT(*) FROM payments AS p JOIN movies as m ON p.movie_id = m.id 
	where YEAR(CURDATE()) - release_year < 10 AS last_movies;

--- RIGHT JOIN соединение таблиц movies и countries.
SELECT m.name, m.description, с.country FROM movies AS m 
	RIGHT JOIN countries AS с ON с.id = m.country_id;

--- UPDATE-запрос с JOIN соединением таблиц movies и catalogs.
UPDATE catalogs JOIN movies ON movies.id = catalogs.movie_id SET price = price * 1.1 
	WHERE movies.release_year < 2000-01-01;

--- DELETE-запрос с JOIN соединением таблиц movies и catalogs.
SET FOREIGN_KEY_CHECKS = 0;
DELETE catalogs, movies FROM catalogs JOIN movies ON movies.id = catalogs.movie_id 
	WHERE movies.release_year < 1980-01-01;
SET FOREIGN_KEY_CHECKS = 1;

--- ОТбор фильмов по жанру и странам с группировкой по жанру.
SELECT COUNT(m.name), m.name, g.name, c.country
	FROM movies AS m
JOIN genres AS g 
	ON g.id = m.genre_id
JOIN countries AS c 
	ON c.id = m.country_id
GROUP BY m.genre_id;




--- 7. представления.

--- Представление с отбором новых фильмов с изменением порядка и переименованием столбцов.
CREATE OR REPLACE VIEW new_movies (year_release, movie_name, movie_id)
	AS SELECT release_year, name, id FROM movies WHERE release_year > 2010;


--- Представление с отбором покупателей, сделавших заказы с суммой больше средней.

CREATE OR REPLACE VIEW customers_payments 
	(customers_name, movie_name, amount) AS 
SELECT c.name, m.name, p.amount 
	FROM customers as c 
JOIN payments as p 
	ON c.id = p.customer_id 
JOIN movies as m 
	ON m.id = p.movie_id
WHERE amount > (SELECT AVG(amount) FROM payments) ORDER BY p.amount, c.name;


--- Представление с отбором покупателей и их реквизитов.

CREATE OR REPLACE VIEW customers_bank_details AS 
SELECT c.name, b.account_namber, c.phone
	FROM customers as c 
JOIN bank_details as b 
	ON c.id = b.customers_id;





--- 8. хранимые процедуры, триггеры.
--- Отбор фильмов не имеющие заказов.

DROP PROCEDURE IF EXISTS movie_not_orders;
DELIMITER //
CREATE PROCEDURE movie_not_orders()
BEGIN 
	SELECT id, name FROM movies
 		WHERE id NOT IN (SELECT customer_id FROM payments);
END //
DELIMITER ;

CALL movie_not_orders();


--- Процедура, предлагающая пользователю пять фильмом с рейтингом выше трех и его любимым жанром.

DROP PROCEDURE IF EXISTS movie_offers;
DELIMITER //
CREATE PROCEDURE movie_offers(customers_id INT)
BEGIN
	DECLARE like_genre VARCHAR(30);
	SET like_genre = (SELECT genre FROM (SELECT COUNT(g.name) 
		AS total, g.name AS genre
        FROM payments AS p
        JOIN customers AS c 
            ON c.id = customers_id 
        JOIN movies AS m 
            ON m.id = p.movie_id
        JOIN genres AS g 
            ON g.id = m.genre_id
        GROUP BY genre ORDER BY total DESC LIMIT 1) AS g_name);
       
	SELECT DISTINCT m.id, m.name FROM movies AS m
	JOIN movie_ratings AS mr 
		ON m.id = mr.movie_id AND mr.rating > 3
	JOIN payments AS p
		ON m.id != p.movie_id
	JOIN customers AS c
		ON c.id = 1
	JOIN genres AS g 
		ON g.id = m.genre_id AND g.name = like_genre
	ORDER BY rand() LIMIT 2;
END //
DELIMITER ;

CALL movie_offers(1);



--- Установка даты создания записи в таблице.

DROP TRIGGER IF EXISTS date_of_payment;
DELIMITER //
CREATE TRIGGER date_of_payment BEFORE INSERT ON payments 
FOR EACH ROW 
BEGIN
	IF NEW.payment_date IS NULL OR NEW.payment_date > CURRENT_DATE() THEN
		SET NEW.payment_date = CURRENT_TIMESTAMP;
	END IF;
END //
DELIMITER ;

INSERT INTO `payments` (movie_id, customer_id, amount) VALUES (1,2,4231.00);

--- Проверка срока действия реквизитов.

DROP TRIGGER IF EXISTS checked_date;
DELIMITER //
CREATE TRIGGER checked_date BEFORE INSERT ON bank_details
FOR EACH ROW
BEGIN 
	IF NEW.`year` <= YEAR(CURRENT_DATE()) and NEW.`month` <= MONTH(CURRENT_DATE()) 
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'INSERT Canceled. Month and year must not be in the past!';
	END IF;
END//
DELIMITER ;


INSERT INTO `bank_details` VALUES (120,1,1144459516637856,4,2020,678,'1999-04-14 10:14:53','1995-05-21 03:44:46');





