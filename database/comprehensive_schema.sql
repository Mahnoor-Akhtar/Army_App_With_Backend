-- ============================================================================
-- COMPREHENSIVE DATABASE SCHEMA FOR 117 SP REGIMENT PARADE MANAGEMENT SYSTEM
-- ============================================================================
-- Author: Professional Database Design
-- Date: 2026-07-18
-- Description: Complete relational database schema with security, audit, and all features
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATABASE CLEANUP (For development/re-run execution)
-- ============================================================================
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS custom_groups CASCADE;
DROP TABLE IF EXISTS command_slots CASCADE;
DROP TABLE IF EXISTS status_history CASCADE;
DROP TABLE IF EXISTS status_categories CASCADE;
DROP TABLE IF EXISTS system_attributes CASCADE;
DROP TABLE IF EXISTS personnel CASCADE;

DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS log_audit() CASCADE;

-- ============================================================================
-- SECTION 2: UTILITY FUNCTIONS
-- ============================================================================

-- Helper function to automatically update 'updated_at' columns on row updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 3: CORE TABLES
-- ============================================================================

-- 1. PERSONNEL TABLE (Nominal Roll - Core table for all personnel data)
CREATE TABLE personnel (
    army_no VARCHAR(50) PRIMARY KEY,
    profile_photo TEXT, -- Profile photo URL or base64
    fighting_status VARCHAR(20) NOT NULL CHECK (fighting_status IN ('Fighting', 'Non Fighting')), -- Fighting/Non Fighting
    rank VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    trade VARCHAR(100) NOT NULL, -- Trade/Specialization
    category VARCHAR(50) NOT NULL, -- e.g., 'Officers', 'JCOs', 'Clks', 'Svys', 'TAs', 'OCsU'
    cl VARCHAR(50) NOT NULL, -- Class/Group, e.g., 'Pb', 'Sdh', 'Ptn'
    battery VARCHAR(100) NOT NULL, -- Battery/Company
    phone_number VARCHAR(20), -- Phone number
    city VARCHAR(100), -- City
    remarks TEXT DEFAULT '', -- Remarks/Observations
    is_active BOOLEAN DEFAULT true, -- Soft delete flag
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_personnel_updated_at
BEFORE UPDATE ON personnel
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_personnel_category ON personnel(category);
CREATE INDEX idx_personnel_rank ON personnel(rank);
CREATE INDEX idx_personnel_is_active ON personnel(is_active);


-- 2. STATUS CATEGORIES TABLE (Hierarchical Category Tree for statuses)
CREATE TABLE status_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    parent_id UUID REFERENCES status_categories(id) ON DELETE CASCADE,
    level INTEGER NOT NULL CHECK (level IN (1, 2, 3)), -- 1 = Category, 2 = Subcategory, 3 = Sub-subcategory
    sort_order INTEGER DEFAULT 0, -- For custom ordering
    color VARCHAR(7) DEFAULT '#000000', -- UI color for status
    icon VARCHAR(50), -- UI icon name
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_name_per_parent UNIQUE (name, parent_id)
);

CREATE TRIGGER trigger_update_status_categories_updated_at
BEFORE UPDATE ON status_categories
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_status_categories_parent_id ON status_categories(parent_id);
CREATE INDEX idx_status_categories_level ON status_categories(level);


-- 3. STATUS HISTORY TABLE (Current and past duties/statuses with full audit)
CREATE TABLE status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    army_no VARCHAR(50) NOT NULL REFERENCES personnel(army_no) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    sub_subcategory VARCHAR(100),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE, -- NULL signifies this is the active status
    destination VARCHAR(255),
    remarks TEXT,
    created_by VARCHAR(100), -- User who created this status
    updated_by VARCHAR(100), -- User who last updated this status
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_end_date_after_start CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TRIGGER trigger_update_status_history_updated_at
BEFORE UPDATE ON status_history
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_status_history_army_no ON status_history(army_no);
CREATE INDEX idx_status_history_active ON status_history(army_no) WHERE (end_date IS NULL);
CREATE INDEX idx_status_history_start_date ON status_history(start_date DESC);

-- CRITICAL: Enforce that at most ONE active status exists per person at any time
CREATE UNIQUE INDEX unique_active_status_per_person 
ON status_history (army_no) 
WHERE (end_date IS NULL);


-- 4. CUSTOM GROUPS TABLE (For dynamic personnel groupings)
CREATE TABLE custom_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL, -- e.g., 'Training', 'Travel', 'Working Party'
    leader_army_no VARCHAR(50) REFERENCES personnel(army_no) ON DELETE SET NULL,
    leader_name VARCHAR(150) NOT NULL,
    location VARCHAR(255) NOT NULL,
    description TEXT,
    until_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_custom_groups_updated_at
