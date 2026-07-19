-- ============================================================================
-- Supabase PostgreSQL Schema, Relations, Queries, and Seed Data for Parade App
-- ============================================================================
--
-- ER DIAGRAM (Mermaid format):
-- 
-- ```mermaid
-- erDiagram
--     PERSONNEL {
--         varchar army_no PK
--         varchar rank
--         varchar name
--         varchar category
--         varchar cl
--         text remarks
--         timestamptz created_at
--         timestamptz updated_at
--     }
--     
--     STATUS_CATEGORIES {
--         uuid id PK
--         varchar name
--         uuid parent_id FK
--         integer level
--     }
-- 
--     STATUS_HISTORY {
--         uuid id PK
--         varchar army_no FK
--         varchar category
--         varchar subcategory
--         varchar sub_subcategory
--         timestamptz start_date
--         timestamptz end_date
--         varchar destination
--         timestamptz created_at
--     }
-- 
--     CUSTOM_GROUPS {
--         uuid id PK
--         varchar name
--         varchar category
--         varchar leader_army_no FK
--         varchar leader_name
--         varchar location
--         timestamptz until_date
--         timestamptz created_at
--     }
-- 
--     GROUP_MEMBERS {
--         uuid group_id PK_FK
--         varchar army_no PK_FK
--     }
-- 
--     COMMAND_SLOTS {
--         integer slot_id PK
--         varchar role
--         varchar army_no FK
--         varchar username
--         varchar password
--     }
-- 
--     SYSTEM_ATTRIBUTES {
--         varchar attribute_type PK
--         jsonb items
--     }
-- 
--     PERSONNEL ||--o{ STATUS_HISTORY : "tracks status changes"
--     PERSONNEL ||--o{ COMMAND_SLOTS : "occupies slot"
--     PERSONNEL ||--o{ CUSTOM_GROUPS : "leads group"
--     PERSONNEL ||--o{ GROUP_MEMBERS : "belongs to"
--     CUSTOM_GROUPS ||--o{ GROUP_MEMBERS : "contains"
--     STATUS_CATEGORIES ||--o{ STATUS_CATEGORIES : "sub-hierarchy parent_id"
-- ```
--

-- ============================================================================
-- SECTION 1: DATABASE CLEANUP (For development/re-run execution)
-- ============================================================================

DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS custom_groups CASCADE;
DROP TABLE IF EXISTS command_slots CASCADE;
DROP TABLE IF EXISTS status_history CASCADE;
DROP TABLE IF EXISTS status_categories CASCADE;
DROP TABLE IF EXISTS system_attributes CASCADE;
DROP TABLE IF EXISTS personnel CASCADE;

DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- ============================================================================
-- SECTION 2: DDL (TABLES, CONSTRAINTS, INDEXES)
-- ============================================================================

-- Helper function to automatically update 'updated_at' columns on row updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. PERSONNEL TABLE (Nominal Roll)
CREATE TABLE personnel (
    army_no VARCHAR(50) PRIMARY KEY,
    rank VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL, -- e.g., 'Officers', 'JCOs', 'Clks'
    cl VARCHAR(50) NOT NULL,       -- Class/Group, e.g., 'Pb', 'Sdh', 'Ptn'
    status_category VARCHAR(100) DEFAULT 'Present', -- Denormalized current status category
    status_subcategory VARCHAR(100), -- Denormalized subcategory
    status_start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- Denormalized start date
    status_end_date TIMESTAMP WITH TIME ZONE, -- Denormalized end date
    remarks TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_personnel_updated_at
BEFORE UPDATE ON personnel
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- 2. STATUS CATEGORIES TABLE (Hierarchical Category Tree)
CREATE TABLE status_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    parent_id UUID REFERENCES status_categories(id) ON DELETE CASCADE,
    level INTEGER NOT NULL CHECK (level IN (1, 2, 3)), -- 1 = Category, 2 = Subcategory, 3 = Sub-subcategory
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_name_per_parent UNIQUE (name, parent_id)
);

CREATE INDEX idx_status_categories_parent_id ON status_categories(parent_id);


-- 3. STATUS HISTORY TABLE (Current and past duties/statuses)
CREATE TABLE status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    army_no VARCHAR(50) NOT NULL REFERENCES personnel(army_no) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    sub_subcategory VARCHAR(100),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE, -- NULL signifies this is the active status
    destination VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_end_date_after_start CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TRIGGER trigger_update_status_history_updated_at
BEFORE UPDATE ON status_history
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Function to update personnel.status_category and dates
CREATE OR REPLACE FUNCTION sync_personnel_status_category()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.end_date IS NULL THEN
        UPDATE personnel 
        SET status_category = NEW.category,
            status_subcategory = NEW.subcategory,
            status_start_date = NEW.start_date,
            status_end_date = NEW.end_date
        WHERE army_no = NEW.army_no;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_personnel_status
AFTER INSERT OR UPDATE ON status_history
FOR EACH ROW
EXECUTE FUNCTION sync_personnel_status_category();

CREATE INDEX idx_status_history_army_no ON status_history(army_no);
CREATE INDEX idx_status_history_active ON status_history(army_no) WHERE (end_date IS NULL);

-- CRITICAL: Enforce that at most ONE active status exists per person at any time.
CREATE UNIQUE INDEX unique_active_status_per_person 
ON status_history (army_no) 
WHERE (end_date IS NULL);


-- 4. CUSTOM GROUPS TABLE
CREATE TABLE custom_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,
    leader_army_no VARCHAR(50) REFERENCES personnel(army_no) ON DELETE SET NULL,
    leader_name VARCHAR(150) NOT NULL,
    location VARCHAR(255) NOT NULL,
    until_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_custom_groups_updated_at
