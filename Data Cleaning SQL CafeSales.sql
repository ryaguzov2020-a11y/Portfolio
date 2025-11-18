--Используемый диалект sql - T-SQL

--Этап 1. Загрузка данных

--Информация о таблице CafeSales
-- Transaction ID - уникальный идентификатор для каждой транзакции. Not-NULL, является уникальным.
-- Item - название купленного товара.
-- Quantity - количество купленного товара.
-- Price_Per_Unit - цена одной единицы товара.
-- Total_Spent - общая сумма расходов.
-- Payment Method - использованный способ оплаты.
-- Location - место совершения транзакции.
-- Transaction Date - дата транзакции.

--Информация о таблице ItemPrice
-- Item - название купленного товара.
-- Price - цена одной единицы товара.

--Удаляем таблицы, если существуют
DROP TABLE IF EXISTS CafeSales;
DROP TABLE IF EXISTS CafeSales_Backup;

-- Создаем таблицы
CREATE TABLE CafeSales(
Transaction_ID Nvarchar(50) PRIMARY KEY,
Item Nvarchar(50),
Quantity Nvarchar(50),
Price_Per_Unit Nvarchar(50), 
Total_Spent Nvarchar(50),
Payment_Method Nvarchar(50),
Location Nvarchar(50),
Transaction_Date Nvarchar(50)
);

CREATE TABLE ItemPrice(
Item Nvarchar(50) PRIMARY KEY,
Price FLOAT
);

-- Загружаем данные
BULK INSERT CafeSales
FROM "C:\Users\ryagu\Desktop\Portfolio Project\dirty_cafe_sales.csv"
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Пропустить строку заголовков
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
	CODEPAGE = '65001'
);

BULK INSERT ItemPrice
FROM "C:\Users\ryagu\Desktop\Portfolio Project\Item.csv"
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Пропустить строку заголовков
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
	CODEPAGE = '65001'
);

--Смотрим загруженные данные

SELECT *
FROM CafeSales;

SELECT *
FROM ItemPrice;

-- Создаем бэкап таблицы (на всякий случай)
SELECT * 
INTO CafeSales_Backup 
FROM CafeSales;

--Этап 2. Замена недопустимых значений (UNKNOWN и ERROR)

UPDATE CafeSales
SET Price_Per_Unit = CASE WHEN Price_Per_Unit IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Price_Per_Unit
					 END,
	Item = CASE WHEN Item IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Item
					 END,
	Quantity = CASE WHEN Quantity IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Quantity
					 END,
	Total_Spent = CASE WHEN Total_Spent IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Total_Spent
					 END,
	Payment_Method = CASE WHEN Payment_Method IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Payment_Method
					 END,
	Location = CASE WHEN Location IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Location
					 END,
	Transaction_Date = CASE WHEN Transaction_Date IN ('UNKNOWN', 'ERROR') THEN NULL
				     ELSE Transaction_Date
					 END;

--Проверяем, что замена прошла успешно.
SELECT *
FROM CafeSales;

--Этап 3. Корректировка форматов даты

--Типы данных столбцов
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CafeSales';

ALTER TABLE CafeSales ALTER COLUMN Quantity int;
ALTER TABLE CafeSales ALTER COLUMN Price_Per_Unit float;
ALTER TABLE CafeSales ALTER COLUMN Total_Spent float;
ALTER TABLE CafeSales ALTER COLUMN Transaction_Date date;

--Этап 4. Заполнение отсутствующих значений
-- 4.1. Восстановим цену товара по его названию.
-- Заполним пропуски в столбце Price_Per_Unit c помощью таблицы Item, в которой содержатся название товара и его цена.

UPDATE CafeSales
SET Price_Per_Unit = CASE WHEN C.Price_Per_Unit IS NULL THEN I.Price
					 ELSE Price_Per_Unit
					 END
FROM CafeSales C
LEFT JOIN ItemPrice I ON C.Item = I.Item;

SELECT *
FROM CafeSales;

--смотрим количество NULL в столбце Price_Per_Unit (осталось 54). Не заполнились те Price_Per_Unit, для которых в столбце Item не указан товар.

SELECT COUNT(ISNULL(Price_Per_Unit, 0)) NullCount
FROM CafeSales
WHERE Price_Per_Unit IS NULL;

-- 4.2. Столбец с названиями товаров содержит пропущенные значения (NULL).
-- Единственный вариант, как мы можем восстановить неизвестное название товара - это использовать цену товара в таблице Item
-- Однако у нас есть товары с одинаковой ценой, и мы не можем точно сказать, что товар за 4$ это Sandwitch, а не Smoothie, 
-- а товар за 3$ - это Cake, а не Juice, поэтому их можно исключить.

-- Запрос возвращает названия товаров с неуникальной ценой
SELECT Item
FROM ItemPrice
WHERE Price IN(
		SELECT Price
		FROM ItemPrice
		GROUP BY Price
		HAVING COUNT(*) > 1);

