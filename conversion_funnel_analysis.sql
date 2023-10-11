use mavenfuzzyfactory;

-- BUilding a conversion funnels

/*
Business Context
we want to build a mini conversion funnel, from /lander-2 to /cart page
we want to know how many people reach each step, and also dropoff rates
Consider /lander-2 traffic only
*/

/*
step-1: select all pageviews for relevant sessions
step-2: identify each relevant pageview as the specific funnel step
step-3: create the session-level conversion funnel view
step-4: aggregate the data to assess funnel performance
*/

-- Step-1:selecting all pageviews for relevant sessions
SELECT 
    website_sessions.website_session_id,
    website_pageviews.pageview_url,
    website_pageviews.created_at AS pageview_created_at,
    CASE
        WHEN pageview_url = '/lander-2' THEN 1
        ELSE 0
    END AS lander_2,
    CASE
        WHEN pageview_url = '/products' THEN 1
        ELSE 0
    END AS product_page,
    CASE
        WHEN pageview_url = '/cart' THEN 1
        ELSE 0
    END AS cart_page,
    CASE
        WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1
        ELSE 0
    END AS mr_fuzzy_page
FROM
    website_sessions
        LEFT JOIN
    website_pageviews ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE
    website_sessions.created_at BETWEEN '2014-01-01' AND '2014-02-01'
        AND website_pageviews.pageview_url IN ('/lander-2' , '/products',
        '/the-original-mr-fuzzy',
        '/cart')
ORDER BY website_sessions.website_session_id , website_pageviews.created_at;



-- writing the previous query using sub-query
-- creating temporary table
CREATE TEMPORARY TABLE session_level_made_it_flag
SELECT 
    website_session_id,
    MAX(product_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_it
FROM
    (SELECT 
        website_sessions.website_session_id,
            website_pageviews.pageview_url,
            CASE
                WHEN pageview_url = '/products' THEN 1
                ELSE 0
            END AS product_page,
            CASE
                WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1
                ELSE 0
            END AS mrfuzzy_page,
            CASE
                WHEN pageview_url = '/cart' THEN 1
                ELSE 0
            END AS cart_page
    FROM
        website_sessions
    LEFT JOIN website_pageviews ON website_sessions.website_session_id = website_pageviews.website_pageview_id
    WHERE
        website_sessions.created_at BETWEEN '2014-01-01' AND '2014-02-01'
            AND website_pageviews.pageview_url IN ('/lander-2' , '/products', '/the-original-mr-fuzzy', '/cart')
    ORDER BY website_sessions.website_session_id , website_pageviews.created_at) AS pageview_level
GROUP BY website_session_id
;


-- creating session level conversion funnel
SELECT 
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE
            WHEN product_made_it = 1 THEN website_session_id
            ELSE NULL
        END) AS to_product,
    COUNT(DISTINCT CASE
            WHEN mrfuzzy_made_it = 1 THEN website_session_id
            ELSE NULL
        END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE
            WHEN cart_it = 1 THEN website_session_id
            ELSE NULL
        END) AS to_cart
FROM
    session_level_made_it_flag;
    

--  aggregate the data to assess funnel performance
SELECT 
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE
            WHEN product_made_it = 1 THEN website_session_id
            ELSE NULL
        END) /COUNT(DISTINCT website_session_id) AS clicked_to_product,
    COUNT(DISTINCT CASE
            WHEN mrfuzzy_made_it = 1 THEN website_session_id
            ELSE NULL
        END)/COUNT(DISTINCT website_session_id) AS clicked_to_mrfuzzy,
    COUNT(DISTINCT CASE
            WHEN cart_it = 1 THEN website_session_id
            ELSE NULL
        END)/COUNT(DISTINCT website_session_id) AS clicked_to_cart
FROM
    session_level_made_it_flag;