BEFORE UPDATE ON custom_groups
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_custom_groups_leader ON custom_groups(leader_army_no);


-- 5. GROUP MEMBERS JUNCTION TABLE (Many-to-Many)
CREATE TABLE group_members (
    group_id UUID NOT NULL REFERENCES custom_groups(id) ON DELETE CASCADE,
    army_no VARCHAR(50) NOT NULL REFERENCES personnel(army_no) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (group_id, army_no)
);

CREATE INDEX idx_group_members_army_no ON group_members(army_no);


-- 6. COMMAND SLOTS TABLE (Backwards-compatible login slots)
CREATE TABLE command_slots (
    slot_id INT PRIMARY KEY,
    role VARCHAR(50) NOT NULL CHECK (role IN ('superadmin', 'admin', 'user')),
    army_no VARCHAR(50) REFERENCES personnel(army_no) ON DELETE SET NULL,
    username VARCHAR(100) UNIQUE,
    password VARCHAR(255),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_command_slots_updated_at
BEFORE UPDATE ON command_slots
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_command_slots_username ON command_slots(username);


-- 7. SYSTEM ATTRIBUTES TABLE (Ranks, Trades, Batteries configuration)
CREATE TABLE system_attributes (
    attribute_type VARCHAR(50) PRIMARY KEY CHECK (attribute_type IN ('ranks', 'trades', 'batteries')),
    items JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_system_attributes_updated_at
BEFORE UPDATE ON system_attributes
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================================
-- SECTION 3: SUPABASE ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE personnel ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE command_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_attributes ENABLE ROW LEVEL SECURITY;

-- Personnel Policies
CREATE POLICY "Allow public read access to nominal roll" ON personnel FOR SELECT USING (true);
CREATE POLICY "Allow all actions for authenticated operators" ON personnel FOR ALL USING (true) WITH CHECK (true);

-- Status Categories Policies
CREATE POLICY "Allow read access to category structure" ON status_categories FOR SELECT USING (true);
CREATE POLICY "Allow writes for category configuration" ON status_categories FOR ALL USING (true) WITH CHECK (true);

-- Status History Policies
CREATE POLICY "Allow read access to status timelines" ON status_history FOR SELECT USING (true);
CREATE POLICY "Allow status logs updates" ON status_history FOR ALL USING (true) WITH CHECK (true);

-- Custom Groups Policies
CREATE POLICY "Allow read access to custom groups" ON custom_groups FOR SELECT USING (true);
CREATE POLICY "Allow management of custom groups" ON custom_groups FOR ALL USING (true) WITH CHECK (true);

-- Group Members Policies
CREATE POLICY "Allow read access to group assignments" ON group_members FOR SELECT USING (true);
CREATE POLICY "Allow modifying group rosters" ON group_members FOR ALL USING (true) WITH CHECK (true);

-- Command Slots Policies
CREATE POLICY "Allow slot view for authentication" ON command_slots FOR SELECT USING (true);
CREATE POLICY "Allow admin slot allocations" ON command_slots FOR ALL USING (true) WITH CHECK (true);

-- System Attributes Policies
CREATE POLICY "Allow read access to configurations" ON system_attributes FOR SELECT USING (true);
CREATE POLICY "Allow modification of system configurations" ON system_attributes FOR ALL USING (true) WITH CHECK (true);


-- ============================================================================
-- SECTION 4: APPLICATION QUERIES (DML REFERENCE)
-- ============================================================================

/*
  Core database operations rewritten from SharedPreferences
  (PersonnelDataManager & MockDataManager) to relational SQL queries.
*/

-- ─────────────────────────────────────────────────────────────────────────────
-- Q1: GET ALL NOMINAL ROLL (PERSONNEL LIST)
-- Replaces: nominalRollList array retrieval
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT army_no, rank, name, category, cl, remarks
-- FROM personnel
-- ORDER BY
--   CASE category
--     WHEN 'Officers' THEN 1
--     WHEN 'JCOs'     THEN 2
--     WHEN 'Clks'     THEN 3
--     WHEN 'Svys'     THEN 4
--     WHEN 'TAs'      THEN 5
--     WHEN 'OCsU'     THEN 6
--     ELSE 7
--   END,
--   name ASC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q2: GET ACTIVE STATUS OF ALL PERSONNEL (PARADE STATE)
-- Replaces: PersonnelDataManager.getStatus() across full roll
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT 
--     p.army_no, 
--     p.rank, 
--     p.name, 
--     p.category AS rank_group,
--     p.cl,
--     sh.category AS current_category,
--     sh.subcategory AS current_subcategory,
--     sh.start_date,
--     sh.destination
-- FROM personnel p
-- LEFT JOIN status_history sh ON p.army_no = sh.army_no AND sh.end_date IS NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q3: GET SINGLE PERSON'S ACTIVE STATUS
-- Replaces: PersonnelDataManager.getStatus(armyNo)
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT category, subcategory, sub_subcategory, start_date, end_date, destination
-- FROM status_history
-- WHERE army_no = :army_no AND end_date IS NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q4: UPDATE PERSONNEL STATUS (TRANSACTION)
-- Replaces: PersonnelDataManager.updateStatus()
-- Steps: Close active status → Insert new active status
-- ─────────────────────────────────────────────────────────────────────────────
-- BEGIN;
--   UPDATE status_history
--   SET end_date = :start_date
--   WHERE army_no = :army_no AND end_date IS NULL;
--   
--   INSERT INTO status_history (army_no, category, subcategory, sub_subcategory, start_date, end_date, destination)
--   VALUES (:army_no, :category, :subcategory, :sub_subcategory, :start_date, :end_date, :destination);
-- COMMIT;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q5: GET TIMELINE HISTORY FOR AN INDIVIDUAL
-- Replaces: PersonnelDataManager.getHistory(armyNo)
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT category, subcategory, sub_subcategory, start_date, end_date, destination
-- FROM status_history
-- WHERE army_no = :army_no
-- ORDER BY start_date DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q6: AGGREGATED PARADE COUNTS (DASHBOARD STATS)
-- Replaces: PersonnelDataManager.getCountForCategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT sh.category, COUNT(*) AS strength
-- FROM status_history sh
-- WHERE sh.end_date IS NULL
-- GROUP BY sh.category
-- ORDER BY strength DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q7: PARADE COUNTS BY SUBCATEGORY
-- Replaces: PersonnelDataManager.getCountForSubcategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT sh.category, sh.subcategory, COUNT(*) AS strength
-- FROM status_history sh
-- WHERE sh.end_date IS NULL AND sh.category = :category
-- GROUP BY sh.category, sh.subcategory
-- ORDER BY strength DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q8: GET PEOPLE IN A SPECIFIC STATUS NODE
-- Replaces: PersonnelDataManager.getPeopleInNode()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT p.army_no, p.rank, p.name, p.category AS rank_group, p.cl, p.remarks
-- FROM personnel p
-- JOIN status_history sh ON p.army_no = sh.army_no
-- WHERE sh.end_date IS NULL
--   AND sh.category = :category
--   AND (:subcategory IS NULL OR sh.subcategory = :subcategory)
--   AND (:sub_subcategory IS NULL OR sh.sub_subcategory = :sub_subcategory);


-- ─────────────────────────────────────────────────────────────────────────────
-- Q9: FETCH CATEGORY HIERARCHY TREE (RECURSIVE CTE)
-- Replaces: PersonnelDataManager.categoryHierarchy JSON decoding
-- ─────────────────────────────────────────────────────────────────────────────
-- WITH RECURSIVE cat_tree AS (
--     SELECT id, name, parent_id, level, ARRAY[name::text] AS path
--     FROM status_categories
--     WHERE parent_id IS NULL
--     UNION ALL
--     SELECT child.id, child.name, child.parent_id, child.level, parent.path || child.name::text
--     FROM status_categories child
--     JOIN cat_tree parent ON child.parent_id = parent.id
-- )
-- SELECT id, name, parent_id, level, path FROM cat_tree ORDER BY path;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q10: ADD NEW MAIN CATEGORY
-- Replaces: PersonnelDataManager.addMainCategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- INSERT INTO status_categories (name, parent_id, level)
-- VALUES (:name, NULL, 1)
-- ON CONFLICT (name, parent_id) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q11: ADD SUBCATEGORY
-- Replaces: PersonnelDataManager.addSubcategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- INSERT INTO status_categories (name, parent_id, level)
-- VALUES (:subcategory_name, (SELECT id FROM status_categories WHERE name = :parent_category AND parent_id IS NULL), 2)
-- ON CONFLICT (name, parent_id) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q12: ADD SUB-SUBCATEGORY
-- Replaces: PersonnelDataManager.addSubSubcategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- INSERT INTO status_categories (name, parent_id, level)
-- VALUES (:sub_sub_name,
--   (SELECT sc2.id FROM status_categories sc2
--    JOIN status_categories sc1 ON sc2.parent_id = sc1.id
--    WHERE sc1.name = :parent_category AND sc1.parent_id IS NULL AND sc2.name = :subcategory_name),
--   3)
-- ON CONFLICT (name, parent_id) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q13: RENAME CATEGORY/SUBCATEGORY
-- Replaces: PersonnelDataManager.renameCategory() / renameSubcategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE status_categories SET name = :new_name WHERE id = :category_id;
-- Also update denormalized names in status_history:
-- UPDATE status_history SET category = :new_name WHERE category = :old_name AND end_date IS NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q14: DELETE CATEGORY (CASCADE REMOVES CHILDREN)
-- Replaces: PersonnelDataManager.deleteCategory()
-- ─────────────────────────────────────────────────────────────────────────────
-- DELETE FROM status_categories WHERE id = :category_id;
-- Reset affected personnel to 'Present':
-- UPDATE status_history
-- SET category = 'Present', subcategory = NULL, sub_subcategory = NULL
-- WHERE category = :deleted_category_name AND end_date IS NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q15: GET CUSTOM GROUPS WITH ROSTER
-- Replaces: PersonnelDataManager.customGroups list
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT 
--     cg.id, cg.name, cg.category, cg.leader_army_no, cg.leader_name,
--     cg.location, cg.until_date,
--     COALESCE(
--       json_agg(json_build_object('armyNo', gm.army_no, 'name', p.name, 'rank', p.rank))
--       FILTER (WHERE gm.army_no IS NOT NULL), '[]'::json
--     ) AS members
-- FROM custom_groups cg
-- LEFT JOIN group_members gm ON cg.id = gm.group_id
-- LEFT JOIN personnel p ON gm.army_no = p.army_no
-- GROUP BY cg.id;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q16: CREATE A NEW CUSTOM GROUP
-- Replaces: PersonnelDataManager.addCustomGroup()
-- ─────────────────────────────────────────────────────────────────────────────
-- BEGIN;
--   INSERT INTO custom_groups (name, category, leader_army_no, leader_name, location, until_date)
--   VALUES (:name, :category, :leader_army_no, :leader_name, :location, :until_date)
--   RETURNING id;
--
--   -- Then insert members using the returned group id:
--   INSERT INTO group_members (group_id, army_no)
--   VALUES (:group_id, :member_army_no_1),
--          (:group_id, :member_army_no_2);
-- COMMIT;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q17: UPDATE A CUSTOM GROUP
-- Replaces: PersonnelDataManager.updateCustomGroup()
-- ─────────────────────────────────────────────────────────────────────────────
-- BEGIN;
--   UPDATE custom_groups
--   SET name = :name, category = :category, leader_army_no = :leader_army_no,
--       leader_name = :leader_name, location = :location, until_date = :until_date
--   WHERE id = :group_id;
--
--   -- Replace members (delete old, insert new)
--   DELETE FROM group_members WHERE group_id = :group_id;
--   INSERT INTO group_members (group_id, army_no)
--   VALUES (:group_id, :member1), (:group_id, :member2);
-- COMMIT;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q18: DELETE A CUSTOM GROUP
-- Replaces: PersonnelDataManager.deleteCustomGroup()
-- ─────────────────────────────────────────────────────────────────────────────
-- DELETE FROM custom_groups WHERE id = :group_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q19: AUTHENTICATE USER (LOGIN)
-- Replaces: LoginViewModel.login()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT slot_id, role, army_no, username
-- FROM command_slots
-- WHERE LOWER(username) = LOWER(:username) AND password = :password;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q20: GET ALL COMMAND SLOTS
-- Replaces: MockDataManager.getCommandGroup()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT slot_id, role, army_no, username, password
-- FROM command_slots
-- ORDER BY slot_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q21: ASSIGN A COMMAND SLOT
-- Replaces: MockDataManager.assignSlot()
-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE command_slots
-- SET army_no = :army_no, username = :username, password = :password
-- WHERE slot_id = :slot_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q22: CLEAR A COMMAND SLOT
-- Replaces: MockDataManager.clearSlot()
-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE command_slots
-- SET army_no = NULL, username = NULL, password = NULL
-- WHERE slot_id = :slot_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q23: CHANGE USER PASSWORD
-- Replaces: MockDataManager.changePassword()
-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE command_slots SET password = :new_password WHERE LOWER(username) = LOWER(:username);


-- ─────────────────────────────────────────────────────────────────────────────
-- Q24: ADD NEW PERSON TO NOMINAL ROLL
-- Replaces: PersonnelDataManager.addPerson()
-- ─────────────────────────────────────────────────────────────────────────────
-- INSERT INTO personnel (army_no, rank, name, category, cl, remarks)
-- VALUES (:army_no, :rank, :name, :category, :cl, :remarks)
-- ON CONFLICT (army_no) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q25: EDIT EXISTING PERSON
-- Replaces: PersonnelDataManager.editPerson()
-- ─────────────────────────────────────────────────────────────────────────────
-- UPDATE personnel
-- SET army_no = :new_army_no, rank = :rank, name = :name, category = :category, cl = :cl, remarks = :remarks
-- WHERE army_no = :old_army_no;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q26: REMOVE PERSON FROM ROLL
-- Replaces: PersonnelDataManager.removePerson()
-- ─────────────────────────────────────────────────────────────────────────────
-- DELETE FROM personnel WHERE army_no = :army_no;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q27: GET / UPDATE SYSTEM ATTRIBUTES (Trades, Ranks, Batteries)
-- Replaces: MockDataManager.getTrades(), getRanks(), getBatteries()
-- ─────────────────────────────────────────────────────────────────────────────
-- GET:
-- SELECT items FROM system_attributes WHERE attribute_type = 'trades';
-- SELECT items FROM system_attributes WHERE attribute_type = 'ranks';
-- SELECT items FROM system_attributes WHERE attribute_type = 'batteries';
--
-- UPDATE:
-- UPDATE system_attributes SET items = :items_jsonb WHERE attribute_type = 'trades';


-- ─────────────────────────────────────────────────────────────────────────────
-- Q28: LOCATION/DESTINATION SEARCH
-- Replaces: PersonStatus.matchesLocationQuery()
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT p.army_no, p.rank, p.name, sh.category, sh.subcategory, sh.destination
-- FROM personnel p
-- JOIN status_history sh ON p.army_no = sh.army_no AND sh.end_date IS NULL
-- WHERE LOWER(COALESCE(sh.destination, '') || ' ' || sh.category || ' ' || COALESCE(sh.subcategory, ''))
--   LIKE '%' || LOWER(:query) || '%';


-- ============================================================================
-- SECTION 5: SEED DATA
-- ============================================================================

-- 1. SEED NOMINAL ROLL
INSERT INTO personnel (army_no, rank, name, category, cl, remarks) VALUES
-- Officers (13)
('PA-43337', 'Lt Col', 'Muhammad Tayyab Ghaznavi', 'Officers', 'Pb', 'Commanding Officer'),
('PA-45571', 'Maj', 'Muhammad Usman Anwar', 'Officers', 'Pb', '2IC'),
('PA-55563', 'Maj', 'Muhammad Azfar Mahmood', 'Officers', 'Sdh', 'Battery Commander'),
('PA-52402', 'Maj', 'Muhammad Umair Asim', 'Officers', 'Pb', 'Battery Commander'),
('PA-56482', 'Maj', 'Muhammad Usman Raza Khan', 'Officers', 'Pb', 'Battery Commander'),
('PA-61131', 'Capt', 'Muhammad Nabeel Ghafoor', 'Officers', 'Pb', 'Adjutant'),
('PA-61755', 'Capt', 'Muhammad Ali', 'Officers', 'Pb', 'Quartermaster'),
('PA-65543', 'Capt', 'Taimoor Ahmed', 'Officers', 'Ptn', 'GPO'),
('PA-66748', 'Lt', 'Muhammad Diayan Akhtar', 'Officers', 'Pb', 'GPO'),
('PA-66674', 'Lt', 'Mohammad Haseeb Niaz', 'Officers', 'Pb', 'GPO'),
('PA-66234', 'Lt', 'Mudasar Ali', 'Officers', 'Pb', 'GPO'),
('PA-67711', 'Lt', 'Asad Ullah', 'Officers', 'Ptn', 'Section Commander'),
('PA-68822', '2/Lt', 'Mohammad Hamza', 'Officers', 'Pb', 'Attached'),
-- JCOs (17)
('PJO-3099842', 'SM', 'Gnr Sadar Ayub', 'JCOs', 'Pb', ''),
('PJO-3121658', 'Sub', 'Gnr Haq Nawaz', 'JCOs', 'Ptn', ''),
('PJO-3106328', 'Sub', 'Gnr Muhammad Ali', 'JCOs', 'Pb', ''),
('PJO-3100038', 'Sub', 'Gnr Ashiq Hussain', 'JCOs', 'Pb', ''),
('PJO-3100144', 'Sub', 'TA Mubarak', 'JCOs', 'Sdh', ''),
('PJO-3114197', 'N/Sub', 'Gnr Muhammad Naeem', 'JCOs', 'Pb', ''),
('PJO-3111230', 'N/Sub', 'Gnr Muhammad Asad', 'JCOs', 'Pb', ''),
('PJO-3133462', 'N/Sub', 'Gnr Fazal Wahab', 'JCOs', 'Ptn', ''),
('PJO-3117115', 'N/Sub', 'OCU Madad Khan', 'JCOs', 'Ptn', ''),
('PJO-3108705', 'N/Sub', 'DMT Bakhtiar Khan', 'JCOs', 'Sdh', ''),
('PJO-3141379', 'N/Sub', 'TA Gul Naseem', 'JCOs', 'Ptn', ''),
('PJO-3122088', 'N/Sub', 'OCU Tahir Aziz', 'JCOs', 'Pb', ''),
('PJO-3096674', 'N/Sub', 'Clk Aziz Muhammad Khan', 'JCOs', 'Ptn', ''),
('PJO-3141735', 'N/Sub', 'Gnr Muhammad Zia Ullah', 'JCOs', 'Pb', ''),
('PJO-3141475', 'N/Sub', 'Gnr Tanveer Ahmed', 'JCOs', 'Ptn', ''),
('PJO-3147263', 'N/Sub', 'Gnr Nadeem Abbas', 'JCOs', 'Pb', ''),
('PJO-3118217', 'N/Sub', 'TA Navaid Asif', 'JCOs', 'Sdh', ''),
-- Clks (12)
('3122918', 'Hav', 'Clk Bashir Ahmed', 'Clks', 'Pb', ''),
('3138647', 'Hav', 'Clk Muhammad Yasir', 'Clks', 'Ptn', ''),
('3153363', 'Hav', 'Clk Muhammad Ramzan', 'Clks', 'Pb', ''),
('3158376', 'Hav', 'Clk Muhammad Shahbaz', 'Clks', 'Pb', ''),
('3158273', 'Nk', 'Clk Muhammad Yasir', 'Clks', 'Ptn', ''),
('3169371', 'Nk', 'Clk Asif Mehmood', 'Clks', 'Pb', ''),
('3192086', 'Nk', 'Clk Muhammad Ilyas', 'Clks', 'Pb', ''),
('3158329', 'Lnk', 'Clk Shoaib Khan', 'Clks', 'Ptn', ''),
('3186830', 'Clk', 'Aamir Hayat', 'Clks', 'Ptn', ''),
('3221173', 'Clk', 'Kashif Wazir', 'Clks', 'Pb', ''),
('3221392', 'Clk', 'Asaad Anwar', 'Clks', 'Pb', ''),
('10207812', 'Clk', 'Aadil Hussain', 'Clks', 'Sdh', ''),
-- Svys (12)
('3154456', 'BQMH', 'Svy Ahmed Ali', 'Svys', 'Ptn', ''),
('3179500', 'Hav', 'Svy Muhammad Idrees', 'Svys', 'Sdh', ''),
('3156116', 'Lhav', 'Svy Khadman', 'Svys', 'Ptn', ''),
('3156156', 'Nk', 'Svy Gulfraz Ahmad', 'Svys', 'Ptn', ''),
('3175231', 'Lnk', 'Svy Wajid Khan', 'Svys', 'Ptn', ''),
('3177490', 'Lnk', 'Svy Ghulam Sajjad', 'Svys', 'Sdh', ''),
('3203222', 'Svy', 'Yasir Irfat', 'Svys', 'Pb', ''),
('3203142', 'Lnk', 'Svy Faisal Ayub', 'Svys', 'Pb', ''),
('3209192', 'Svy', 'Ismaeel Zabeehullah', 'Svys', 'Ptn', ''),
('3209817', 'Svy', 'Jamil Ali', 'Svys', 'Sdh', ''),
('3212484', 'Svy', 'Muhammad Aslam', 'Svys', 'Pb', ''),
('3208495', 'Svy', 'Muhammad Jamshed', 'Svys', 'Pb', ''),
-- TAs (28)
('3175394', 'RQMH', 'TA Aamir Shahzad', 'TAs', 'Pb', ''),
('3186474', 'Hav', 'Muhammad Sohail Adnan', 'TAs', 'Pb', ''),
('3156226', 'Hav', 'TA Younas Khan', 'TAs', 'Ptn', ''),
('3163228', 'Lhav', 'TA Naveed Iqbal', 'TAs', 'Ptn', ''),
('3156738', 'Lhav', 'TA Shaista Khan', 'TAs', 'Ptn', ''),
('3145638', 'Hav', 'TA Parvez Ahmed', 'TAs', 'Sdh', ''),
('3187922', 'Lhav', 'TA Muhammad Asif Yousaf', 'TAs', 'Pb', ''),
('3156807', 'TA', 'Amjad Ali', 'TAs', 'Sdh', ''),
('3139629', 'Nk', 'TA Farid Khan', 'TAs', 'Ptn', ''),
('3188316', 'Lnk', 'TA Abdul Salam', 'TAs', 'Sdh', ''),
('3187840', 'Nk', 'TA Muhammad Aamir', 'TAs', 'Pb', ''),
('3192839', 'Lnk', 'TA Muhammad Ashiq', 'TAs', 'Pb', ''),
('3157112', 'Lnk', 'TA Saif Ur Rehman', 'TAs', 'Ptn', ''),
('3191300', 'Lnk', 'TA Muhammad Noman', 'TAs', 'Pb', ''),
('3196939', 'Lnk', 'TA Nasir Mehmood', 'TAs', 'Pb', ''),
('3188317', 'TA', 'Muhammad Imran Fareed', 'TAs', 'Pb', ''),
('3188004', 'Lnk', 'TA Humair Raza Kazmai', 'TAs', 'Pb', ''),
('3156623', 'TA', 'Abdul Wahab', 'TAs', 'Ptn', ''),
('3164739', 'TA', 'Manzoor Elahi', 'TAs', 'Ptn', ''),
('3177687', 'Nk', 'TA Muhammad Kashif', 'TAs', 'Sdh', ''),
('3161148', 'Lnk', 'TA Nadeem Khan', 'TAs', 'Ptn', ''),
('3188615', 'Nk', 'TA Muhammad Asif', 'TAs', 'Pb', ''),
('3216620', 'TA', 'Sameed Khan', 'TAs', 'Ptn', ''),
('3226536', 'TA', 'Muhammad Zesshan Khan', 'TAs', 'Pb', ''),
('3227884', 'TA', 'Asad Farooq', 'TAs', 'Pb', ''),
('3225476', 'TA', 'Javed Akhtar', 'TAs', 'Pb', ''),
('3215615', 'TA', 'Hazrat Ullah', 'TAs', 'Ptn', ''),
('3226167', 'TA', 'Ali Husnain', 'TAs', 'Pb', ''),
-- OCsU (representative sample)
('3144778', 'RHM Hav', 'OCU Ghulam Abbas', 'OCsU', 'Pb', ''),
('3125849', 'Hav', 'OCU Sajjad Ali', 'OCsU', 'Ptn', ''),
('3137700', 'Hav', 'OCU Irfan Ali', 'OCsU', 'Ptn', ''),
('3149393', 'Hav', 'OCU Asim Shahzad', 'OCsU', 'Pb', ''),
('3143873', 'Lhav', 'OCU Sajid', 'OCsU', 'Ptn', ''),
('3146799', 'Lhav', 'OCU Rajab Ali', 'OCsU', 'Pb', '');


-- 2. SEED CATEGORY HIERARCHY TREE
DO $$
DECLARE
    pres_id UUID; lve_id UUID; aval_id UUID; att_id UUID; crs_id UUID;
    osl_id UUID; sg_id UUID; ug_id UUID; cmh_id UUID; reg_id UUID;
    trg_id UUID; spt_id UUID; aslt_id UUID; dido_id UUID; work_id UUID;
    prot_id UUID; ex_id UUID; ud_id UUID; sub_id UUID;
BEGIN
    -- Level 1: Main Categories
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Present', NULL, 1) RETURNING id INTO pres_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Leave', NULL, 1) RETURNING id INTO lve_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Aval', NULL, 1) RETURNING id INTO aval_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Att', NULL, 1) RETURNING id INTO att_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Courses', NULL, 1) RETURNING id INTO crs_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('OSL/Pris', NULL, 1) RETURNING id INTO osl_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Sta Gds', NULL, 1) RETURNING id INTO sg_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Unit Gds', NULL, 1) RETURNING id INTO ug_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('CMH/Sick', NULL, 1) RETURNING id INTO cmh_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Regt Emp', NULL, 1) RETURNING id INTO reg_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Trg', NULL, 1) RETURNING id INTO trg_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Sports', NULL, 1) RETURNING id INTO spt_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Aslt Course', NULL, 1) RETURNING id INTO aslt_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('DIDO', NULL, 1) RETURNING id INTO dido_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Working', NULL, 1) RETURNING id INTO work_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Prot', NULL, 1) RETURNING id INTO prot_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Ex/Cl', NULL, 1) RETURNING id INTO ex_id;
    INSERT INTO status_categories (name, parent_id, level) VALUES ('U/D', NULL, 1) RETURNING id INTO ud_id;

    -- Level 2: Subcategories under Present
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Duty', pres_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Standby', pres_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Office', pres_id, 2);

    -- Level 2: Subcategories under Leave
    INSERT INTO status_categories (name, parent_id, level) VALUES ('P/Lve', lve_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('C/Lve', lve_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Weekend', lve_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Sick Lve', lve_id, 2);

    -- Level 2: Subcategories under Aval
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Leave Reserve', aval_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('General Aval', aval_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Other', aval_id, 2);

    -- Level 2+3: Subcategories and Sub-subcategories under Att
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Perm Comd', att_id, 2) RETURNING id INTO sub_id;
        INSERT INTO status_categories (name, parent_id, level) VALUES ('Arms Br', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('Army Camp', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('PMA', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('3 Trg/ASL Muree', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('UN Msn', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('COAS Dte', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('52 RSTE', sub_id, 3);

    INSERT INTO status_categories (name, parent_id, level) VALUES ('Temp', att_id, 2) RETURNING id INTO sub_id;
        INSERT INTO status_categories (name, parent_id, level) VALUES ('9 Div', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('30 CAB', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('30 Corps', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('Arty Cen', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('325 CIB', sub_id, 3);
        INSERT INTO status_categories (name, parent_id, level) VALUES ('Arms Br', sub_id, 3);

    -- Level 2: Subcategories under Courses
    INSERT INTO status_categories (name, parent_id, level) VALUES ('JSC/ MCC/OGS', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('PRT Course', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('ARI(TA)', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('ARI(G)', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('SNBIC', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('SCC Screening', crs_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('JNAC', crs_id, 2);

    -- Level 2: Subcategories under OSL/Pris
    INSERT INTO status_categories (name, parent_id, level) VALUES ('OSL', osl_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Regt Prisoner', osl_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Detained', osl_id, 2);

    -- Level 2: Subcategories under Sta Gds
    INSERT INTO status_categories (name, parent_id, level) VALUES ('ISI Sub Sec Gd', sg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('COM Gd', sg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('FG Deg Gd', sg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('PRO Sec', sg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('GMP', sg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Ammo Gd', sg_id, 2);

    -- Level 2: Subcategories under Unit Gds
    INSERT INTO status_categories (name, parent_id, level) VALUES ('MT', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('158 Line', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('POL', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('148 SP', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Stores', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Office', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Guns', ug_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Prisoner', ug_id, 2);

    -- Level 2: Subcategories under CMH/Sick
    INSERT INTO status_categories (name, parent_id, level) VALUES ('CMH Gwa', cmh_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('SIQ', cmh_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('CMH Kht', cmh_id, 2);

    -- Level 2: Subcategories under Regt Emp
    INSERT INTO status_categories (name, parent_id, level) VALUES ('RP', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Ck House', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Adm/Emg/CO Veh', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('DR', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Rnrs', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Orderly/ Daily NCO', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Complain NCO', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Tea Bar NCO', reg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Store Man', reg_id, 2);

    -- Level 2: Subcategories under Trg
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Observer', trg_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Guns', trg_id, 2);

    -- Level 2: Subcategories under Sports
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Rugby', spt_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Volleyball', spt_id, 2);

    -- Level 2: Subcategories under Aslt Course
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Obstacle Trg', aslt_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Physical Test', aslt_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('General Aslt', aslt_id, 2);

    -- Level 2: Subcategories under DIDO
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Waiters', dido_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Managers', dido_id, 2);

    -- Level 2: Subcategories under Working
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Area Maint', work_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Weapon Maint', work_id, 2);

    -- Level 2: Subcategories under Prot
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Chinese Team', prot_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Players Pot', prot_id, 2);

    -- Level 2: Subcategories under Ex/Cl
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Extra Class', ex_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Remedial Class', ex_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Other', ex_id, 2);

    -- Level 2: Subcategories under U/D
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Under Displ', ud_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Inquiry', ud_id, 2);
    INSERT INTO status_categories (name, parent_id, level) VALUES ('Other', ud_id, 2);
END $$;


-- 3. SEED STATUS HISTORY TIMELINE
INSERT INTO status_history (army_no, category, subcategory, sub_subcategory, start_date, end_date, destination) VALUES
-- Lt Col Tayyab timeline
('PA-43337', 'Present', 'Office', NULL, NOW() - INTERVAL '90 days', NOW() - INTERVAL '60 days', NULL),
('PA-43337', 'Leave', 'C/Lve', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '30 days', 'Lahore'),
('PA-43337', 'Present', 'Duty', NULL, NOW() - INTERVAL '30 days', NULL, NULL),
-- Maj Usman Anwar timeline
('PA-45571', 'Courses', 'JNAC', NULL, NOW() - INTERVAL '90 days', NOW() - INTERVAL '60 days', NULL),
('PA-45571', 'Present', 'Standby', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '30 days', NULL),
('PA-45571', 'Present', 'Office', NULL, NOW() - INTERVAL '30 days', NULL, NULL),
-- Maj Azfar timeline
('PA-55563', 'Present', 'Duty', NULL, NOW() - INTERVAL '90 days', NOW() - INTERVAL '60 days', NULL),
('PA-55563', 'Sta Gds', 'COM Gd', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '30 days', NULL),
('PA-55563', 'Present', 'Office', NULL, NOW() - INTERVAL '30 days', NULL, NULL),
-- Capt Muhammad Ali timeline
('PA-61755', 'Present', 'Office', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '15 days', NULL),
('PA-61755', 'Att', 'Perm Comd', 'PMA', NOW() - INTERVAL '15 days', NULL, 'Kakul Abbottabad'),
-- Clk Bashir Ahmed timeline
('3122918', 'Regt Emp', 'RP', NULL, NOW() - INTERVAL '90 days', NOW() - INTERVAL '60 days', NULL),
('3122918', 'Present', 'Duty', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '30 days', NULL),
('3122918', 'Leave', 'C/Lve', NULL, NOW() - INTERVAL '30 days', NULL, 'Rawalpindi'),
-- N/Sub Muhammad Naeem timeline
('PJO-3114197', 'CMH/Sick', 'SIQ', NULL, NOW() - INTERVAL '90 days', NOW() - INTERVAL '60 days', NULL),
('PJO-3114197', 'Present', 'Duty', NULL, NOW() - INTERVAL '60 days', NOW() - INTERVAL '10 days', NULL),
('PJO-3114197', 'Aslt Course', 'Obstacle Trg', NULL, NOW() - INTERVAL '10 days', NULL, 'Sector 4'),
-- Remaining personnel: set to Present/Duty (active) with a 10 day start
('PA-52402', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-56482', 'Leave', 'P/Lve', NULL, NOW() - INTERVAL '10 days', NULL, 'Peshawar'),
('PA-61131', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-65543', 'Trg', 'Observer', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-66748', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-66674', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-66234', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-67711', 'Sta Gds', 'COM Gd', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PA-68822', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3099842', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3121658', 'Leave', 'Weekend', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3106328', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3100038', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3100144', 'Aval', 'Leave Reserve', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3111230', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3133462', 'Regt Emp', 'RP', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3117115', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3108705', 'CMH/Sick', 'SIQ', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3141379', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3122088', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3096674', 'Unit Gds', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3141735', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3141475', 'Courses', 'PRT Course', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3147263', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('PJO-3118217', 'Att', 'Temp', '30 Corps', NOW() - INTERVAL '10 days', NULL, NULL),
('3138647', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3153363', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3158376', 'Regt Emp', 'Store Man', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3158273', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3169371', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3192086', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3158329', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3186830', 'Leave', 'C/Lve', NULL, NOW() - INTERVAL '10 days', NULL, 'Islamabad'),
('3221173', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3221392', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('10207812', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3154456', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3179500', 'Sports', 'Volleyball', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156116', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156156', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3175231', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3177490', 'Working', 'Area Maint', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3203222', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3203142', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3209192', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3209817', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3212484', 'Sta Gds', 'Ammo Gd', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3208495', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3175394', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3186474', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156226', 'Leave', 'P/Lve', NULL, NOW() - INTERVAL '10 days', NULL, 'Kohat'),
('3163228', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156738', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3145638', 'DIDO', 'Waiters', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3187922', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156807', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3139629', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3188316', 'Prot', 'Chinese Team', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3187840', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3192839', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3157112', 'OSL/Pris', 'OSL', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3191300', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3196939', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3188317', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3188004', 'Ex/Cl', 'Extra Class', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3156623', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3164739', 'U/D', 'Under Displ', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3177687', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3161148', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3188615', 'Unit Gds', 'MT', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3216620', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3226536', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3227884', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3225476', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3215615', 'Aslt Course', 'Physical Test', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3226167', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3144778', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3125849', 'Present', 'Office', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3137700', 'Regt Emp', 'Ck House', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3149393', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3143873', 'Present', 'Standby', NULL, NOW() - INTERVAL '10 days', NULL, NULL),
('3146799', 'Present', 'Duty', NULL, NOW() - INTERVAL '10 days', NULL, NULL);


-- 4. SEED COMMAND GROUP LOGIN SLOTS
INSERT INTO command_slots (slot_id, role, army_no, username, password) VALUES
(1,  'superadmin', 'PA-43337', 'tayyab',  '123456'),
(2,  'admin',      'PA-45571', 'usman',   '123456'),
(3,  'admin',      'PA-55563', 'azfar',   '123456'),
(4,  'admin',      'PA-52402', 'umair',   '123456'),
(5,  'admin',      'PA-56482', 'raza',    '123456'),
(6,  'user',       'PA-61131', 'nabeel',  '123456'),
(7,  'user',       'PA-61755', 'ali',     '123456'),
(8,  'user',       'PA-65543', 'taimoor', '123456'),
(9,  'user',       NULL,       'bilal',   '123456'),
(10, 'user',       NULL,       'hamza',   '123456'),
(11, 'user',       NULL,       'talha',   '123456'),
(12, 'user',       NULL,       'sameer',  '123456');


-- 5. SEED SYSTEM ATTRIBUTES
INSERT INTO system_attributes (attribute_type, items) VALUES
('trades',    '["All", "Gnr", "TA", "OCU", "DMT", "DSV", "Svy", "Clk", "Ck", "Engr", "N/A", "LAD", "NCB", "S/W", "Civ"]'::jsonb),
('ranks',     '["All", "Officers", "  Lt Col", "  Maj", "  Capt", "  Lt", "  2/Lt", "JCOs", "  SM", "  Sub", "  N/Sub", "Soldiers", "  Hav", "  Lhav", "  Nk", "  Lnk", "  Sep"]'::jsonb),
('batteries', '["All", "HQ Bty", "P Bty", "Q Bty", "R Bty"]'::jsonb);


-- 6. SEED CUSTOM GROUPS & MEMBERS
DO $$
DECLARE
    grp1_id UUID;
    grp2_id UUID;
    grp3_id UUID;
BEGIN
    INSERT INTO custom_groups (name, category, leader_army_no, leader_name, location, until_date)
    VALUES ('PMA Visit Team', 'Travel', 'PA-61755', 'Capt Muhammad Ali', 'Kakul Abbottabad', '2026-07-15 18:00:00+05'::timestamptz)
    RETURNING id INTO grp1_id;

    INSERT INTO group_members (group_id, army_no) VALUES
    (grp1_id, '3122918'),
    (grp1_id, '3138647'),
    (grp1_id, '3153363'),
    (grp1_id, '3158376');

    INSERT INTO custom_groups (name, category, leader_army_no, leader_name, location, until_date)
    VALUES ('Assault Course Prep A', 'Training', 'PJO-3114197', 'N/Sub Gnr Muhammad Naeem', 'Training Area Sector 4', '2026-07-12 14:00:00+05'::timestamptz)
    RETURNING id INTO grp2_id;

    INSERT INTO group_members (group_id, army_no) VALUES
    (grp2_id, '3158273'),
    (grp2_id, '3169371'),
    (grp2_id, '3192086');

    INSERT INTO custom_groups (name, category, leader_army_no, leader_name, location, until_date)
    VALUES ('Kitchen Working Party', 'Working Party', 'PA-45571', 'Maj Muhammad Usman Anwar', 'Mess Hall Cookhouse', '2026-07-10 20:00:00+05'::timestamptz)
    RETURNING id INTO grp3_id;

    INSERT INTO group_members (group_id, army_no) VALUES
    (grp3_id, '3158329'),
    (grp3_id, '3186830'),
    (grp3_id, '3221173'),
    (grp3_id, '3221392');
END $$;


-- ============================================================================
-- DONE. Schema ready. Run this in Supabase SQL Editor.
-- ============================================================================
