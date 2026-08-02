-- ============================================================
-- Nayo - Quick Fix SQL Script
-- ============================================================
-- This script contains common database fixes for the Nayo
-- loyalty platform. Run against the PostgreSQL database.
--
-- Usage:
--   psql -U nayo -d nayo -f QUICK_FIX.sql
--
-- Or via Docker:
--   docker-compose exec -T db psql -U nayo -d nayo < QUICK_FIX.sql
--
-- Or via Make:
--   make db-shell < QUICK_FIX.sql
-- ============================================================

-- ============================================================
-- 1. FIX: Reset Admin Password
-- ============================================================
-- Use this if you're locked out of the admin panel.
-- Replace 'your-new-password-hash' with a bcrypt hash.
-- Generate with: php -r "echo password_hash('newpassword', PASSWORD_BCRYPT);"

-- UPDATE nayo_admin SET password = 'your-new-password-hash'
-- WHERE username = 'admin';


-- ============================================================
-- 2. FIX: Re-index Elasticsearch Projections
-- ============================================================
-- Run this if member search or segment calculations are wrong.
-- After running this SQL, also run from PHP container:
--   php bin/console oloy:user:projections:index:create --drop-old

-- This SQL just flags projections for reprocessing
-- UPDATE member SET updated_at = NOW() WHERE updated_at IS NOT NULL;


-- ============================================================
-- 3. FIX: Clear Stuck Point Transfers
-- ============================================================
-- Find and cancel point transfers that have been pending
-- for more than 7 days without resolution.

-- SELECT id, member_id, value, state, created_at
-- FROM points_transfer
-- WHERE state = 'pending'
--   AND created_at < NOW() - INTERVAL '7 days';

-- To actually cancel them (uncomment to execute):
-- UPDATE points_transfer
-- SET state = 'canceled', updated_at = NOW()
-- WHERE state = 'pending'
--   AND created_at < NOW() - INTERVAL '7 days';


-- ============================================================
-- 4. FIX: Repair Member Segment Assignments
-- ============================================================
-- Run this if segments show incorrect member counts.
-- After running, trigger segment recalculation from admin panel
-- or via API.

-- DELETE FROM segment_member;

-- Then re-run segment calculation:
-- php bin/console oloy:segment:recompute


-- ============================================================
-- 5. FIX: Restore Default Earning Rules
-- ============================================================
-- Insert default earning rule if accidentally deleted.

-- INSERT INTO earning_rule (id, name, description, type, active, event_data, created_at, updated_at)
-- VALUES (
--     gen_random_uuid(),
--     'Default Earn Rate',
--     '1 point per 100 currency units spent',
--     'transaction_value',
--     true,
--     '{"reward": {"type": "points", "formula": "Math.floor(transaction.summary.grossValue / 100)"}, "conditions": [{"type": "transaction.value", "operator": ">=", "value": 100}]}',
--     NOW(),
--     NOW()
-- );


-- ============================================================
-- 6. FIX: Clean Up Expired Sessions
-- ============================================================
-- Remove expired JWT refresh tokens and sessions.

-- DELETE FROM refresh_token WHERE expires_at < NOW();


-- ============================================================
-- 7. FIX: Recalculate Member Point Balances
-- ============================================================
-- Run this if point balances appear incorrect.
-- This creates a materialized view for verification.

-- CREATE OR REPLACE VIEW member_points_summary AS
-- SELECT
--     member_id,
--     COALESCE(SUM(CASE WHEN state = 'active' AND type = 'add' THEN value ELSE 0 END), 0) as total_earned,
--     COALESCE(SUM(CASE WHEN state = 'active' AND type = 'spend' THEN value ELSE 0 END), 0) as total_spent,
--     COALESCE(SUM(CASE WHEN state = 'active' AND type = 'add' THEN value ELSE 0 END), 0)
--     - COALESCE(SUM(CASE WHEN state = 'active' AND type = 'spend' THEN value ELSE 0 END), 0) as current_balance
-- FROM points_transfer
-- WHERE state IN ('active', 'pending')
-- GROUP BY member_id;

