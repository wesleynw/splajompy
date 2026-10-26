CREATE FUNCTION notify_unread_notification_count_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NOT NEW.viewed THEN
            PERFORM pg_notify('notification_unread_count_changed', NEW.user_id::text);
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF NOT OLD.viewed THEN
            PERFORM pg_notify('notification_unread_count_changed', OLD.user_id::text);
        END IF;
    ELSIF OLD.user_id IS DISTINCT FROM NEW.user_id OR OLD.viewed IS DISTINCT FROM NEW.viewed THEN
        IF NOT OLD.viewed THEN
            PERFORM pg_notify('notification_unread_count_changed', OLD.user_id::text);
        END IF;
        IF NOT NEW.viewed THEN
            PERFORM pg_notify('notification_unread_count_changed', NEW.user_id::text);
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER notification_unread_count_changed
AFTER INSERT OR UPDATE OR DELETE ON notifications
FOR EACH ROW EXECUTE FUNCTION notify_unread_notification_count_change();
