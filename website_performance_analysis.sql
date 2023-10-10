/* 
For this analysis I'll create a temporary table first then  apply multi-step analysis
on that temporary table
*/
use mavenfuzzyfactory;
# Finding the top viewed pages
SELECT 
    pageview_url,
    COUNT(DISTINCT (website_pageview_id)) AS page_views
FROM
    website_pageviews
WHERE
    website_pageview_id < 1000
GROUP BY pageview_url
ORDER BY 2 DESC;


# Pulling the most viewed page or landing page
SELECT 
    first_pageview.website_session_id,
    website_pageviews.pageview_url AS landing_page,
    COUNT(DISTINCT first_pageview.website_session_id) AS sessions_hitting_landing
FROM
    first_pageview
        LEFT JOIN
    website_pageviews ON first_pageview.min_pageview_id = website_pageviews.website_pageview_id
GROUP BY website_pageviews.pageview_url;

# Finding most-viewed website pages, ranked by session volumne
SELECT 
    pageview_url, 
    COUNT(DISTINCT website_session_id) AS page_views
FROM
    website_pageviews
WHERE
    created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY 2 DESC;



# Pulling the list of top entry pages and rank them by volume before '2012-06-12'

-- step-1: find the first pageview for each session
-- step-2: find the url the customer saw on that first pageview
-- step-1
create temporary table first_pageview_per_session
SELECT 
    website_session_id,
    min(website_pageview_id) as first_pageview
    
from website_pageviews
where created_at < '2012-06-12'
group by website_session_id;

-- -----------
-- step-2
SELECT 
    website_pageviews.pageview_url AS landing_page_url,
    COUNT(DISTINCT first_pageview_per_session.website_session_id) AS sessions
FROM
    first_pageview_per_session
        LEFT JOIN
    website_pageviews ON first_pageview_per_session.first_pageview = website_pageviews.website_pageview_id
GROUP BY landing_page_url;



-- Analyzing landing page performance for a certain period of time

-- step-1: find the first website_pageview_id for relevant sessions
-- step-2: identify the landing page of each session
-- step-3: counting pageviews for each session to identify "bounces"
-- step-4: summarizing total sessions and bounced session, by landing page

# Step-1
SELECT 
    website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM
    website_pageviews
        INNER JOIN
    website_sessions ON website_sessions.website_session_id = website_pageviews.website_session_id
        AND website_sessions.created_at BETWEEN '2014-01-01' AND '2014-02-01'
GROUP BY website_pageviews.website_session_id;

-- creating a temporary table with the query written in step-1
create temporary table first_pageview_demo
SELECT 
    website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM
    website_pageviews
        INNER JOIN
    website_sessions ON website_sessions.website_session_id = website_pageviews.website_session_id
        AND website_sessions.created_at BETWEEN '2014-01-01' AND '2014-02-01'
GROUP BY website_pageviews.website_session_id;

-- Step-2: identify the landing page of each session
create temporary table session_wise_landing_page
select
	first_pageview_demo.website_session_id,
    website_pageviews.pageview_url as landing_page
from first_pageview_demo
	left join website_pageviews
    on website_pageviews.website_pageview_id = first_pageview_demo.min_pageview_id;
    
-- Step-3: counting pageviews for each session to identify "bounces"
create temporary table bounced_session_only
SELECT 
    session_wise_landing_page.website_session_id,
    session_wise_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_page_viewd
FROM
    session_wise_landing_page
        LEFT JOIN
    website_pageviews ON website_pageviews.website_session_id = session_wise_landing_page.website_session_id
GROUP BY session_wise_landing_page.website_session_id , session_wise_landing_page.landing_page
having count(website_pageviews.website_pageview_id) =1 -- limiting the pageview to 1
;

# finding the bounced sessions. if it is null then it's not a bounced session else it's bounced session
SELECT 
    session_wise_landing_page.landing_page,
    session_wise_landing_page.website_session_id,
    bounced_session_only.website_session_id AS bounced_session_id
FROM
    session_wise_landing_page
        LEFT JOIN
    bounced_session_only ON session_wise_landing_page.website_session_id = bounced_session_only.website_session_id
ORDER BY session_wise_landing_page.website_session_id;

-- step:4

SELECT 
    session_wise_landing_page.landing_page,
    count( distinct session_wise_landing_page.website_session_id) as sessions,
    count(distinct bounced_session_only.website_session_id) AS bounced_session,
    (count(distinct bounced_session_only.website_session_id) /count( distinct session_wise_landing_page.website_session_id)) as bounce_rate
    
FROM
    session_wise_landing_page
        LEFT JOIN
    bounced_session_only ON session_wise_landing_page.website_session_id = bounced_session_only.website_session_id

group by session_wise_landing_page.landing_page
ORDER BY session_wise_landing_page.website_session_id;





-- Assignment on calculating bounce rates for the home page

/*
Step-1: Finding the first website_pageview_id for relevant session
step-2: Identifying the landing page of each session
step-3: Counting pageviews for each session, to identify "bounces"
step-4: Summarizing by counting total sessions and bounced session
*/

create temporary table first_pageviews
select
	website_session_id,
    min(website_pageview_id) as min_pageview_id
from website_pageviews
where created_at < '2012-06-14'
group by website_session_id;

# Now finding all the landing pages that redirect to homepage only
create temporary table session_w_home_page
SELECT 
    first_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM
    first_pageviews
        LEFT JOIN
    website_pageviews ON website_pageviews.website_pageview_id = first_pageviews.min_pageview_id
WHERE
    website_pageviews.pageview_url = '/home';
    
# Filtering the bounce session
create temporary table bounced_session
SELECT 
    session_w_home_page.website_session_id,
    session_w_home_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_viewed_page
