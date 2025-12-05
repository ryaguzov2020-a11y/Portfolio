
--Интерактивная версия дашборда доступна по запросу. 
--Ввиду ограничений Power BI Desktop на публикацию в интернете по ссылке представлен статичный обзор в PDF».
--https://drive.google.com/drive/folders/14k6fbZAzyZGh0N2A5EzM_ff0Qf8wrLjP?usp=drive_link

--Информация о таблице UberRides

--Date - дата бронирования (заказа)
--Time - время бронирования (заказа)
--Booking ID - Уникальный идентификатор бронирования поездки
--Booking Status - Статус бронирования
--Customer ID	- Уникальный идентификатор клиента
--Vehicle Type - тип транспортного средства (Go Mini, Go Sedan, Auto, eBike/Bike, UberXL, Premier Sedan)
--Pickup Location - начальное место посадки
--Drop Location - конечное место высадки
--Avg VTAT - Среднее время прибытия водителя к месту посадки (мин)
--Avg CTAT - Средняя продолжительность поездки от места посадки до места назначения (мин)
--Cancelled Rides by Customer - поездка, отмененная клиентом
--Reason for cancelling by Customer - причина отмены поездки клиентом
--Cancelled Rides by Driver - поездка, отмененная водителем
--Driver Cancellation Reason - причина отмены поездки водителем
--Incomplete Rides - незавершенные поездки
--Incomplete Rides Reason - Причина незавершённой поездки
--Booking Value - стоимость поездки
--Ride Distance - расстояние, пройденное за поездку
--Driver Ratings - Оценка, присвоенная водителю (по шкале от 1 до 5)
--Customer Rating - Оценка, присвоенная клиенту (по шкале от 1 до 5)
--Payment Method - Способ оплаты (UPI, наличные, кредитная карта, Uber Wallet, дебетовая карта)

--Удаляем таблицы, если существуют
DROP TABLE IF EXISTS UberRides;
DROP TABLE IF EXISTS UberRides_Backup;

-- Создаем таблицу
CREATE TABLE UberRides(
Date Nvarchar(50),
Time Nvarchar(50),
Booking_ID Nvarchar(50),
Booking_Status Nvarchar(50),
Customer_ID Nvarchar(50),
Vehicle_Type Nvarchar(50), 
Pickup_Location Nvarchar(50),
Drop_Location Nvarchar(50),
Avg_VTAT Nvarchar(50),
Avg_CTAT Nvarchar(50),
Cancelled_Rides_by_Customer Nvarchar(50),
Reason_for_cancelling_by_Customer Nvarchar(50),
Cancelled_Rides_by_Driver Nvarchar(50),
Driver_Cancellation_Reason Nvarchar(50),
Incomplete_Rides Nvarchar(50),
Incomplete_Rides_Reason Nvarchar(50),
Booking_Value Nvarchar(50),
Ride_Distance Nvarchar(50),
Driver_Ratings Nvarchar(50),
Customer_Rating Nvarchar(50),
Payment_Method Nvarchar(50)
);

--Этап 1.Загружаем данные
BULK INSERT UberRides
FROM "C:\Users\ryagu\Desktop\Portfolio Project\ncr_ride_bookings.csv"
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Пропустить строку заголовков
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
	CODEPAGE = '65001'
);

-- Создаем бэкап таблицы
SELECT * 
INTO UberRides_Backup 
FROM UberRides;

SELECT *
FROM UberRides;

--Этап 2.Корректировка форматов данных
ALTER TABLE UberRides ALTER COLUMN Date date;
ALTER TABLE UberRides ALTER COLUMN Time time;
ALTER TABLE UberRides ALTER COLUMN Avg_VTAT float;
ALTER TABLE UberRides ALTER COLUMN Avg_CTAT float;
ALTER TABLE UberRides ALTER COLUMN Cancelled_Rides_by_Customer int;
ALTER TABLE UberRides ALTER COLUMN Cancelled_Rides_by_Driver int;
ALTER TABLE UberRides ALTER COLUMN Incomplete_Rides int;
ALTER TABLE UberRides ALTER COLUMN Booking_Value int;
ALTER TABLE UberRides ALTER COLUMN Ride_Distance float;
ALTER TABLE UberRides ALTER COLUMN Driver_Ratings float;
ALTER TABLE UberRides ALTER COLUMN Customer_Rating float;

--Типы данных столбцов
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'UberRides';

--Этап 3. Заполнение NULL-значений.

--3.1. Для столбца Cancelled_Rides_by_Customer делаем флаг. 1 - поездка отменена клиентом, 0 - не отменена клиентом
UPDATE UberRides
SET Cancelled_Rides_by_Customer = CASE WHEN Cancelled_Rides_by_Customer IS NULL THEN 0
								  ELSE Cancelled_Rides_by_Customer
								  END
FROM UberRides;

--3.2. Для столбца Cancelled_Rides_by_Driver делаем флаг. 1 - поездка отменена водителем, 0 - не отменена водителем
UPDATE UberRides
SET Cancelled_Rides_by_Driver = CASE WHEN Cancelled_Rides_by_Driver IS NULL THEN 0
								  ELSE Cancelled_Rides_by_Driver
								  END
