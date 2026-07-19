
-- Test script to verify update_personnel_status works correctly
-- Step 1: Pick a test army number from your personnel table
-- Replace 'PA-43337' with an army number that actually exists in your database!
WITH test_army AS (
    SELECT 'PA-43337' AS army_no
)

-- Step 2: Run the update_personnel_status function
SELECT update_personnel_status(
    p_army_no := (SELECT army_no FROM test_army),
    p_category := 'Leave',
    p_subcategory := 'Annual',
    p_destination := 'Lahore',
    p_start_date := NOW() - INTERVAL '2 days',
    p_end_date := NOW() + INTERVAL '7 days',
    p_remarks := 'Test update'
);

-- Step 3: Check if the personnel table was updated
SELECT 
    army_no, 
    status_category, 
    status_subcategory, 
    status_start_date, 
    status_end_date
FROM personnel 
WHERE army_no = (SELECT army_no FROM test_army);

-- Step 4: Check if status_history was updated
SELECT 
    id,
    army_no,
    category,
    subcategory,
    start_date,
    end_date,
    destination
FROM status_history 
WHERE army_no = (SELECT army_no FROM test_army)
ORDER BY start_date DESC
LIMIT 5;
