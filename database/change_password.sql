-- ============================================
-- CHANGE PASSWORD FUNCTION
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

    -- Get user details
    SELECT slot_id, password_hash, is_active
    INTO v_slot_id, v_password_hash, v_is_active
    FROM command_slots
    WHERE LOWER(username) = LOWER(p_username);

    -- Check if user exists
    IF v_slot_id IS NULL THEN
        RAISE NOTICE 'Username not found: %', p_username;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid username or password.'
        );
    END IF;

    -- Check if account is active
    IF NOT COALESCE(v_is_active, true) THEN
        RAISE NOTICE 'Account is deactivated';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Account is deactivated.'
        );
    END IF;

    -- Verify old password
    IF NOT ((v_password_hash = p_old_password) OR 
            ((v_password_hash LIKE '$2a$%' OR v_password_hash LIKE '$2b$%') AND v_password_hash = crypt(p_old_password, v_password_hash))) THEN
        RAISE NOTICE 'Old password verification failed';
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Incorrect old password.'
        );
    END IF;

    -- Update password (the trigger will hash it automatically)
    UPDATE command_slots
    SET password_hash = p_new_password,
        updated_at = NOW()
    WHERE slot_id = v_slot_id;

    RAISE NOTICE 'Password changed successfully for user: %', p_username;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Password changed successfully!'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in change_password: %', SQLERRM;
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database error: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
