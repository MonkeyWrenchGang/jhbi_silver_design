-- ============================================================
-- JHBI Cross-Rail Dollar Flow Analysis
-- Target: GCP BigQuery  |  Table: lake.unified_transactions
-- ============================================================


-- ── 1. Monthly inflow / outflow / net by payment rail ─────────
--    Feed this into the Sankey diagram (cross_rail_sankey.html)
--    Replace project.dataset with your actual BQ project/dataset
-- ──────────────────────────────────────────────────────────────
SELECT
  payment_type,
  FORMAT_DATE('%Y-%m', DATE(transaction_ts))       AS month,

  -- Inflow (credits into the institution)
  COUNTIF(direction = 'CREDIT')                    AS inflow_count,
  SUM(CASE WHEN direction = 'CREDIT'
       THEN settlement_amount ELSE 0 END)          AS inflow_usd,

  -- Outflow (debits leaving the institution)
  COUNTIF(direction = 'DEBIT')                     AS outflow_count,
  SUM(CASE WHEN direction = 'DEBIT'
       THEN settlement_amount ELSE 0 END)          AS outflow_usd,

  -- Net position
  SUM(CASE WHEN direction = 'CREDIT'
       THEN  settlement_amount
       ELSE -settlement_amount END)                AS net_usd

FROM `your_project.lake.unified_transactions`
WHERE
  status     = 'SETTLED'
  AND DATE(transaction_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
GROUP BY 1, 2
ORDER BY 2 DESC, inflow_usd DESC;


-- ── 2. Sankey-ready output ─────────────────────────────────────
--    Produces one row per (period, rail, direction).
--    Paste the results directly into QUERY_DATA in the HTML file.
-- ──────────────────────────────────────────────────────────────
SELECT
  CONCAT(
    'Q', CAST(EXTRACT(QUARTER FROM DATE(transaction_ts)) AS STRING),
    ' ',
    CAST(EXTRACT(YEAR   FROM DATE(transaction_ts)) AS STRING)
  )                                                AS period,
  payment_type,
  direction,
  ROUND(SUM(settlement_amount), 2)                 AS total

FROM `your_project.lake.unified_transactions`
WHERE
  status    = 'SETTLED'
  AND direction IN ('CREDIT', 'DEBIT')
  AND DATE(transaction_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 4 QUARTER)
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 3, total DESC;


-- ── 3. Cross-rail pivot (one column per rail) ──────────────────
--    Good for a quick net position snapshot in a BI tool.
-- ──────────────────────────────────────────────────────────────
SELECT
  month,
  SUM(CASE WHEN payment_type = 'ACH'     THEN net_usd END) AS ach_net,
  SUM(CASE WHEN payment_type = 'WIRE'    THEN net_usd END) AS wire_net,
  SUM(CASE WHEN payment_type = 'RTP'     THEN net_usd END) AS rtp_net,
  SUM(CASE WHEN payment_type = 'FEDNOW'  THEN net_usd END) AS fednow_net,
  SUM(CASE WHEN payment_type = 'ZELLE'   THEN net_usd END) AS zelle_net,
  SUM(CASE WHEN payment_type = 'CARD'    THEN net_usd END) AS card_net,
  SUM(CASE WHEN payment_type = 'CHECK'   THEN net_usd END) AS check_net,
  SUM(CASE WHEN payment_type = 'BILLPAY' THEN net_usd END) AS billpay_net,
  SUM(net_usd)                                              AS total_net
FROM (
  SELECT
    FORMAT_DATE('%Y-%m', DATE(transaction_ts)) AS month,
    payment_type,
    SUM(CASE WHEN direction = 'CREDIT'
         THEN  settlement_amount
         ELSE -settlement_amount END)          AS net_usd
  FROM `your_project.lake.unified_transactions`
  WHERE status = 'SETTLED'
    AND DATE(transaction_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
  GROUP BY 1, 2
)
GROUP BY 1
ORDER BY 1 DESC;


-- ── 4. FX flows only — cross-rail in original currency ─────────
--    Useful when you need multi-currency Sankey breakdowns.
-- ──────────────────────────────────────────────────────────────
SELECT
  payment_type,
  original_currency_code,
  direction,
  COUNT(*)                           AS txn_count,
  SUM(original_amount)               AS original_amount,
  ROUND(AVG(fx_rate), 6)             AS avg_fx_rate,
  SUM(settlement_amount)             AS settled_usd

FROM `your_project.lake.unified_transactions`
WHERE
  status = 'SETTLED'
  AND original_currency_code != 'USD'
  AND DATE(transaction_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)
GROUP BY 1, 2, 3
ORDER BY settled_usd DESC;