--В данном запросе подтягиваем данные из таблицы ItemPrice с условием на отсутствие товаров с неуникальной ценой.
--Далее обновляем названия товаров (C.Item = I.Item) для нулевых значений.
UPDATE C
SET C.Item = I.Item
FROM CafeSales C
LEFT JOIN ItemPrice I ON C.Price_Per_Unit = I.Price
WHERE I.Item NOT IN (SELECT Item
						FROM ItemPrice
						WHERE Price IN(
								SELECT Price
								FROM ItemPrice
								GROUP BY Price
								HAVING COUNT(*) > 1))
			AND C.Item IS NULL;

--4.3. Столбец Quantity содержит пропущенные значения (NULL). Их можно заполнить, разделив Total_Spent на Price_Per_Unit.

UPDATE CafeSales
SET Quantity = Total_Spent/Price_Per_Unit
WHERE Quantity IS NULL;

SELECT *
FROM CafeSales
WHERE Total_Spent IS NULL OR Quantity IS NULL OR Price_Per_Unit IS NULL OR Item IS NULL;

--4.4. Столбец Total_Spent содержит пропущенные значения (NULL). Их можно заполнить, умножив Quantity на Price_Per_Unit.

UPDATE CafeSales
SET Total_Spent = Quantity*Price_Per_Unit
WHERE Total_Spent IS NULL;

--4.5. Вернемся к столбцу Price_Per_Unit. Его мы можем заполнить, разделив Total_Spent на Quantity.
UPDATE CafeSales
SET Price_Per_Unit = Total_Spent/Quantity
WHERE Price_Per_Unit IS NULL;

--4.6. Теперь снова можем вернуться к Item и заполнить пропущенные значения по цене товара.

UPDATE C
SET C.Item = I.Item
FROM CafeSales C
LEFT JOIN ItemPrice I ON C.Price_Per_Unit = I.Price
WHERE I.Item NOT IN (SELECT Item
						FROM ItemPrice
						WHERE Price IN(
								SELECT Price
								FROM ItemPrice
								GROUP BY Price
								HAVING COUNT(*) > 1))
			AND C.Item IS NULL;

--4.7. Столбцы Payment_Method, Location, Transaction_Date.

--Payment_Method имеет 3178 пропусков. Этот столбец для анализа сложно будет использовать. Но удалять 3178 строк мы не можем. Оставляем, как есть.
SELECT COUNT(ISNULL(Payment_Method, '0'))
FROM CafeSales
WHERE Payment_Method IS NULL;

--То же самое с Location - 3961 пропуск. Оставляем.
SELECT COUNT(ISNULL(Location, '0'))
FROM CafeSales
WHERE Location IS NULL;

--Столбец с датами имеет 460 пропусков.
SELECT COUNT(ISNULL(Transaction_Date, '2000-01-01'))
FROM CafeSales
WHERE Transaction_Date IS NULL;
--Пропущенные даты мы заполнить не можем, поэтому удаляем null, чтобы избежать ошибок при дальнейшем анализе временного ряда.
DELETE FROM CafeSales
WHERE Transaction_Date IS NULL;

-- 4.8. Таким образом, мы заполнили все возможные пропуски. Пропуски остались там, где не узнать точное название товара по цене (456 строк на данном этапе).
-- И там где, в столбцах Price_Per_Unit, Total_Spent, Quantity два и более пропущенных значения (26 пропусков).
-- Можем удалить данные строки, т.к. никакой полезной информации они не несут.

DELETE FROM CafeSales
WHERE Total_Spent IS NULL OR Quantity IS NULL OR Total_Spent IS NULL;

DELETE FROM CafeSales
WHERE Item IS NULL;

SELECT *
FROM CafeSales;

-- 4.9. Таким образом, получаем подготовленный к дальнейшему анализу набор данных.

--Этап 5. Создание дополнительных фичей для дальнейшего анализа (например, день недели или месяц транзакции)
--5.1 Месяц транзакции

--выделяем из даты название месяца (DATENAME - возвращает часть даты в виде строки, 
--DATEPART - возвращает часть даты в виде числа, что может быть полезно при сортировке от первого к последнему месяцу). 
SELECT DATENAME(MONTH, Transaction_Date)
FROM CafeSales;

--добавляем новый столбец с названием месяца
ALTER TABLE CafeSales ADD Transaction_Month NVARCHAR(50) NULL;

--Заполняем столбец данными
UPDATE CafeSales
SET Transaction_Month = DATENAME(MONTH, Transaction_Date);

--5.2 День недели транзакции

--выделяем из даты день недели
SELECT *, DATENAME(WEEKDAY, Transaction_Date), DATEPART(WEEKDAY, Transaction_Date) --где 1 - понедельник
FROM CafeSales;

--добавляем новые столбцы
ALTER TABLE CafeSales ADD WeekdayName NVARCHAR(50) NULL;
ALTER TABLE CafeSales ADD WeekdayNumber INT NULL;

--Заполняем столбец данными
UPDATE CafeSales
SET WeekdayName = DATENAME(WEEKDAY, Transaction_Date),
	WeekdayNumber = DATEPART(WEEKDAY, Transaction_Date);

--Данные добавлены
SELECT *
FROM CafeSales;

