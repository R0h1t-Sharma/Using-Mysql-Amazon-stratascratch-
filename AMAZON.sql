create database amazon;
use amazon;
-- 1 You are provided with a transactional dataset from Amazon that contains detailed information about sales across different products 
-- and marketplaces. Your task is to list the top 3 sellers in each product category for January.
---- The output should contain 'seller_id' , 'total_sales' ,'product_category' , 'market_place', and 'month'.
WITH january_sales AS (SELECT *
FROM sales_data
WHERE month = '2024-01'),
ranked_sales AS (
SELECT seller_id,total_sales,product_category,market_place,
month,
DENSE_RANK() OVER (PARTITION BY product_category ORDER BY total_sales DESC) AS sales_rank
FROM january_sales)
SELECT seller_id,total_sales,product_category,market_place,
month
FROM ranked_sales
WHERE sales_rank <= 3
ORDER BY product_category, sales_rank
LIMIT 3;

--- 2 You are given a dataset from Amazon that tracks and aggregates user activity on their platform in certain time periods. 
-- For each device type, find the time period with the highest number of active users.
-- The output should contain 'user_count', 'time_period', and 'device_type',
--  where 'time_period' is a concatenation of 'start_timestamp' and 'end_timestamp', like ; "start_timestamp to end_timestamp"
WITH ranked_activity AS (
    SELECT user_count, CONCAT(start_timestamp, ' to ', end_timestamp) AS time_period, device_type, 
    RANK() OVER (PARTITION BY device_type ORDER BY user_count DESC) AS rnk 
    FROM user_activity
)
SELECT user_count, time_period, device_type 
FROM ranked_activity 
WHERE rnk = 1;

-- 3 You have been asked to compare sales of the current month, May, to those of the previous month, April.
--- the company requested that you only display products whose sales (UNITS SOLD * PRICE) have increased by more than 10% from the 
--- previous month to the current month.
--- Your output should include the product id and the percentage growth in sales.
WITH monthly_sales AS (SELECT product_id,
SUM(CASE WHEN MONTH(date) = 4 AND YEAR(date) = 2022 THEN units_sold * cost_in_dollars ELSE 0 END) AS april_sales,
SUM(CASE WHEN MONTH(date) = 5 AND YEAR(date) = 2022 THEN units_sold * cost_in_dollars ELSE 0 END) AS may_sales
FROM online_orders
WHERE YEAR(date) = 2022 AND MONTH(date) IN (4, 5)
GROUP BY product_id)
SELECT product_id,
ROUND(((may_sales - april_sales) / NULLIF(april_sales, 0) * 100), 2) AS percentage_growth
FROM monthly_sales
WHERE april_sales > 0 AND (may_sales - april_sales) / NULLIF(april_sales, 0) > 0.10  -- More than 10% increase
ORDER BY product_id;


 ---- 4 .Find the most expensive products on Amazon for each product category. Output category, product name and the price (as a number)
 --- data is error 
 -- 5 
 -- Given a table of purchases by date, calculate the month-over-month percentage change in revenue.
 -- The output should include the year-month date (YYYY-MM) and percentage change, rounded to the 2nd decimal point, and 
 --- sorted from the beginning of the year to the end of the year.
