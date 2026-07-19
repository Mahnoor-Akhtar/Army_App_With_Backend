-- ============================================
-- REMOVE REDUNDANT STATUS FIELDS FROM PERSONNEL TABLE
-- ============================================

-- Step 1: Update the update_personnel_status function to remove personnel table updates
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
    -- Close current active status
    UPDATE status_history
    SET end_date = NOW(),
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
$$ LANGUAGE plpgsql;

-- Step 2: Update the v_current_personnel_status view to remove redundant fields
DROP VIEW IF EXISTS v_current_personnel_status;
CREATE VIEW v_current_personnel_status AS
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

-- Step 3: Remove redundant status columns from personnel table
ALTER TABLE personnel 
    DROP COLUMN IF EXISTS status_category,
    DROP COLUMN IF EXISTS status_subcategory,
    DROP COLUMN IF EXISTS status_start_date,
    DROP COLUMN IF EXISTS status_end_date;

-- ============================================
-- ALL CHANGES APPLIED!
-- ============================================
