-- ============================================
-- STEP 1: (SKIP LISTING FUNCTIONS TO AVOID ERROR)
-- ============================================

-- ============================================
-- STEP 2: DROP ALL EXISTING FUNCTIONS
-- ============================================
DROP FUNCTION IF EXISTS verify_password(character varying, character varying);
DROP FUNCTION IF EXISTS verify_password(text, text);
DROP FUNCTION IF EXISTS verify_password(); -- any other variants
DROP FUNCTION IF EXISTS change_password(character varying, character varying, character varying);
DROP FUNCTION IF EXISTS change_password(text, text, text);
DROP FUNCTION IF EXISTS change_password(); -- any other variants

-- ============================================
-- STEP 3: RECREATE verify_password FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION verify_password(p_username text, p_password text)
RETURNS jsonb AS $$
DECLARE
    v_slot_id int;
    v_role text;
    v_army_no text;
    v_password_hash text;
    v_is_active boolean;
BEGIN
    RAISE NOTICE 'Attempting login for username: %', p_username;

    SELECT slot_id, role, army_no, password_hash, is_active
    INTO v_slot_id, v_role, v_army_no, v_password_hash, v_is_active
    FROM command_slots
    WHERE LOWER(username) = LOWER(p_username);

    IF v_slot_id IS NULL THEN
        RAISE NOTICE 'Username not found: %', p_username;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;

    RAISE NOTICE 'Found user: % (slot_id: %)', p_username, v_slot_id;

    IF NOT COALESCE(v_is_active, true) THEN
        RAISE NOTICE 'Account is deactivated';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;

    IF (v_password_hash = p_password) OR 
       ((v_password_hash LIKE '$2a$%' OR v_password_hash LIKE '$2b$%') AND v_password_hash = crypt(p_password, v_password_hash)) THEN
        RAISE NOTICE 'Password verified successfully';
        UPDATE command_slots SET last_login = NOW() WHERE slot_id = v_slot_id;
        RETURN jsonb_build_object(
            'success', true,
            'role', v_role,
            'army_no', v_army_no,
            'slot_id', v_slot_id
        );
    ELSE
        RAISE NOTICE 'Password verification failed';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in verify_password: %', SQLERRM;
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 4: RECREATE change_password FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION change_password(
    p_username text,
    p_old_password text,
    p_new_password text
)
RETURNS jsonb AS $$
DECLARE
    v_slot_id int;
    v_password_hash text;
    v_is_active boolean;
BEGIN
    RAISE NOTICE 'Attempting password change for username: %', p_username;

    SELECT slot_id, password_hash, is_active
    INTO v_slot_id, v_password_hash, v_is_active
    FROM command_slots
    WHERE LOWER(username) = LOWER(p_username);

    IF v_slot_id IS NULL THEN
        RAISE NOTICE 'Username not found: %', p_username;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;

    IF NOT COALESCE(v_is_active, true) THEN
        RAISE NOTICE 'Account is deactivated';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;

    IF NOT ((v_password_hash = p_old_password) OR 
            ((v_password_hash LIKE '$2a$%' OR v_password_hash LIKE '$2b$%') AND v_password_hash = crypt(p_old_password, v_password_hash))) THEN
        RAISE NOTICE 'Old password verification failed';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Incorrect old password'
        );
    END IF;

    UPDATE command_slots
    SET password_hash = p_new_password, updated_at = NOW()
    WHERE slot_id = v_slot_id;

    RAISE NOTICE 'Password changed successfully for user: %', p_username;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Password changed successfully'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in change_password: %', SQLERRM;
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: TEST verify_password
-- ============================================
SELECT verify_password('Frukh', 'frukh123');

-- ============================================
-- STEP 6: TEST change_password (optional, uncomment to test)
-- ============================================
-- SELECT change_password('Frukh', 'frukh123', 'newpassword123');