-- View discrepancies:
-- SELECT m.*, s.current_balance as calculated_balance
-- FROM member m
-- LEFT JOIN member_points_summary s ON m.id = s.member_id
-- WHERE m.points != COALESCE(s.current_balance, 0);


-- ============================================================
-- 8. FIX: Update Database Timezone
-- ============================================================
-- Ensure database uses correct timezone for East Africa.

ALTER DATABASE nayo SET timezone TO 'Africa/Nairobi';
SET timezone TO 'Africa/Nairobi';


-- ============================================================
-- 9. FIX: Vacuum and Analyze Tables
-- ============================================================
-- Run periodically for performance optimization.

VACUUM ANALYZE points_transfer;
VACUUM ANALYZE member;
VACUUM ANALYZE transaction;
VACUUM ANALYZE campaign;
VACUUM ANALYZE segment;


-- ============================================================
-- 10. FIX: Check Database Health
-- ============================================================
-- Run these diagnostic queries to check database health.

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) as data_size,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename) - pg_relation_size(schemaname || '.' || tablename)) as index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 20;

-- Active connections
SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';

-- Long running queries (> 5 minutes)
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
  AND state != 'idle';

-- Index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC
LIMIT 20;


-- ============================================================
-- 11. FIX: Reset Failed Campaign Deliveries
-- ============================================================
-- Re-queue campaign coupons that failed to deliver.

-- UPDATE campaign_coupon
-- SET status = 'pending', updated_at = NOW()
-- WHERE status = 'failed'
--   AND campaign_id IN (
--     SELECT id FROM campaign WHERE active = true
--   );


-- ============================================================
-- 12. FIX: Add Missing Indexes
-- ============================================================
-- Add indexes for commonly slow queries.

CREATE INDEX IF NOT EXISTS idx_points_transfer_member_state
    ON points_transfer (member_id, state);

CREATE INDEX IF NOT EXISTS idx_points_transfer_created
    ON points_transfer (created_at);

CREATE INDEX IF NOT EXISTS idx_transaction_document_number
    ON transaction (document_number);

CREATE INDEX IF NOT EXISTS idx_transaction_customer_loyalty
    ON transaction (customer_loyalty_card_number);

CREATE INDEX IF NOT EXISTS idx_member_email
    ON member (email);

CREATE INDEX IF NOT EXISTS idx_member_loyalty_card
    ON member (loyalty_card_number);

CREATE INDEX IF NOT EXISTS idx_member_created_at
    ON member (created_at);

CREATE INDEX IF NOT EXISTS idx_segment_member_segment
    ON segment_member (segment_id);

CREATE INDEX IF NOT EXISTS idx_campaign_activity_dates
    ON campaign (activity_from, activity_to);


-- ============================================================
-- 13. FIX: Create Default Roles
-- ============================================================
-- Ensure default admin roles exist.

-- INSERT INTO role (id, name, description, permissions, created_at)
-- SELECT gen_random_uuid(), 'Super Admin', 'Full system access',
--     '["*"]', NOW()
-- WHERE NOT EXISTS (SELECT 1 FROM role WHERE name = 'Super Admin');

-- INSERT INTO role (id, name, description, permissions, created_at)
-- SELECT gen_random_uuid(), 'Campaign Manager', 'Manage campaigns and segments',
--     '["campaign.*", "segment.*", "member.read", "analytics.read"]', NOW()
-- WHERE NOT EXISTS (SELECT 1 FROM role WHERE name = 'Campaign Manager');

-- INSERT INTO role (id, name, description, permissions, created_at)
-- SELECT gen_random_uuid(), 'POS Operator', 'Point of sale operations',
--     '["transaction.create", "transaction.read", "member.read", "reward.read"]', NOW()
-- WHERE NOT EXISTS (SELECT 1 FROM role WHERE name = 'POS Operator');


-- ============================================================
-- DONE
-- ============================================================
-- Review the output above for any errors.
-- For fixes that are commented out, uncomment and run as needed.
-- ============================================================