-- The percentage change column will be populated from the 2nd month forward and can be calculated as ((this month's revenue - last month's revenue) / last month's revenue)*100 

SELECT current.ym,
ROUND((current.total_revenue - COALESCE(previous.total_revenue, 0)) 
        / NULLIF(previous.total_revenue, 0) * 100,2) AS revenue_diff_pct
FROM (SELECT DATE_FORMAT(created_at, '%Y-%m') AS ym,
SUM(value) AS total_revenue
FROM sf_transactions
GROUP BY ym
) AS current
LEFT JOIN (SELECT DATE_FORMAT(created_at, '%Y-%m') AS ym,
SUM(value) AS total_revenue
FROM sf_transactions
GROUP BY ym
) AS previous ON previous.ym = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(current.ym, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m')
ORDER BY current.ym;

    
    
-- 6 Find the best selling item for each month (no need to separate months by year) where the biggest total invoice was paid.
--- The best selling item is calculated using the formula (unitprice * quantity). Output the month, 
-- the description of the item along with the amount paid.
WITH monthly_sales AS (SELECT DATE_FORMAT(invoicedate, '%Y-%m') AS month,description,
SUM(quantity * unitprice) AS total_amount
FROM online_retail
GROUP BY month, description)
SELECT month,description,total_amount
FROM monthly_sales AS ms
WHERE total_amount = (SELECT MAX(total_amount) 
FROM monthly_sales 
WHERE month = ms.month)
ORDER BY month;

-- 7 You have been asked to find the employees with the highest and lowest salary.
-- Your output should include the employee's ID, salary, and department, as well as a column salary_type that categorizes the output by:
--- 'Highest Salary' represents the highest salary
--- 'Lowest Salary' represents the lowest salary
WITH salary_ranks AS (
SELECT worker_id,salary,department,
RANK() OVER (ORDER BY salary DESC) AS salary_rank_desc,
RANK() OVER (ORDER BY salary ASC) AS salary_rank_asc
FROM worker)
SELECT worker_id,salary,department,
CASE WHEN salary_rank_desc = 1 THEN 'Highest Salary' 
WHEN salary_rank_asc = 1 THEN 'Lowest Salary'
END AS salary_type
FROM salary_ranks
WHERE salary_rank_desc = 1 OR salary_rank_asc = 1;

-- 8-- Find the lowest order cost of each customer.
-- Output the customer id along with the first name and the lowest order price.
SELECT c.id AS customer_id, c.first_name, o.total_order_cost
FROM customers c
JOIN (
    SELECT cust_id, total_order_cost,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY total_order_cost ASC) AS rn
    FROM orders
) o ON c.id = o.cust_id
WHERE o.rn = 1;

-- 9 You have been asked to find the employee with the highest salary in each department.
-- Output the department name, full name of the employee(s), and corresponding salary.
SELECT department, 
CONCAT(first_name, ' ', last_name) AS full_name, 
salary FROM (
SELECT worker_id, first_name, last_name, salary, department,
RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
FROM worker) AS ranked_employees
WHERE salary_rank = 1;

--- 10 Find the first 50% records of the dataset.
WITH ranked_workers AS (SELECT *,
ROW_NUMBER() OVER (ORDER BY worker_id) AS rn,COUNT(*) 
OVER () AS total_count FROM worker)
 SELECT * FROM ranked_workers WHERE rn <= total_count / 2;
 
 -- 11.You have been asked to find the fifth highest salary without using TOP or LIMIT.
-- Note: Duplicate salaries should not be removed.
SELECT salary
FROM (SELECT salary, 
DENSE_RANK() OVER (ORDER BY salary DESC) AS salary_rank
FROM worker) 
ranked_salaries
WHERE salary_rank = 5;

-- 12 Determine the highest salary and employee id for each department.
-- Your output should contain the department, worker id and their corresponding salary.
-- Note: In the event of a tie, output both worker id's
SELECT department, worker_id, salary
FROM (
    SELECT department, worker_id, salary,
           DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
    FROM worker
) ranked_salaries
WHERE salary_rank = 1;

-- 13 --Find the top ten highest paid employees.
-- Your output should include the worker id,  salary and department.
-- Sort records based on the salary in descending order.
SELECT worker_id,salary,department
FROM (
    SELECT worker_id,salary,department,
           ROW_NUMBER() OVER (ORDER BY salary DESC) AS salary_rank
    FROM worker
) ranked_employees
WHERE salary_rank <= 10
ORDER BY salary DESC;

-- 14 --It's time to find out who is the top employee. You've been tasked with finding the employee (or employees,
--  in the case of a tie) who have received the most votes.
-- A vote is recorded when a customer leaves their 10-digit phone number in the free text customer_response column of their 
-- sign up response (occurrence of any number sequence with exactly 10 digits is considered as a phone number)
WITH response_counts AS (
    SELECT employee_id, 
           COUNT(*) AS vote_count
    FROM customer_responses
    WHERE customer_response REGEXP '[0-9]{10}'
    GROUP BY employee_id
),
ranked_responses AS (
    SELECT employee_id, 
           vote_count,
           RANK() OVER (ORDER BY vote_count DESC) AS rnk
    FROM response_counts
)
SELECT employee_id, 
       vote_count
FROM ranked_responses
WHERE rnk = 1;

-- 15 -You've been asked by Amazon to find the shipment_id and weight of the third heaviest shipment.
-- Output the shipment_id, and total_weight for that shipment_id.
-- In the event of a tie, do not skip ranks.
WITH ranked_shipments AS (
    SELECT shipment_id, weight,
           DENSE_RANK() OVER (ORDER BY weight DESC) AS weight_rank
    FROM amazon_shipment
)
SELECT shipment_id, weight
FROM ranked_shipments
WHERE weight_rank = 3;
 
 -- 16 -Amazon's information technology department is looking for information on employees' most recent logins.
-- The output should include all information related to each employee's most recent login.
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY worker_id ORDER BY login_timestamp DESC) AS rn
    FROM worker_logins
) AS recent_logins
WHERE rn = 1;

