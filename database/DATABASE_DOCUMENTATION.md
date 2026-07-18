# 117 SP Regiment Parade Management System - Database Documentation

## Overview
This is a comprehensive, professional relational database schema designed for the 117 SP Regiment Parade Management System. It supports all core features including personnel management, status tracking, custom groups, and audit logging.

## Database Schema Diagram

```mermaid
erDiagram
    PERSONNEL ||--o{ STATUS_HISTORY : has
    PERSONNEL ||--o{ COMMAND_SLOTS : occupies
    PERSONNEL ||--o{ CUSTOM_GROUPS : leads
    PERSONNEL ||--o{ GROUP_MEMBERS : belongs_to
    CUSTOM_GROUPS ||--o{ GROUP_MEMBERS : contains
    STATUS_CATEGORIES ||--o{ STATUS_CATEGORIES : parent_of
    SYSTEM_ATTRIBUTES ||--o{ PERSONNEL : configures
    AUDIT_LOGS ||--o{ ALL_TABLES : tracks
    
    PERSONNEL {
        varchar army_no PK
        text profile_photo
        varchar fighting_status
        varchar rank
        varchar name
        varchar trade
        varchar category
        varchar cl
        varchar battery
        varchar phone_number
        varchar city
        text remarks
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    
    STATUS_CATEGORIES {
        uuid id PK
        varchar name
        uuid parent_id FK
        integer level
        integer sort_order
        varchar color
        varchar icon
        timestamptz created_at
        timestamptz updated_at
    }
    
    STATUS_HISTORY {
        uuid id PK
        varchar army_no FK
        varchar category
        varchar subcategory
        varchar sub_subcategory
        timestamptz start_date
        timestamptz end_date
        varchar destination
        text remarks
        varchar created_by
        varchar updated_by
        timestamptz created_at
        timestamptz updated_at
    }
    
    CUSTOM_GROUPS {
        uuid id PK
        varchar name
        varchar category
        varchar leader_army_no FK
        varchar leader_name
        varchar location
        text description
        timestamptz until_date
        boolean is_active
        varchar created_by
        varchar updated_by
        timestamptz created_at
        timestamptz updated_at
    }
    
    GROUP_MEMBERS {
        uuid group_id PK FK
        varchar army_no PK FK
        varchar added_by
        timestamptz created_at
    }
    
    COMMAND_SLOTS {
        integer slot_id PK
        varchar role
        varchar army_no FK
        varchar username
        varchar password_hash
        boolean is_active
        timestamptz last_login
        timestamptz created_at
        timestamptz updated_at
    }
    
    SYSTEM_ATTRIBUTES {
        varchar attribute_type PK
        jsonb items
        varchar updated_by
        timestamptz updated_at
    }
    
    AUDIT_LOGS {
        uuid id PK
        varchar table_name
        varchar record_id
        varchar action
        jsonb old_data
        jsonb new_data
        varchar changed_by
        timestamptz changed_at
        varchar ip_address
        text user_agent
    }
```

## Table Details

### 1. `personnel` - Nominal Roll
Stores all personnel information.

| Column | Type | Description |
|--------|------|-------------|
| `army_no` | VARCHAR(50) | Primary Key - Unique army number |
| `profile_photo` | TEXT | Profile photo URL or base64 |
| `fighting_status` | VARCHAR(20) | Fighting status (Fighting/Non Fighting) |
| `rank` | VARCHAR(50) | Personnel rank |
| `name` | VARCHAR(150) | Full name |
| `trade` | VARCHAR(100) | Trade/Specialization |
| `category` | VARCHAR(50) | Category (Officers, JCOs, Clks, Svys, TAs, OCsU) |
| `cl` | VARCHAR(50) | Class/Group (Pb, Sdh, Ptn) |
| `battery` | VARCHAR(100) | Battery/Company |
| `phone_number` | VARCHAR(20) | Phone number |
| `city` | VARCHAR(100) | City |
| `remarks` | TEXT | Additional remarks/observations |
| `is_active` | BOOLEAN | Soft delete flag (default: true) |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Indexes:**
- `idx_personnel_category`
- `idx_personnel_rank`
- `idx_personnel_is_active`