FROM
    session_w_home_page
        LEFT JOIN
    website_pageviews ON website_pageviews.website_session_id = session_w_home_page.website_session_id
GROUP BY session_w_home_page.website_session_id , session_w_home_page.landing_page
HAVING COUNT(website_pageviews.website_pageview_id) = 1;

-- finding the brounce rates
SELECT 
    COUNT(DISTINCT session_w_home_page.website_session_id) AS total_session,
    COUNT(DISTINCT bounced_session.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bounced_session.website_session_id) / COUNT(DISTINCT session_w_home_page.website_session_id) AS bounce_rate
FROM
    session_w_home_page
        LEFT JOIN
    bounced_session ON session_w_home_page.website_session_id = bounced_session.website_session_id;





/*
Testing newly launched webpage and doing a split test
step-1: find out when the new page/lander launched
step-2: finding the first website_pageview_id for relevant sessions
step3: identifying the landing page of each session
step-4: counting the pageviews for each session, to indentify bounces
step-5: summarizing total sessions and bounced sessions by landing page

*/

# finding when the lander-1 page launched and first session
SELECT 
    MIN(created_at) AS first_created_at,
    MIN(website_pageview_id) AS first_pageview_id
FROM
    website_pageviews
WHERE
    pageview_url = '/lander-1'
        AND created_at IS NOT NULL;
        
-- lander-1 created at '2012-06-19'
-- first_pageview_id 23504

# step-2: finding the first website_pageview_id for relevant sessions
create temporary table first_test_pageviews
SELECT 
    website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM
    website_pageviews
        INNER JOIN
    website_sessions ON website_sessions.website_session_id = website_pageviews.website_session_id
        AND website_sessions.created_at < '2012-07-28'
        AND website_pageviews.website_pageview_id > 23504
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY website_pageviews.website_session_id;

-- step-3: Now, identifying the landing page for each session
create temporary table nonbrand_test_session_w_landing_page
SELECT 
    first_test_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM
    first_test_pageviews
        LEFT JOIN
    website_pageviews ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
WHERE
    website_pageviews.pageview_url IN ('/home' , '/lander-1');
    
-- step-4: counting each session by landing pages
create temporary table nonbrand_test_bounced_session
SELECT 
    nonbrand_test_session_w_landing_page.website_session_id,
    nonbrand_test_session_w_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pageviewd
FROM
    nonbrand_test_session_w_landing_page
        LEFT JOIN
    website_pageviews ON website_pageviews.website_session_id = nonbrand_test_session_w_landing_page.website_session_id
GROUP BY nonbrand_test_session_w_landing_page.website_session_id , nonbrand_test_session_w_landing_page.landing_page
HAVING COUNT(website_pageviews.website_pageview_id) = 1;


-- step-5: summarizing the result
SELECT 
    nonbrand_test_session_w_landing_page.landing_page,
    COUNT(DISTINCT (nonbrand_test_session_w_landing_page.website_session_id)) AS sessions,
    COUNT(DISTINCT (nonbrand_test_bounced_session.website_session_id)) AS bounced_session,
    (COUNT(DISTINCT (nonbrand_test_bounced_session.website_session_id))/COUNT(DISTINCT (nonbrand_test_session_w_landing_page.website_session_id))) as bounced_rate
FROM
    nonbrand_test_session_w_landing_page
        LEFT JOIN
    nonbrand_test_bounced_session ON nonbrand_test_bounced_session.website_session_id = nonbrand_test_session_w_landing_page.website_session_id
GROUP BY nonbrand_test_session_w_landing_page.landing_page;




# Finding the website pageview trend
/*
step-1: finding the first website_pageview_id for relevant sessions
step-2: indentifying the landing page of each session
step-3: counting pageviews for each session, to identify 'bounces'
step-4: summarizing by week (bounce rate, sessions to each lander)
*/

# step-1 & 2
create temporary table session_w_min_pageview_id_and_view_count
SELECT 
    website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pageview_id,
    COUNT(website_pageviews.website_pageview_id) AS count_pageview
FROM
    website_sessions
        LEFT JOIN
    website_pageviews ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE
    website_sessions.created_at > '2012-06-01'
        AND website_sessions.created_at < '2012-08-31'
        AND website_sessions.utm_source = 'gsearch'
        AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY website_sessions.website_session_id;

-- step-3:
create temporary table session_w_counts_landing_and_created_at
SELECT 
    session_w_min_pageview_id_and_view_count.website_session_id,
    session_w_min_pageview_id_and_view_count.first_pageview_id,
    session_w_min_pageview_id_and_view_count.count_pageview,
    website_pageviews.pageview_url AS landing_page,
    website_pageviews.created_at AS session_created_at
FROM
    session_w_min_pageview_id_and_view_count
        LEFT JOIN
    website_pageviews ON session_w_min_pageview_id_and_view_count.first_pageview_id = website_pageviews.website_pageview_id;
    
-- step-4
SELECT 
    MIN(DATE(session_created_at)) AS week_start_date,
    COUNT(DISTINCT CASE
            WHEN count_pageview = 1 THEN website_session_id
            ELSE NULL
        END) * 1.0 / COUNT(DISTINCT website_session_id) as bounce_rate,
    COUNT(DISTINCT CASE
            WHEN landing_page = '/home' THEN website_session_id
            ELSE NULL
        END) AS home_sessions,
    COUNT(DISTINCT CASE
            WHEN landing_page = '/lander-1' THEN website_session_id
            ELSE NULL
        END) AS lander_sessions
FROM
    session_w_counts_landing_and_created_at
GROUP BY YEARWEEK(session_created_at)