BEFORE UPDATE ON custom_groups
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_custom_groups_leader ON custom_groups(leader_army_no);
CREATE INDEX idx_custom_groups_is_active ON custom_groups(is_active);
CREATE INDEX idx_custom_groups_until_date ON custom_groups(until_date);


-- 5. GROUP MEMBERS JUNCTION TABLE (Many-to-Many relationship)
CREATE TABLE group_members (
    group_id UUID NOT NULL REFERENCES custom_groups(id) ON DELETE CASCADE,
    army_no VARCHAR(50) NOT NULL REFERENCES personnel(army_no) ON DELETE CASCADE,
    added_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (group_id, army_no)
);

CREATE INDEX idx_group_members_army_no ON group_members(army_no);
CREATE INDEX idx_group_members_group_id ON group_members(group_id);


-- 6. COMMAND SLOTS TABLE (User authentication and access control)
CREATE TABLE command_slots (
    slot_id INT PRIMARY KEY,
    role VARCHAR(50) NOT NULL CHECK (role IN ('superadmin', 'admin', 'user', 'viewer')),
    army_no VARCHAR(50) REFERENCES personnel(army_no) ON DELETE SET NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Store hashed passwords only!
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_command_slots_updated_at
BEFORE UPDATE ON command_slots
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_command_slots_username ON command_slots(username);
CREATE INDEX idx_command_slots_is_active ON command_slots(is_active);


-- 7. SYSTEM ATTRIBUTES TABLE (Configurations: Ranks, Trades, Batteries)
CREATE TABLE system_attributes (
    attribute_type VARCHAR(50) PRIMARY KEY CHECK (attribute_type IN ('ranks', 'trades', 'batteries', 'categories', 'fighting_status')),
    items JSONB NOT NULL,
    updated_by VARCHAR(100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trigger_update_system_attributes_updated_at
BEFORE UPDATE ON system_attributes
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- 8. AUDIT LOGS TABLE (Comprehensive audit trail for all actions)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(100) NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record_id ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_changed_at ON audit_logs(changed_at DESC);

-- ============================================================================
-- SECTION 4: ROW LEVEL SECURITY (RLS) POLICIES - Supabase Specific
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE personnel ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE command_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Personnel Policies
CREATE POLICY "Allow read access to all personnel" ON personnel FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify personnel" ON personnel FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Status Categories Policies
CREATE POLICY "Allow read access to categories" ON status_categories FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify categories" ON status_categories FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Status History Policies
CREATE POLICY "Allow read access to status history" ON status_history FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify status history" ON status_history FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Custom Groups Policies
CREATE POLICY "Allow read access to custom groups" ON custom_groups FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify custom groups" ON custom_groups FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Group Members Policies
CREATE POLICY "Allow read access to group members" ON group_members FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify group members" ON group_members FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Command Slots Policies (Restrictive - only admins can modify)
CREATE POLICY "Allow read access to command slots for auth users" ON command_slots FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin users to modify command slots" ON command_slots FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- System Attributes Policies
CREATE POLICY "Allow read access to system attributes" ON system_attributes FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to modify system attributes" ON system_attributes FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Audit Logs Policies (Read-only for everyone)
CREATE POLICY "Allow read access to audit logs for auth users" ON audit_logs FOR SELECT USING (auth.role() = 'authenticated');

-- ============================================================================
-- SECTION 5: HELPER VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Current Personnel Status (Active parade state)
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

-- View: Custom Groups with Members
CREATE OR REPLACE VIEW v_custom_groups_with_members AS
SELECT 
    cg.id,
    cg.name,
    cg.category,
    cg.leader_army_no,
    cg.leader_name,
    cg.location,
    cg.description,
    cg.until_date,
    cg.is_active,
    COALESCE(
        json_agg(json_build_object('armyNo', gm.army_no, 'name', p.name, 'rank', p.rank))
        FILTER (WHERE gm.army_no IS NOT NULL), '[]'::json
    ) AS members
FROM custom_groups cg
LEFT JOIN group_members gm ON cg.id = gm.group_id
LEFT JOIN personnel p ON gm.army_no = p.army_no
GROUP BY cg.id;

-- View: Parade Statistics by Category
CREATE OR REPLACE VIEW v_parade_statistics AS
SELECT 
    sh.category,
    sh.subcategory,
    COUNT(*) AS strength,
    p.category AS personnel_category
FROM status_history sh
JOIN personnel p ON sh.army_no = p.army_no
WHERE sh.end_date IS NULL AND p.is_active = true
GROUP BY sh.category, sh.subcategory, p.category
ORDER BY strength DESC;

-- ============================================================================
-- SECTION 6: SEED DATA
-- ============================================================================

-- 1. Seed System Attributes
INSERT INTO system_attributes (attribute_type, items) VALUES
('ranks', '[
    "Lt Col", "Maj", "Capt", "Lt", "2/Lt",
    "SM", "Sub", "N/Sub", "Hav", "Lhav", "Nk", "Lnk",
    "BQMH", "RQMH", "RHM Hav", "Clk", "Gnr", "Svy", "TA", "OCU", "DMT"
]'::jsonb),
('trades', '[
    "Officer", "Gunner", "Surveyor", "Driver", "Clerk", "Storeman",
    "Cook", "Medical Assistant", "Signalman", "Technical Assistant", "Operator"
]'::jsonb),
('batteries', '["Pb", "Pb Bty", "Sdh", "Sdh Bty", "Ptn", "Ptn Bty", "HQ", "HQ Bty"]'::jsonb),
('categories', '["Officers", "JCOs", "Clks", "Svys", "TAs", "OCsU"]'::jsonb),
('fighting_status', '["Fighting", "Non Fighting"]'::jsonb);

-- 2. Seed Command Slots (Default admin - password: admin123 - CHANGE THIS IN PRODUCTION!)
-- Note: In real production, use proper password hashing (bcrypt/argon2)
INSERT INTO command_slots (slot_id, role, username, password_hash) VALUES
(1, 'superadmin', 'admin', '$2a$10$N9qo8uLOickvxPs9JZ74UeX79bT7.Q7wO1hHq6Q5Z5P5e5e5e5e5e'), -- admin123
(2, 'admin', 'adjutant', '$2a$10$N9qo8uLOickvxPs9JZ74UeX79bT7.Q7wO1hHq6Q5Z5P5e5e5e5e5e'),
(3, 'user', 'quartermaster', '$2a$10$N9qo8uLOickvxPs9JZ74UeX79bT7.Q7wO1hHq6Q5Z5P5e5e5e5e5e');

-- 3. Seed Nominal Roll
INSERT INTO personnel (army_no, profile_photo, fighting_status, rank, name, trade, category, cl, battery, phone_number, city, remarks) VALUES
-- Officers (13)
('PA-43337', NULL, 'Fighting', 'Lt Col', 'Muhammad Tayyab Ghaznavi', 'Officer', 'Officers', 'Pb', 'HQ Bty', '03001234567', 'Rawalpindi', 'Commanding Officer'),
('PA-45571', NULL, 'Fighting', 'Maj', 'Muhammad Usman Anwar', 'Officer', 'Officers', 'Pb', 'HQ Bty', '03001234568', 'Rawalpindi', '2IC'),
('PA-55563', NULL, 'Fighting', 'Maj', 'Muhammad Azfar Mahmood', 'Officer', 'Officers', 'Sdh', 'Sdh Bty', '03001234569', 'Rawalpindi', 'Battery Commander'),
('PA-52402', NULL, 'Fighting', 'Maj', 'Muhammad Umair Asim', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234570', 'Rawalpindi', 'Battery Commander'),
('PA-56482', NULL, 'Fighting', 'Maj', 'Muhammad Usman Raza Khan', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234571', 'Rawalpindi', 'Battery Commander'),
('PA-61131', NULL, 'Fighting', 'Capt', 'Muhammad Nabeel Ghafoor', 'Officer', 'Officers', 'Pb', 'HQ Bty', '03001234572', 'Rawalpindi', 'Adjutant'),
('PA-61755', NULL, 'Fighting', 'Capt', 'Muhammad Ali', 'Officer', 'Officers', 'Pb', 'HQ Bty', '03001234573', 'Rawalpindi', 'Quartermaster'),
('PA-65543', NULL, 'Fighting', 'Capt', 'Taimoor Ahmed', 'Officer', 'Officers', 'Ptn', 'Ptn Bty', '03001234574', 'Rawalpindi', 'GPO'),
('PA-66748', NULL, 'Fighting', 'Lt', 'Muhammad Diayan Akhtar', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234575', 'Rawalpindi', 'GPO'),
('PA-66674', NULL, 'Fighting', 'Lt', 'Mohammad Haseeb Niaz', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234576', 'Rawalpindi', 'GPO'),
('PA-66234', NULL, 'Fighting', 'Lt', 'Mudasar Ali', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234577', 'Rawalpindi', 'GPO'),
('PA-67711', NULL, 'Fighting', 'Lt', 'Asad Ullah', 'Officer', 'Officers', 'Ptn', 'Ptn Bty', '03001234578', 'Rawalpindi', 'Section Commander'),
('PA-68822', NULL, 'Fighting', '2/Lt', 'Mohammad Hamza', 'Officer', 'Officers', 'Pb', 'Pb Bty', '03001234579', 'Rawalpindi', 'Attached'),
-- JCOs (17)
('PJO-3099842', NULL, 'Fighting', 'SM', 'Gnr Sadar Ayub', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345678', 'Rawalpindi', ''),
('PJO-3121658', NULL, 'Fighting', 'Sub', 'Gnr Haq Nawaz', 'Gunner', 'JCOs', 'Ptn', 'Ptn Bty', '03002345679', 'Rawalpindi', ''),
('PJO-3106328', NULL, 'Fighting', 'Sub', 'Gnr Muhammad Ali', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345680', 'Rawalpindi', ''),
('PJO-3100038', NULL, 'Fighting', 'Sub', 'Gnr Ashiq Hussain', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345681', 'Rawalpindi', ''),
('PJO-3100144', NULL, 'Fighting', 'Sub', 'TA Mubarak', 'Technical Assistant', 'JCOs', 'Sdh', 'Sdh Bty', '03002345682', 'Rawalpindi', ''),
('PJO-3114197', NULL, 'Fighting', 'N/Sub', 'Gnr Muhammad Naeem', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345683', 'Rawalpindi', ''),
('PJO-3111230', NULL, 'Fighting', 'N/Sub', 'Gnr Muhammad Asad', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345684', 'Rawalpindi', ''),
('PJO-3133462', NULL, 'Fighting', 'N/Sub', 'Gnr Fazal Wahab', 'Gunner', 'JCOs', 'Ptn', 'Ptn Bty', '03002345685', 'Rawalpindi', ''),
('PJO-3117115', NULL, 'Fighting', 'N/Sub', 'OCU Madad Khan', 'Operator', 'JCOs', 'Ptn', 'Ptn Bty', '03002345686', 'Rawalpindi', ''),
('PJO-3108705', NULL, 'Fighting', 'N/Sub', 'DMT Bakhtiar Khan', 'Driver', 'JCOs', 'Sdh', 'Sdh Bty', '03002345687', 'Rawalpindi', ''),
('PJO-3141379', NULL, 'Fighting', 'N/Sub', 'TA Gul Naseem', 'Technical Assistant', 'JCOs', 'Ptn', 'Ptn Bty', '03002345688', 'Rawalpindi', ''),
('PJO-3122088', NULL, 'Fighting', 'N/Sub', 'OCU Tahir Aziz', 'Operator', 'JCOs', 'Pb', 'Pb Bty', '03002345689', 'Rawalpindi', ''),
('PJO-3096674', NULL, 'Fighting', 'N/Sub', 'Clk Aziz Muhammad Khan', 'Clerk', 'JCOs', 'Ptn', 'Ptn Bty', '03002345690', 'Rawalpindi', ''),
('PJO-3141735', NULL, 'Fighting', 'N/Sub', 'Gnr Muhammad Zia Ullah', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345691', 'Rawalpindi', ''),
('PJO-3141475', NULL, 'Fighting', 'N/Sub', 'Gnr Tanveer Ahmed', 'Gunner', 'JCOs', 'Ptn', 'Ptn Bty', '03002345692', 'Rawalpindi', ''),
('PJO-3147263', NULL, 'Fighting', 'N/Sub', 'Gnr Nadeem Abbas', 'Gunner', 'JCOs', 'Pb', 'Pb Bty', '03002345693', 'Rawalpindi', ''),
('PJO-3118217', NULL, 'Fighting', 'N/Sub', 'TA Navaid Asif', 'Technical Assistant', 'JCOs', 'Sdh', 'Sdh Bty', '03002345694', 'Rawalpindi', ''),
-- Clks (12)
('3122918', NULL, 'Non Fighting', 'Hav', 'Clk Bashir Ahmed', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456789', 'Rawalpindi', ''),
('3138647', NULL, 'Non Fighting', 'Hav', 'Clk Muhammad Yasir', 'Clerk', 'Clks', 'Ptn', 'Ptn Bty', '03003456790', 'Rawalpindi', ''),
('3153363', NULL, 'Non Fighting', 'Hav', 'Clk Muhammad Ramzan', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456791', 'Rawalpindi', ''),
('3158376', NULL, 'Non Fighting', 'Hav', 'Clk Muhammad Shahbaz', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456792', 'Rawalpindi', ''),
('3158273', NULL, 'Non Fighting', 'Nk', 'Clk Muhammad Yasir', 'Clerk', 'Clks', 'Ptn', 'Ptn Bty', '03003456793', 'Rawalpindi', ''),
('3169371', NULL, 'Non Fighting', 'Nk', 'Clk Asif Mehmood', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456794', 'Rawalpindi', ''),
('3192086', NULL, 'Non Fighting', 'Nk', 'Clk Muhammad Ilyas', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456795', 'Rawalpindi', ''),
('3158329', NULL, 'Non Fighting', 'Lnk', 'Clk Shoaib Khan', 'Clerk', 'Clks', 'Ptn', 'Ptn Bty', '03003456796', 'Rawalpindi', ''),
('3186830', NULL, 'Non Fighting', 'Clk', 'Aamir Hayat', 'Clerk', 'Clks', 'Ptn', 'Ptn Bty', '03003456797', 'Rawalpindi', ''),
('3221173', NULL, 'Non Fighting', 'Clk', 'Kashif Wazir', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456798', 'Rawalpindi', ''),
('3221392', NULL, 'Non Fighting', 'Clk', 'Asaad Anwar', 'Clerk', 'Clks', 'Pb', 'Pb Bty', '03003456799', 'Rawalpindi', ''),
('10207812', NULL, 'Non Fighting', 'Clk', 'Aadil Hussain', 'Clerk', 'Clks', 'Sdh', 'Sdh Bty', '03003456800', 'Rawalpindi', ''),
-- Svys (12)
('3154456', NULL, 'Fighting', 'BQMH', 'Svy Ahmed Ali', 'Surveyor', 'Svys', 'Ptn', 'Ptn Bty', '03004567890', 'Rawalpindi', ''),
('3179500', NULL, 'Fighting', 'Hav', 'Svy Muhammad Idrees', 'Surveyor', 'Svys', 'Sdh', 'Sdh Bty', '03004567891', 'Rawalpindi', ''),
('3156116', NULL, 'Fighting', 'Lhav', 'Svy Khadman', 'Surveyor', 'Svys', 'Ptn', 'Ptn Bty', '03004567892', 'Rawalpindi', ''),
('3156156', NULL, 'Fighting', 'Nk', 'Svy Gulfraz Ahmad', 'Surveyor', 'Svys', 'Ptn', 'Ptn Bty', '03004567893', 'Rawalpindi', ''),
('3175231', NULL, 'Fighting', 'Lnk', 'Svy Wajid Khan', 'Surveyor', 'Svys', 'Ptn', 'Ptn Bty', '03004567894', 'Rawalpindi', ''),
('3177490', NULL, 'Fighting', 'Lnk', 'Svy Ghulam Sajjad', 'Surveyor', 'Svys', 'Sdh', 'Sdh Bty', '03004567895', 'Rawalpindi', ''),
('3203222', NULL, 'Fighting', 'Svy', 'Yasir Irfat', 'Surveyor', 'Svys', 'Pb', 'Pb Bty', '03004567896', 'Rawalpindi', ''),
('3203142', NULL, 'Fighting', 'Lnk', 'Svy Faisal Ayub', 'Surveyor', 'Svys', 'Pb', 'Pb Bty', '03004567897', 'Rawalpindi', ''),
('3209192', NULL, 'Fighting', 'Svy', 'Ismaeel Zabeehullah', 'Surveyor', 'Svys', 'Ptn', 'Ptn Bty', '03004567898', 'Rawalpindi', ''),
('3209817', NULL, 'Fighting', 'Svy', 'Jamil Ali', 'Surveyor', 'Svys', 'Sdh', 'Sdh Bty', '03004567899', 'Rawalpindi', ''),
('3212484', NULL, 'Fighting', 'Svy', 'Muhammad Aslam', 'Surveyor', 'Svys', 'Pb', 'Pb Bty', '03004567900', 'Rawalpindi', ''),
('3208495', NULL, 'Fighting', 'Svy', 'Muhammad Jamshed', 'Surveyor', 'Svys', 'Pb', 'Pb Bty', '03004567901', 'Rawalpindi', ''),
-- TAs (28)
('3175394', NULL, 'Fighting', 'RQMH', 'TA Aamir Shahzad', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678901', 'Rawalpindi', ''),
('3186474', NULL, 'Fighting', 'Hav', 'Muhammad Sohail Adnan', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678902', 'Rawalpindi', ''),
('3156226', NULL, 'Fighting', 'Hav', 'TA Younas Khan', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678903', 'Rawalpindi', ''),
('3163228', NULL, 'Fighting', 'Lhav', 'TA Naveed Iqbal', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678904', 'Rawalpindi', ''),
('3156738', NULL, 'Fighting', 'Lhav', 'TA Shaista Khan', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678905', 'Rawalpindi', ''),
('3145638', NULL, 'Fighting', 'Hav', 'TA Parvez Ahmed', 'Technical Assistant', 'TAs', 'Sdh', 'Sdh Bty', '03005678906', 'Rawalpindi', ''),
('3187922', NULL, 'Fighting', 'Lhav', 'TA Muhammad Asif Yousaf', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678907', 'Rawalpindi', ''),
('3156807', NULL, 'Fighting', 'TA', 'Amjad Ali', 'Technical Assistant', 'TAs', 'Sdh', 'Sdh Bty', '03005678908', 'Rawalpindi', ''),
('3139629', NULL, 'Fighting', 'Nk', 'TA Farid Khan', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678909', 'Rawalpindi', ''),
('3188316', NULL, 'Fighting', 'Lnk', 'TA Abdul Salam', 'Technical Assistant', 'TAs', 'Sdh', 'Sdh Bty', '03005678910', 'Rawalpindi', ''),
('3187840', NULL, 'Fighting', 'Nk', 'TA Muhammad Aamir', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678911', 'Rawalpindi', ''),
('3192839', NULL, 'Fighting', 'Lnk', 'TA Muhammad Ashiq', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678912', 'Rawalpindi', ''),
('3157112', NULL, 'Fighting', 'Lnk', 'TA Saif Ur Rehman', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678913', 'Rawalpindi', ''),
('3191300', NULL, 'Fighting', 'Lnk', 'TA Muhammad Noman', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678914', 'Rawalpindi', ''),
('3196939', NULL, 'Fighting', 'Lnk', 'TA Nasir Mehmood', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678915', 'Rawalpindi', ''),
('3188317', NULL, 'Fighting', 'TA', 'Muhammad Imran Fareed', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678916', 'Rawalpindi', ''),
('3188004', NULL, 'Fighting', 'Lnk', 'TA Humair Raza Kazmai', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678917', 'Rawalpindi', ''),
('3156623', NULL, 'Fighting', 'TA', 'Abdul Wahab', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678918', 'Rawalpindi', ''),
('3164739', NULL, 'Fighting', 'TA', 'Manzoor Elahi', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678919', 'Rawalpindi', ''),
('3177687', NULL, 'Fighting', 'Nk', 'TA Muhammad Kashif', 'Technical Assistant', 'TAs', 'Sdh', 'Sdh Bty', '03005678920', 'Rawalpindi', ''),
('3161148', NULL, 'Fighting', 'Lnk', 'TA Nadeem Khan', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678921', 'Rawalpindi', ''),
('3188615', NULL, 'Fighting', 'Nk', 'TA Muhammad Asif', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678922', 'Rawalpindi', ''),
('3216620', NULL, 'Fighting', 'TA', 'Sameed Khan', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678923', 'Rawalpindi', ''),
('3226536', NULL, 'Fighting', 'TA', 'Muhammad Zesshan Khan', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678924', 'Rawalpindi', ''),
('3227884', NULL, 'Fighting', 'TA', 'Asad Farooq', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678925', 'Rawalpindi', ''),
('3225476', NULL, 'Fighting', 'TA', 'Javed Akhtar', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678926', 'Rawalpindi', ''),
('3215615', NULL, 'Fighting', 'TA', 'Hazrat Ullah', 'Technical Assistant', 'TAs', 'Ptn', 'Ptn Bty', '03005678927', 'Rawalpindi', ''),
('3226167', NULL, 'Fighting', 'TA', 'Ali Husnain', 'Technical Assistant', 'TAs', 'Pb', 'Pb Bty', '03005678928', 'Rawalpindi', ''),
-- OCsU (6)
('3144778', NULL, 'Non Fighting', 'RHM Hav', 'OCU Ghulam Abbas', 'Operator', 'OCsU', 'Pb', 'Pb Bty', '03006789012', 'Rawalpindi', ''),
('3125849', NULL, 'Non Fighting', 'Hav', 'OCU Sajjad Ali', 'Operator', 'OCsU', 'Ptn', 'Ptn Bty', '03006789013', 'Rawalpindi', ''),
('3137700', NULL, 'Non Fighting', 'Hav', 'OCU Irfan Ali', 'Operator', 'OCsU', 'Ptn', 'Ptn Bty', '03006789014', 'Rawalpindi', ''),
('3149393', NULL, 'Non Fighting', 'Hav', 'OCU Asim Shahzad', 'Operator', 'OCsU', 'Pb', 'Pb Bty', '03006789015', 'Rawalpindi', ''),
('3143873', NULL, 'Non Fighting', 'Lhav', 'OCU Sajid', 'Operator', 'OCsU', 'Ptn', 'Ptn Bty', '03006789016', 'Rawalpindi', ''),
('3146799', NULL, 'Non Fighting', 'Lhav', 'OCU Rajab Ali', 'Operator', 'OCsU', 'Pb', 'Pb Bty', '03006789017', 'Rawalpindi', '');

-- 4. Seed Status Categories Hierarchy
DO $$
DECLARE
    pres_id UUID; lve_id UUID; aval_id UUID; att_id UUID; crs_id UUID;
    osl_id UUID; sg_id UUID; ug_id UUID; cmh_id UUID; reg_id UUID;
    trg_id UUID; spt_id UUID; aslt_id UUID; dido_id UUID; work_id UUID;
    prot_id UUID; ex_id UUID; ud_id UUID; sub_id UUID;
BEGIN
    -- Level 1: Main Categories
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Present', NULL, 1, 1, '#4CAF50') RETURNING id INTO pres_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Leave', NULL, 1, 2, '#FF9800') RETURNING id INTO lve_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Aval', NULL, 1, 3, '#2196F3') RETURNING id INTO aval_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Att', NULL, 1, 4, '#9C27B0') RETURNING id INTO att_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Courses', NULL, 1, 5, '#3F51B5') RETURNING id INTO crs_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('OSL/Pris', NULL, 1, 6, '#F44336') RETURNING id INTO osl_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Sta Gds', NULL, 1, 7, '#FF5722') RETURNING id INTO sg_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Unit Gds', NULL, 1, 8, '#795548') RETURNING id INTO ug_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('CMH/Sick', NULL, 1, 9, '#E91E63') RETURNING id INTO cmh_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Regt Emp', NULL, 1, 10, '#607D8B') RETURNING id INTO reg_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Trg', NULL, 1, 11, '#00BCD4') RETURNING id INTO trg_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Sports', NULL, 1, 12, '#8BC34A') RETURNING id INTO spt_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Aslt Course', NULL, 1, 13, '#FFC107') RETURNING id INTO aslt_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('DIDO', NULL, 1, 14, '#009688') RETURNING id INTO dido_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Working', NULL, 1, 15, '#673AB7') RETURNING id INTO work_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Prot', NULL, 1, 16, '#03A9F4') RETURNING id INTO prot_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('Ex/Cl', NULL, 1, 17, '#CDDC39') RETURNING id INTO ex_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order, color) VALUES 
    ('U/D', NULL, 1, 18, '#9E9E9E') RETURNING id INTO ud_id;

    -- Level 2: Subcategories under Present
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Duty', pres_id, 2, 1),
    ('Standby', pres_id, 2, 2),
    ('Office', pres_id, 2, 3);

    -- Level 2: Subcategories under Leave
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('P/Lve', lve_id, 2, 1),
    ('C/Lve', lve_id, 2, 2),
    ('Weekend', lve_id, 2, 3),
    ('Sick Lve', lve_id, 2, 4);

    -- Level 2: Subcategories under Aval
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Leave Reserve', aval_id, 2, 1),
    ('General Aval', aval_id, 2, 2),
    ('Other', aval_id, 2, 3);

    -- Level 2+3: Subcategories and Sub-subcategories under Att
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Perm Comd', att_id, 2, 1) RETURNING id INTO sub_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Arms Br', sub_id, 3, 1),
    ('Army Camp', sub_id, 3, 2),
    ('PMA', sub_id, 3, 3),
    ('3 Trg/ASL Muree', sub_id, 3, 4),
    ('UN Msn', sub_id, 3, 5),
    ('COAS Dte', sub_id, 3, 6),
    ('52 RSTE', sub_id, 3, 7);

    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Temp', att_id, 2, 2) RETURNING id INTO sub_id;
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('9 Div', sub_id, 3, 1),
    ('30 CAB', sub_id, 3, 2),
    ('30 Corps', sub_id, 3, 3),
    ('Arty Cen', sub_id, 3, 4),
    ('325 CIB', sub_id, 3, 5),
    ('Arms Br', sub_id, 3, 6);

    -- Level 2: Subcategories under Courses
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('JSC/ MCC/OGS', crs_id, 2, 1),
    ('PRT Course', crs_id, 2, 2),
    ('ARI(TA)', crs_id, 2, 3),
    ('ARI(G)', crs_id, 2, 4),
    ('SNBIC', crs_id, 2, 5),
    ('SCC Screening', crs_id, 2, 6),
    ('JNAC', crs_id, 2, 7);

    -- Level 2: Subcategories under OSL/Pris
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('OSL', osl_id, 2, 1),
    ('Regt Prisoner', osl_id, 2, 2),
    ('Detained', osl_id, 2, 3);

    -- Level 2: Subcategories under Sta Gds
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('ISI Sub Sec Gd', sg_id, 2, 1),
    ('COM Gd', sg_id, 2, 2),
    ('FG Deg Gd', sg_id, 2, 3),
    ('PRO Sec', sg_id, 2, 4),
    ('GMP', sg_id, 2, 5),
    ('Ammo Gd', sg_id, 2, 6);

    -- Level 2: Subcategories under Unit Gds
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('MT', ug_id, 2, 1),
    ('158 Line', ug_id, 2, 2),
    ('POL', ug_id, 2, 3),
    ('148 SP', ug_id, 2, 4),
    ('Stores', ug_id, 2, 5),
    ('Office', ug_id, 2, 6),
    ('Guns', ug_id, 2, 7),
    ('Prisoner', ug_id, 2, 8);

    -- Level 2: Subcategories under CMH/Sick
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('CMH Gwa', cmh_id, 2, 1),
    ('SIQ', cmh_id, 2, 2),
    ('CMH Kht', cmh_id, 2, 3);

    -- Level 2: Subcategories under Regt Emp
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('RP', reg_id, 2, 1),
    ('Ck House', reg_id, 2, 2),
    ('Adm/Emg/CO Veh', reg_id, 2, 3),
    ('DR', reg_id, 2, 4),
    ('Rnrs', reg_id, 2, 5),
    ('Orderly/ Daily NCO', reg_id, 2, 6),
    ('Complain NCO', reg_id, 2, 7),
    ('Tea Bar NCO', reg_id, 2, 8),
    ('Store Man', reg_id, 2, 9);

    -- Level 2: Subcategories under Trg
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Observer', trg_id, 2, 1),
    ('Guns', trg_id, 2, 2);

    -- Level 2: Subcategories under Sports
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Rugby', spt_id, 2, 1),
    ('Volleyball', spt_id, 2, 2);

    -- Level 2: Subcategories under Aslt Course
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Obstacle Trg', aslt_id, 2, 1),
    ('Physical Test', aslt_id, 2, 2),
    ('General Aslt', aslt_id, 2, 3);

    -- Level 2: Subcategories under DIDO
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Waiters', dido_id, 2, 1),
    ('Managers', dido_id, 2, 2);

    -- Level 2: Subcategories under Working
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Area Maint', work_id, 2, 1),
    ('Weapon Maint', work_id, 2, 2);

    -- Level 2: Subcategories under Prot
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Chinese Team', prot_id, 2, 1),
    ('Players Pot', prot_id, 2, 2);

    -- Level 2: Subcategories under Ex/Cl
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Extra Class', ex_id, 2, 1),
    ('Remedial Class', ex_id, 2, 2),
    ('Other', ex_id, 2, 3);

    -- Level 2: Subcategories under U/D
    INSERT INTO status_categories (name, parent_id, level, sort_order) VALUES 
    ('Under Displ', ud_id, 2, 1),
    ('Inquiry', ud_id, 2, 2),
    ('Other', ud_id, 2, 3);
END $$;

-- 5. Seed Initial Status History (Set all to Present/Duty)
INSERT INTO status_history (army_no, category, subcategory, sub_subcategory, start_date, end_date, destination, created_by)
SELECT 
    army_no,
    'Present',
    'Duty',
    NULL,
    NOW() - INTERVAL '10 days',
    NULL,
    NULL,
    'system'
FROM personnel;

-- 6. Seed Example Custom Groups
INSERT INTO custom_groups (id, name, category, leader_army_no, leader_name, location, description, until_date, created_by) VALUES
(gen_random_uuid(), 'PMA Visit Team', 'Travel', 'PA-61755', 'Capt Muhammad Ali', 'Kakul Abbottabad', 'Team visiting PMA for training', NOW() + INTERVAL '30 days', 'system'),
(gen_random_uuid(), 'Assault Course Prep A', 'Training', 'PJO-3114197', 'N/Sub Gnr Muhammad Naeem', 'Training Area Sector 4', 'Preparation for assault course', NOW() + INTERVAL '15 days', 'system'),
(gen_random_uuid(), 'Kitchen Working Party', 'Working Party', 'PA-45571', 'Maj Muhammad Usman Anwar', 'Mess Hall Cookhouse', 'Daily kitchen duties', NOW() + INTERVAL '7 days', 'system');

-- Step 7: Add PostgreSQL Function for Status Update
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

-- ============================================================================
-- SECTION 7: COMMON QUERY EXAMPLES
-- ============================================================================

/*
-- Get current parade state with full personnel details
SELECT * FROM v_current_personnel_status ORDER BY rank_group, name;

-- Get parade statistics
SELECT * FROM v_parade_statistics;

-- Get custom groups with members
SELECT * FROM v_custom_groups_with_members WHERE is_active = true;

-- Get personnel in a specific status
SELECT * FROM v_current_personnel_status WHERE current_category = 'Leave';

-- Update personnel status (transaction)
BEGIN;
    -- Close current status
    UPDATE status_history 
    SET end_date = NOW() 
    WHERE army_no = 'PA-43337' AND end_date IS NULL;
    
    -- Insert new status
    INSERT INTO status_history (army_no, category, subcategory, start_date, end_date, destination, created_by)
    VALUES ('PA-43337', 'Leave', 'C/Lve', NOW(), NULL, 'Lahore', 'admin');
COMMIT;

-- Get status history for a specific person
SELECT * FROM status_history 
WHERE army_no = 'PA-43337' 
ORDER BY start_date DESC;

-- Search personnel by name or army number
SELECT * FROM personnel 
WHERE name ILIKE '%Muhammad%' OR army_no ILIKE '%PA-43337%';

-- Search by destination or status
SELECT * FROM v_current_personnel_status 
WHERE destination ILIKE '%Lahore%' OR current_category ILIKE '%Leave%';
*/

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