---

### 2. `status_categories` - Hierarchical Status Categories
Stores the hierarchical tree of status categories (3 levels deep).

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary Key |
| `name` | VARCHAR(100) | Category name |
| `parent_id` | UUID | Parent category (NULL for level 1) |
| `level` | INTEGER | Level (1=Category, 2=Subcategory, 3=Sub-subcategory) |
| `sort_order` | INTEGER | Display order |
| `color` | VARCHAR(7) | UI color (hex) |
| `icon` | VARCHAR(50) | UI icon name |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Indexes:**
- `idx_status_categories_parent_id`
- `idx_status_categories_level`
- `unique_name_per_parent` (unique constraint)

---

### 3. `status_history` - Personnel Status History
Tracks all status changes for each person (current and historical).

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary Key |
| `army_no` | VARCHAR(50) | Foreign Key to `personnel` |
| `category` | VARCHAR(100) | Main status category |
| `subcategory` | VARCHAR(100) | Subcategory (optional) |
| `sub_subcategory` | VARCHAR(100) | Sub-subcategory (optional) |
| `start_date` | TIMESTAMPTZ | Status start date |
| `end_date` | TIMESTAMPTZ | Status end date (NULL = active) |
| `destination` | VARCHAR(255) | Location/destination |
| `remarks` | TEXT | Additional remarks |
| `created_by` | VARCHAR(100) | User who created |
| `updated_by` | VARCHAR(100) | User who updated |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Indexes:**
- `idx_status_history_army_no`
- `idx_status_history_active` (filtered index for active statuses)
- `idx_status_history_start_date`
- `unique_active_status_per_person` (unique constraint for one active status per person)

---

### 4. `custom_groups` - Custom Personnel Groups
Stores dynamic groups of personnel.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary Key |
| `name` | VARCHAR(150) | Group name |
| `category` | VARCHAR(100) | Group category (Training, Travel, etc.) |
| `leader_army_no` | VARCHAR(50) | Foreign Key to `personnel` (group leader) |
| `leader_name` | VARCHAR(150) | Leader's name |
| `location` | VARCHAR(255) | Group location |
| `description` | TEXT | Group description |
| `until_date` | TIMESTAMPTZ | Group validity end date |
| `is_active` | BOOLEAN | Active flag (default: true) |
| `created_by` | VARCHAR(100) | User who created |
| `updated_by` | VARCHAR(100) | User who updated |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Indexes:**
- `idx_custom_groups_leader`
- `idx_custom_groups_is_active`
- `idx_custom_groups_until_date`

---

### 5. `group_members` - Group Members Junction Table
Many-to-many relationship between `custom_groups` and `personnel`.

| Column | Type | Description |
|--------|------|-------------|
| `group_id` | UUID | Primary Key - Foreign Key to `custom_groups` |
| `army_no` | VARCHAR(50) | Primary Key - Foreign Key to `personnel` |
| `added_by` | VARCHAR(100) | User who added |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

**Indexes:**
- `idx_group_members_army_no`
- `idx_group_members_group_id`

---

### 6. `command_slots` - User Authentication & Access Control
Stores user accounts with role-based access.

| Column | Type | Description |
|--------|------|-------------|
| `slot_id` | INTEGER | Primary Key - Slot number |
| `role` | VARCHAR(50) | User role (superadmin, admin, user, viewer) |
| `army_no` | VARCHAR(50) | Foreign Key to `personnel` (optional) |
| `username` | VARCHAR(100) | Unique username |
| `password_hash` | VARCHAR(255) | Hashed password (never store plain text!) |
| `is_active` | BOOLEAN | Active flag (default: true) |
| `last_login` | TIMESTAMPTZ | Last login timestamp |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Indexes:**
- `idx_command_slots_username`
- `idx_command_slots_is_active`

---

### 7. `system_attributes` - System Configurations
Stores system-wide configurations (ranks, trades, batteries, etc.).

