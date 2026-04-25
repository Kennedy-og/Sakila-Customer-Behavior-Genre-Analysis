-- Customer Rental Behavior & Genre Preference Analysis
-- Dataset: Sakila

-- ============================================================
-- 1. CUSTOMER RENTAL SUMMARY
-- Purpose:
-- Measure how often each customer rents and how much they spend.
-- ============================================================

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COALESCE(r.total_rentals, 0) AS total_rentals,
    COALESCE(p.total_spent, 0) AS total_spent,
    ROUND(
        COALESCE(p.total_spent, 0) / NULLIF(COALESCE(r.total_rentals, 0), 0), -- More explanations needed
        2
    ) AS avg_spent_per_rental,
    c.active
FROM customer c
LEFT JOIN (
    SELECT
        customer_id,
        COUNT(*) AS total_rentals
    FROM rental
    GROUP BY customer_id
) r
    ON c.customer_id = r.customer_id
LEFT JOIN (
    SELECT
        customer_id,
        SUM(amount) AS total_spent
    FROM payment
    GROUP BY customer_id
) p
    ON c.customer_id = p.customer_id
ORDER BY total_spent DESC, total_rentals DESC
limit 20;


-- ============================================================
-- 2. ACTIVE VS INACTIVE CUSTOMER BEHAVIOR
-- Purpose:
-- Compare behavior between active and inactive customers.
-- ============================================================

SELECT
    c.active,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COALESCE(SUM(p.amount), 0) AS total_revenue,
    ROUND(COALESCE(AVG(p.amount), 0), 2) AS avg_payment_amount,ROUND(SUM(COALESCE((p.amount), 0)/COUNT(c.customer_id))) AS MEDIAN, -- what does COALESCE and the figures in the parentisis mean
    COUNT(DISTINCT r.rental_id) AS total_rentals
FROM customer c
LEFT JOIN payment p
    ON c.customer_id = p.customer_id -- whats the diffrence BETWEEN LEFT and RIGHT JOIN
LEFT JOIN rental r
    ON c.customer_id = r.customer_id
GROUP BY c.active
ORDER BY c.active DESC;


-- ============================================================
-- 3. CUSTOMER GENRE PREFERENCE
-- Purpose:
-- Identify which genres each customer rents most often.
-- ============================================================

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    cat.name AS genre,
    COUNT(*) AS genre_rental_count
FROM customer c
JOIN rental r
    ON c.customer_id = r.customer_id
JOIN inventory i
    ON r.inventory_id = i.inventory_id
JOIN film_category fc
    ON i.film_id = fc.film_id
JOIN category cat
    ON fc.category_id = cat.category_id
GROUP BY
    c.customer_id,
    customer_name,
    cat.name
ORDER BY
    c.customer_id,
    genre_rental_count DESC;


-- ============================================================
-- 4. TOP GENRE PER CUSTOMER
-- Purpose:
-- Return the most rented genre for each customer.
-- ============================================================

WITH customer_genre_counts AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        cat.name AS genre,
        COUNT(*) AS genre_rental_count,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id
            ORDER BY COUNT(*) DESC, cat.name ASC
        ) AS rn
    FROM customer c
    JOIN rental r
        ON c.customer_id = r.customer_id
    JOIN inventory i
        ON r.inventory_id = i.inventory_id
    JOIN film_category fc
        ON i.film_id = fc.film_id
    JOIN category cat
        ON fc.category_id = cat.category_id
    GROUP BY
        c.customer_id,
        customer_name,
        cat.name
)
SELECT
    customer_id,
    customer_name,
    genre AS favorite_genre,
    genre_rental_count
FROM customer_genre_counts
WHERE rn = 1 -- why is rn = 1
ORDER BY genre_rental_count DESC, customer_id;


-- ============================================================
-- 5. TOP CUSTOMERS BY RENTAL VOLUME
-- Purpose:
-- Find the most active customers.
-- ============================================================

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(r.rental_id) AS total_rentals
FROM customer c
JOIN rental r
    ON c.customer_id = r.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY total_rentals DESC
LIMIT 10;


