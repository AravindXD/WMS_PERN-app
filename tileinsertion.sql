CREATE OR REPLACE FUNCTION populate_tiles(wh_id INTEGER) RETURNS VOID AS $$
DECLARE
  rack_rec RECORD;  -- Cursor record type matching the rack table
  rack_id INTEGER;
  row_count INTEGER;
  col_count INTEGER;
  i INTEGER;
  j INTEGER;
  x_offset NUMERIC := 0.0;
  y_offset NUMERIC := 0.0;
  z_offset NUMERIC := 0.0;
  tile_area NUMERIC;
  aruco_id VARCHAR(255);
BEGIN

  -- Open a cursor to iterate through racks in the specified warehouse
  FOR rack_rec IN SELECT * FROM public.rack WHERE warehouse_id = wh_id LOOP

    rack_id := rack_rec.rack_id;  -- Access column value from the record

    -- Get random row and column count for the current rack (adjust ranges as needed)
    row_count := FLOOR(RANDOM() * (5 - 2 + 1)) + 2;
    col_count := FLOOR(RANDOM() * (5 - 2 + 1)) + 2;

    -- Loop through each tile in the rack
    FOR i IN 1..row_count LOOP
      FOR j IN 1..col_count LOOP

        -- Calculate tile area based on pre-defined base dimensions (adjust as needed)
        tile_area := 1.0 * 0.5;  -- Replace with your base length and breadth

        -- Generate a unique ARUco ID (modify as needed)
        aruco_id := CONCAT('RACK-', rack_id, '-ROW', i, '-COL', j);

        -- Calculate x, y, and z coordinates based on offsets and tile dimensions
        x_offset := x_offset + (j - 1) * 1.0;  -- Replace with your base length
        y_offset := y_offset + (i - 1) * 0.5;  -- Replace with your base breadth
        z_offset := z_offset + 0.1;  -- Adjust z-offset for stacking

        -- Insert tile data
        INSERT INTO public.tile (rack_id, row_number, column_number, dynamic_surface_area, aruco_id, x_coordinate, y_coordinate, z_coordinate)
        VALUES (rack_id, i, j, tile_area, aruco_id, x_offset, y_offset, z_offset);
      END LOOP;
    END LOOP;
  END LOOP;

END;
$$ LANGUAGE plpgsql;

-- Call the function for each warehouse ID
SELECT populate_tiles(warehouse_id) FROM public.warehouse;