FROM UberRides;

--3.3. Для столбца Incomplete_Rides делаем флаг. 1 - поездка не завершена, 0 - поездка завершена
UPDATE UberRides
SET Incomplete_Rides = CASE WHEN Incomplete_Rides IS NULL THEN 0
								  ELSE Incomplete_Rides
								  END
FROM UberRides;

--3.4. NULL-значения в столбцах Reason_for_cancelling_by_Customer, Driver_Cancellation_Reason, Incomplete_Rides_Reason
--можно оставить, т.к. причины отмены нет, если поездка не отменена. Если поездка отменена или не завершилась, то причина указана.

--3.5. Посмотрим на значения в столбце Booking_Status
SELECT DISTINCT(Booking_Status)
FROM UberRides;

--Значения, которые мы видим - 'No Driver Found', 'Incomplete', 'Completed', 'Cancelled by Driver', 'Cancelled by Customer'
--Значение 'No Driver Found' означает, что водитель не был найден, т.е. поездка не состоялась. Какая-либо полезная 
--информация по данной группе отсутствует. Эти строки можно удалить.
DELETE FROM UberRides
WHERE Booking_Status = 'No Driver Found';

--3.6. Значения Avg_CTAT (Средняя продолжительность поездки) имеет NULL, там где 
-- Cancelled_Rides_by_Customer = 1 и Cancelled_Rides_by_Driver = 1. Т.е. нет средней продолжительности поездки, т.к.
-- поездка была отменена. Что логично, поэтому оставляем, как есть.

--3.7. Смотрим на столбцы Booking_Value, Ride_Distance, Driver_Ratings, Customer_Rating

--Столбец Booking_Value и Ride_Distance имеют NULL, там где Cancelled_Rides_by_Customer = 1 и Cancelled_Rides_by_Driver = 1. 
--При этом для Incomplete_Rides_Reason = 1 null-ы отсутствуют, т.к. хоть поездка не завершилась до конца, оплата была произведена 
--и какое-то определенное расстояние было пройдено. При этом Столбец Driver_Ratings и Customer_Rating имеет NULL, там где Incomplete_Rides_Reason = 1.
--Возможно, оценку водителю и клиенту можно поставить только при завершении поездки.
--Столбец Driver_Ratings и Customer_Rating имеет NULL, там где Cancelled_Rides_by_Customer = 1, Cancelled_Rides_by_Driver = 1, т.к.
--поездка была отменена.

--3.8. Столбец Payment_Method имеет NULL, там где Cancelled_Rides_by_Customer = 1 и Cancelled_Rides_by_Driver = 1. Оставляем.

--3.9. В целом набор данных готов для построения визуализаций. Null значения мы не заполняем, поскольку они выглядят логично.
-- Некорректное заполнение Null-значений может привести к искажению данных.

SELECT *
FROM UberRides;

--Этап 4. Создание дополнительных признаков для анализа

SELECT Date, Time, DATENAME(MONTH, Date) AS Month,
	   DATEPART(MONTH, Date) AS MonthNumber,
	   DATENAME(WEEKDAY, Date) AS Weekday,
	   DATEPART(WEEKDAY, Date) AS WeekdayNumber,
	   DATENAME(HOUR, Time) AS Hour
FROM UberRides;

--добавляем новые столбцы 
ALTER TABLE UberRides 
ADD Month NVARCHAR(50) NULL,
	MonthNumber INT NULL,
	Weekday NVARCHAR(50) NULL,
	WeekdayNumber INT NULL,
	Hour INT NULL;

SELECT *
FROM UberRides;

--Заполняем столбцы данными
UPDATE UberRides
SET Month = DATENAME(MONTH, Date),
	MonthNumber = DATEPART(MONTH, Date),
	Weekday = DATENAME(WEEKDAY, Date),
	WeekdayNumber = DATEPART(WEEKDAY, Date),
	Hour = DATENAME(HOUR, Time);


--Этап 5.

-- Общая сумма выручки
SELECT SUM(Booking_Value)
FROM UberRides;

-- Количество поездок
SELECT COUNT(Booking_ID)
FROM UberRides;

--Средняя стоимость поездки
SELECT AVG(Booking_Value)
FROM UberRides;

--Динамика выручки по месяцам
SELECT Month, SUM(Booking_Value)
FROM UberRides
GROUP BY Month, MonthNumber
ORDER BY MonthNumber;

--Количество поездок по месяцам
SELECT Month, COUNT(Booking_ID)
FROM UberRides
GROUP BY Month, MonthNumber
ORDER BY MonthNumber;

--Выручка по способу оплаты
SELECT Payment_Method, SUM(Booking_Value)
FROM UberRides
GROUP BY Payment_Method
ORDER BY 2 DESC;

