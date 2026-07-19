-- ============================================================================
-- COMPREHENSIVE FIX FOR STATUS HISTORY SETUP
-- ============================================================================

-- 0. DROP OLD TRIGGER AND FUNCTION THAT NO LONGER APPLY (THEY TRY TO UPDATE DELETED COLUMNS)
DROP TRIGGER IF EXISTS trigger_sync_personnel_status ON status_history;
DROP FUNCTION IF EXISTS sync_personnel_status_category();

-- 1. FIRST, DROP AND RECREATE THE UPDATE FUNCTION WITH SECURITY DEFINER TO AVOID RLS ISSUES
DROP FUNCTION IF EXISTS update_personnel_status(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION update_personnel_status(
    p_army_no VARCHAR,
    p_category VARCHAR,
    p_subcategory VARCHAR DEFAULT NULL,
    p_sub_subcategory VARCHAR DEFAULT NULL,
    p_destination VARCHAR DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_created_by VARCHAR DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Close current active status if it exists
    UPDATE status_history
    SET end_date = COALESCE(p_start_date, NOW()),
        updated_by = p_created_by,
        updated_at = NOW()
    WHERE army_no = p_army_no AND end_date IS NULL;
    
    -- Insert new active status
    INSERT INTO status_history (
        army_no, category, subcategory, sub_subcategory, 
        start_date, end_date, destination, remarks, created_by
    ) VALUES (
        p_army_no, p_category, p_subcategory, p_sub_subcategory,
        COALESCE(p_start_date, NOW()), p_end_date, p_destination, p_remarks, p_created_by
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. DROP AND RECREATE THE VIEW TO AVOID COLUMN NAME ISSUES
DROP VIEW IF EXISTS v_current_personnel_status;

CREATE OR REPLACE VIEW v_current_personnel_status AS
SELECT 
    p.army_no,
    p.profile_photo,
    p.fighting_status,
    p.rank,
    p.name,
    p.trade,
    p.category AS rank_group,
    p.cl,
    p.battery,
    p.phone_number,
    p.city,
    p.remarks,
    -- From status history (only the active one)
    sh.category AS current_category,
    sh.subcategory AS current_subcategory,
    sh.start_date,
    sh.end_date,
    sh.destination,
    sh.remarks AS status_remarks
FROM personnel p
LEFT JOIN status_history sh ON p.army_no = sh.army_no AND sh.end_date IS NULL
WHERE p.is_active = true;

-- 3. SEED INITIAL STATUS HISTORY FOR ALL PERSONNEL WHO DON'T HAVE ANY
INSERT INTO status_history (
    army_no, category, subcategory, start_date, end_date, destination, created_by
)
SELECT 
    army_no, 
    'Present' AS category, 
    'Duty' AS subcategory,
    NOW() - INTERVAL '30 days' AS start_date,
    NULL AS end_date,
    NULL AS destination,
    'system' AS created_by
FROM personnel p
WHERE NOT EXISTS (
    SELECT 1 FROM status_history sh WHERE sh.army_no = p.army_no
);

-- 4. ENSURE RLS POLICIES ARE CORRECT FOR STATUS HISTORY
-- Drop existing policies if needed
DROP POLICY IF EXISTS "Allow read access to status timelines" ON status_history;
DROP POLICY IF EXISTS "Allow status logs updates" ON status_history;

CREATE POLICY "Allow read access to status timelines" 
ON status_history FOR SELECT 
USING (true);

CREATE POLICY "Allow all actions on status history" 
ON status_history
FOR ALL
USING (true)
WITH CHECK (true);

-- 5. VERIFY EVERYTHING IS WORKING
-- Check that we have status history records
SELECT COUNT(*) AS status_history_count FROM status_history;

-- ============================================================================
-- DONE!
-- ============================================================================
