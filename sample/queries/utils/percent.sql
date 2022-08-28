CREATE OR REPLACE FUNCTION PERCENT(numerator anycompatible, denominator anycompatible)
RETURNS numeric LANGUAGE plpgsql AS $$
BEGIN
    RETURN ROUND(numerator::numeric / denominator::numeric * 100, 2);
END $$;