-- 17 --Given the users' sessions logs on a particular day, calculate how many hours each user was active that day.
-- Note: The session starts when state=1 and ends when state=0.
SELECT cust_id,SUM(active_duration)/3600 AS active_hours 
FROM (SELECT state_start.cust_id,
TIMESTAMPDIFF(SECOND,state_start.timestamp,state_end.timestamp) AS active_duration
FROM (SELECT cust_id,timestamp,LEAD(timestamp) 
OVER (PARTITION BY cust_id ORDER BY timestamp) AS next_timestamp 
FROM cust_tracking WHERE state = 1) AS state_start
 JOIN 
 (SELECT cust_id,timestamp
 FROM cust_tracking
 WHERE state = 0) AS state_end 
 ON state_start.cust_id = state_end.cust_id
 AND state_start.next_timestamp = state_end.timestamp) AS durations
 GROUP BY cust_id;

-- 18 - Given a phone log table that has information about callers' call history, find out the callers 
-- whose first and last calls were to the same person on a given day. Output the caller ID, recipient ID, and the date called.
WITH call_ranks AS (
    SELECT 
        caller_id,
        recipient_id,
        date_called,
        ROW_NUMBER() OVER (PARTITION BY caller_id, DATE(date_called) ORDER BY date_called) AS rn_first,
        ROW_NUMBER() OVER (PARTITION BY caller_id, DATE(date_called) ORDER BY date_called DESC) AS rn_last
    FROM caller_history
)
SELECT 
    first.caller_id,
    first.recipient_id,
    first.date_called
FROM call_ranks AS first
JOIN call_ranks AS last ON first.caller_id = last.caller_id 
WHERE first.rn_first = 1 
  AND last.rn_last = 1 
  AND first.recipient_id = last.recipient_id;

-- 19 --
WITH department_sizes AS (
SELECT department_id, COUNT(*) AS employee_count, 
ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS dept_rank 
FROM az_employees 
GROUP BY department_id),
largest_department AS (SELECT department_id FROM department_sizes WHERE dept_rank = 1)
SELECT first_name, last_name 
FROM az_employees 
WHERE department_id IN (SELECT department_id FROM largest_department) 
AND position LIKE '%manager%';

-- 20 --You are given a table of tennis players and their matches that they could either win (W) or lose (L). 
-- Find the longest streak of wins. A streak is a set of consecutive won matches of one player. 
-- The streak ends once a player loses their next match. Output the ID of the player or players and the length of the streak.

WITH streaks AS (
SELECT player_id,match_date,match_result,
SUM(CASE WHEN match_result = 'W' THEN 0 ELSE 1 END) 
OVER (PARTITION BY player_id ORDER BY match_date) AS streak_group
FROM players_results),
win_streaks AS (
SELECT player_id,
COUNT(*) AS win_count
FROM streaks
WHERE match_result = 'W'
GROUP BY player_id, streak_group)
SELECT player_id,
MAX(win_count) AS longest_streak
FROM win_streaks
GROUP BY player_id;

























    










    