--Метрики в разрезе типа транспортного средства
SELECT Vehicle_Type, 
	   SUM(Booking_Value) AS Total_Value, 
	   COUNT(Booking_ID) AS Count_of_Bookings, 
	   ROUND(AVG(Avg_VTAT),2) AS Avg_VTAT, 
	   ROUND(AVG(Avg_CTAT),2) AS Avg_CTAT, 
	   SUM(Ride_Distance) AS Total_Ride_Distance, 
	   ROUND(AVG(Ride_Distance),2) AS Avg_Ride_Distance
FROM UberRides
GROUP BY Vehicle_Type;

-- Отмены
CREATE OR ALTER VIEW BookingStatusVIEW AS 
	WITH BookingStatusInfo AS 
		(SELECT Booking_Status, COUNT(Booking_ID) AS Count_of_Bookings
		FROM UberRides
		GROUP BY Booking_Status)

	SELECT Booking_Status, Count_of_Bookings, 
		   ROUND(CAST(Count_of_Bookings AS float)/CAST(Total_Bookings AS float)*100, 2) AS Booking_Percentage
	FROM
		(SELECT Booking_Status, Count_of_Bookings,
			   SUM(Count_of_Bookings) OVER() AS Total_Bookings
		FROM BookingStatusInfo) AS t1;

SELECT *
FROM BookingStatusVIEW;

--сколько всего отмененных поездок.
SELECT SUM(Count_of_Bookings) AS Cancelling_Count, 
	   SUM(Booking_Percentage) AS Cancelling_Persentage
FROM BookingStatusVIEW
WHERE Booking_Status LIKE 'Cancelled%';

--причины отмены поездки клиентом
WITH CancellingByCustomerInfo AS
(SELECT Reason_for_cancelling_by_Customer, COUNT(Cancelled_Rides_by_Customer) AS Reason_Count
FROM UberRides
WHERE Reason_for_cancelling_by_Customer IS NOT NULL
GROUP BY Reason_for_cancelling_by_Customer)

SELECT Reason_for_cancelling_by_Customer,
	   Reason_Count,
	   ROUND(CAST(Reason_Count AS float)/CAST(Total_Reason_Count AS float) * 100, 2) AS Reason_Percentage
FROM
(SELECT Reason_for_cancelling_by_Customer, Reason_Count,
	   SUM(Reason_Count) OVER () AS Total_Reason_Count
FROM CancellingByCustomerInfo) AS t1
ORDER BY Reason_Percentage DESC;

--причины отмены поездки водителем
WITH CancellingByDriverInfo AS
(SELECT Driver_Cancellation_Reason, COUNT(Cancelled_Rides_by_Driver) AS Reason_Count
FROM UberRides
WHERE Driver_Cancellation_Reason IS NOT NULL
GROUP BY Driver_Cancellation_Reason)

SELECT Driver_Cancellation_Reason,
	   Reason_Count,
	   ROUND(CAST(Reason_Count AS float)/CAST(Total_Reason_Count AS float) * 100, 2) AS Reason_Percentage
FROM
(SELECT Driver_Cancellation_Reason, Reason_Count,
	   SUM(Reason_Count) OVER () AS Total_Reason_Count
FROM CancellingByDriverInfo) AS t1
ORDER BY Reason_Percentage DESC;

--причины незавершенной поездки
WITH IncompleteRidesReasonInfo AS
(SELECT Incomplete_Rides_Reason, COUNT(Incomplete_Rides_Reason) AS Reason_Count
FROM UberRides
WHERE Incomplete_Rides_Reason IS NOT NULL
GROUP BY Incomplete_Rides_Reason)

SELECT Incomplete_Rides_Reason,
	   Reason_Count,
	   ROUND(CAST(Reason_Count AS float)/CAST(Total_Reason_Count AS float) * 100, 2) AS Reason_Percentage
FROM
(SELECT Incomplete_Rides_Reason, Reason_Count,
	   SUM(Reason_Count) OVER () AS Total_Reason_Count
FROM IncompleteRidesReasonInfo) AS t1
ORDER BY Reason_Percentage DESC;

SELECT *
FROM UberRides;

--Количество поездок всего и количество оцененных поездок 
SELECT COUNT(Booking_ID), COUNT(Driver_Ratings), COUNT(Customer_Rating)
FROM UberRides;

--Рейтинг по типу транспортного средства
SELECT Vehicle_Type, COUNT(Vehicle_Type) AS Count_Of_Bookings, 
	   ROUND(AVG(Driver_Ratings), 3) AS Avg_Driver_Ratings, 
	   ROUND(AVG(Customer_Rating), 3) AS Avg_Customer_Rating
FROM UberRides
WHERE Driver_Ratings IS NOT NULL AND Customer_Rating IS NOT NULL
GROUP BY Vehicle_Type
ORDER BY Avg_Driver_Ratings DESC;

--Локации

SELECT Pickup_Location, Vehicle_Type, COUNT(Booking_ID) AS Booking_Count
FROM UberRides
GROUP BY Pickup_Location, Vehicle_Type
ORDER BY Vehicle_Type, Booking_Count DESC;

select *
from UberRides;

SELECT Drop_Location, COUNT(Booking_ID) AS Booking_Count
FROM UberRides
GROUP BY Drop_Location
ORDER BY Booking_Count DESC;


SELECT *
FROM UberRides;

