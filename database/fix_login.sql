-- ============================================
-- SQL SCRIPT TO FIX LOGIN FUNCTIONALITY
-- Run this in your Supabase SQL Editor!
-- ============================================

-- 1. Enable the pgcrypto extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Ensure password hashing trigger function is robust and prevents double-hashing
CREATE OR REPLACE FUNCTION hash_command_slot_password()
RETURNS TRIGGER AS $$
BEGIN
    -- Only hash if the password is new/changed AND not already hashed with bcrypt
    IF (TG_OP = 'INSERT' OR NEW.password_hash IS DISTINCT FROM OLD.password_hash) 
       AND NEW.password_hash NOT LIKE '$2a$%' 
       AND NEW.password_hash NOT LIKE '$2b$%' THEN
        NEW.password_hash := crypt(NEW.password_hash, gen_salt('bf', 6));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-create the trigger on command_slots
DROP TRIGGER IF EXISTS trigger_hash_command_slot_password ON command_slots;
CREATE TRIGGER trigger_hash_command_slot_password
BEFORE INSERT OR UPDATE ON command_slots
FOR EACH ROW
EXECUTE FUNCTION hash_command_slot_password();

-- 4. Re-create the verify_password RPC function to correctly verify bcrypt hashes
CREATE OR REPLACE FUNCTION verify_password(p_username text, p_password text)
RETURNS jsonb AS $$
DECLARE
    v_slot_id int;
    v_role text;
    v_army_no text;
    v_password_hash text;
    v_is_active boolean;
BEGIN
    -- Select matching command slot details (case-insensitive username check)
    SELECT slot_id, role, army_no, password_hash, is_active
    INTO v_slot_id, v_role, v_army_no, v_password_hash, v_is_active
    FROM command_slots
    WHERE LOWER(username) = LOWER(p_username);

    -- If username not found
    IF v_slot_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;

    -- If account is deactivated
    IF NOT COALESCE(v_is_active, true) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;

    -- Verify password (checks bcrypt hash, with a fallback for plaintext)
    IF (v_password_hash = p_password) OR 
       ((v_password_hash LIKE '$2a$%' OR v_password_hash LIKE '$2b$%') AND v_password_hash = crypt(p_password, v_password_hash)) THEN
        
        -- Update last login timestamp
        UPDATE command_slots
        SET last_login = NOW()
        WHERE slot_id = v_slot_id;

        RETURN jsonb_build_object(
            'success', true,
            'role', v_role,
            'army_no', v_army_no,
            'slot_id', v_slot_id
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database verification error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