-- ============================================================
-- 6. TOP CUSTOMERS BY SPENDING
-- Purpose:
-- Find the highest-value customers.
-- ============================================================

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(p.amount) AS total_spent
FROM customer c
JOIN payment p
    ON c.customer_id = p.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY total_spent DESC
LIMIT 10;


-- ============================================================
-- 7. GENRE REVENUE ANALYSIS
-- Purpose:
-- Identify which genres drive the most revenue.
-- ============================================================

SELECT
    cat.name AS genre,
    SUM(p.amount) AS total_revenue,
    COUNT(DISTINCT r.rental_id) AS total_rentals
FROM payment p
JOIN rental r
    ON p.rental_id = r.rental_id
JOIN inventory i
    ON r.inventory_id = i.inventory_id
JOIN film_category fc
    ON i.film_id = fc.film_id
JOIN category cat
    ON fc.category_id = cat.category_id
GROUP BY genre
ORDER BY total_revenue DESC;


-- ============================================================
-- 8. CUSTOMER SEGMENTATION BY SPENDING
-- Purpose:
-- Group customers into value bands.
-- ============================================================

WITH customer_spend AS (
    SELECT
        customer_id ,
        SUM(amount) AS total_spent,sum(customer_id) as c
    FROM payment
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN total_spent >= 150 THEN 'High Value'
        WHEN total_spent >= 100 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spent), 2) AS avg_spent

FROM customer_spend
GROUP BY customer_segment
ORDER BY avg_spent DESC;


-- ============================================================
-- 9. MONTHLY CUSTOMER RENTAL TREND
-- Purpose:
-- Track rental activity over time.
-- ============================================================

SELECT
    DATE_FORMAT(rental_date, '%Y-%m') AS rental_month,
    COUNT(*) AS total_rentals,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM rental
GROUP BY rental_month
ORDER BY rental_month;


-- ============================================================
-- 10. CUSTOMER INSIGHT VIEW
-- Purpose:
-- Create a reusable summary view for dashboards.
-- ============================================================

CREATE OR REPLACE VIEW customer_insight_summary AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.active,
    COALESCE(r.total_rentals, 0) AS total_rentals,
    COALESCE(p.total_spent, 0) AS total_spent,
    ROUND(
        COALESCE(p.total_spent, 0) / NULLIF(COALESCE(r.total_rentals, 0), 0),
        2
    ) AS avg_spent_per_rental
FROM customer c
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS total_rentals
    FROM rental
    GROUP BY customer_id
) r
    ON c.customer_id = r.customer_id
LEFT JOIN (
    SELECT customer_id, SUM(amount) AS total_spent
    FROM payment
    GROUP BY customer_id
) p
    ON c.customer_id = p.customer_id;

SELECT * FROM customer_insight_summary ORDER BY total_spent DESC;


-- Example usage:
-- SELECT * FROM customer_insight_summary ORDER BY total_spent DESC;



WITH city_rentals AS (
    SELECT 
        ci.city,
        COUNT(r.rental_id) AS total_rentals,
        COUNT(DISTINCT c.customer_id) AS total_customers,
        SUM(p.amount) AS total_revenue
    FROM customer c
    JOIN address a ON c.address_id = a.address_id
    JOIN city ci ON a.city_id = ci.city_id
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY ci.city
)

SELECT 
    city,
    total_rentals,
    total_customers,
    total_revenue,
    ROUND(total_revenue / total_rentals, 2) AS avg_revenue_per_rental
FROM city_rentals
ORDER BY total_revenue DESC;


WITH city_genre AS (
    SELECT 
        ci.city,
        cat.name AS genre,
        COUNT(r.rental_id) AS rental_count
    FROM customer c
    JOIN address a ON c.address_id = a.address_id
    JOIN city ci ON a.city_id = ci.city_id
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film_category fc ON i.film_id = fc.film_id
    JOIN category cat ON fc.category_id = cat.category_id
    GROUP BY ci.city, cat.name
),

ranked_genre AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY city ORDER BY rental_count DESC) AS rank_num
    FROM city_genre
)

SELECT 
    city,
    genre AS top_genre,
    rental_count
FROM ranked_genre
WHERE rank_num = 1
ORDER BY rental_count DESC;