| Column | Type | Description |
|--------|------|-------------|
| `attribute_type` | VARCHAR(50) | Primary Key - Type (ranks, trades, batteries, categories, fighting_status) |
| `items` | JSONB | JSON array of items |
| `updated_by` | VARCHAR(100) | User who updated |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

---

### 8. `audit_logs` - Comprehensive Audit Trail
Tracks all changes to the database.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary Key |
| `table_name` | VARCHAR(100) | Table that was changed |
| `record_id` | VARCHAR(100) | ID of the record that was changed |
| `action` | VARCHAR(20) | Action (INSERT, UPDATE, DELETE) |
| `old_data` | JSONB | Data before change |
| `new_data` | JSONB | Data after change |
| `changed_by` | VARCHAR(100) | User who made the change |
| `changed_at` | TIMESTAMPTZ | Timestamp of change |
| `ip_address` | VARCHAR(45) | Client IP address |
| `user_agent` | TEXT | Client user agent |

**Indexes:**
- `idx_audit_logs_table_name`
- `idx_audit_logs_record_id`
- `idx_audit_logs_changed_at`

---

## Helper Views

### `v_current_personnel_status`
Current parade state with all personnel details.

### `v_custom_groups_with_members`
Custom groups with their members as JSON array.

### `v_parade_statistics`
Parade statistics aggregated by category and subcategory.

---

## Security Features

### Row Level Security (RLS)
All tables have RLS enabled with appropriate policies.

### Password Security
- **Never store plain text passwords!**
- Use bcrypt or Argon2 for password hashing
- Default seed passwords are for demo only - change immediately!

### Audit Logging
All changes are tracked in `audit_logs` table with before/after data.

---

## Common Queries

### Get Current Parade State
```sql
SELECT * FROM v_current_personnel_status ORDER BY rank_group, name;
```

### Update Personnel Status (Transaction)
```sql
BEGIN;
    -- Close current status
    UPDATE status_history 
    SET end_date = NOW() 
    WHERE army_no = 'PA-43337' AND end_date IS NULL;
    
    -- Insert new status
    INSERT INTO status_history (army_no, category, subcategory, start_date, end_date, destination, created_by)
    VALUES ('PA-43337', 'Leave', 'C/Lve', NOW(), NULL, 'Lahore', 'admin');
COMMIT;
```

### Get Personnel in Specific Status
```sql
SELECT * FROM v_current_personnel_status WHERE current_category = 'Leave';
```

### Get Status History for a Person
```sql
SELECT * FROM status_history 
WHERE army_no = 'PA-43337' 
ORDER BY start_date DESC;
```

### Search Personnel
```sql
SELECT * FROM personnel 
WHERE name ILIKE '%Muhammad%' OR army_no ILIKE '%PA-43337%';
```

### Get Custom Groups with Members
```sql
SELECT * FROM v_custom_groups_with_members WHERE is_active = true;
```

---

## Seed Data

The schema includes comprehensive seed data:
- Default admin user (username: `admin`, password: `admin123` - CHANGE THIS!)
- Complete nominal roll
- Full status category hierarchy
- Initial status for all personnel (Present/Duty)
- Example custom groups

---

## Deployment Notes

### For Supabase:
1. Create a new Supabase project
2. Go to SQL Editor → New Query
3. Copy and paste `comprehensive_schema.sql`
4. Run the query
5. Configure authentication settings

### Password Hashing:
In production, use proper password hashing:
- **bcrypt** (cost factor 10-12)
- **Argon2id** (recommended)

### Backup Strategy:
- Enable Supabase Point-in-Time Recovery (PITR)
- Take regular backups
- Test restore procedures

---

## Maintenance

### Vacuum/Analyze
```sql
VACUUM ANALYZE;
```

### Check for Long-Running Queries
```sql
SELECT pid, query, state, now() - query_start AS duration
FROM pg_stat_activity
WHERE state = 'active' AND query NOT LIKE '%pg_stat_activity%';
```

---

## Support & Documentation

For questions or issues, refer to:
- Supabase Documentation: https://supabase.com/docs
- PostgreSQL Documentation: https://www.postgresql.org/docs/
