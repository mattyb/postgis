-- $Id$
----------------------------------------------------------------------
-- Copyright (c) 2009-2010 Pierre Racine <pierre.racine@sbf.ulaval.ca>
----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ST_Reclass(rast raster,
				      band int,
                                      reclassexpr text) 
    RETURNS raster AS 
    $$
    DECLARE
	-- Create a new raster without the band we will reclassify
    	newrast raster := ST_DeleteBand(rast, band);

	-- Determine the nodata value
    	nodataval float8 := ST_BandNodataValue(rast, band);

	-- First parse of the reclass expression. Split the reclass classes into an array.
    	reclarray text[] := string_to_array(reclassexpr, '|');

    	-- Determine the number of classes.
    	nbreclassstr int := array_length(reclarray, 1);

    	-- Initialise the MapAlgebra expression
    	maexpr text := 'CASE ';

    	-- Temporary container for the two part of the class being parsed.
    	reclassstr text[];

    	-- Temporary array containing the splited class.
    	fromstr text[];

    	i int;
    BEGIN
	-- For each classes
    	FOR i IN 1..nbreclassstr LOOP
		-- Split the class into an array of classes.
    		reclassstr := string_to_array(reclarray[i], ':');
    		IF array_length(reclassstr, 1) < 2 THEN
			RAISE EXCEPTION 'ST_Reclass: Invalid reclassification class: "%". Aborting', reclarray[i];
    		END IF;
    		-- Split the range to reclassify into two
    		fromstr := string_to_array(reclassstr[1], '-');
    		-- Replace NODATA with the nodata value
    		IF upper(reclassstr[2]) = 'NODATA' THEN
    			reclassstr[2] = nodataval::text;
    		END IF;
    		-- Build the maexpr expression
    		IF fromstr[2] IS NULL OR fromstr[2] = ''  THEN
			maexpr := maexpr || ' WHEN ' || fromstr[1] || ' = rast1 THEN ' || reclassstr[2] || ' ';
		ELSE
			maexpr := maexpr || ' WHEN ' || fromstr[1] || ' <= rast1 AND rast1 < ' || fromstr[2] || ' THEN ' || reclassstr[2] || ' ';
		END IF;
    	END LOOP;
    	maexpr := maexpr || 'ELSE rast1 END';
    	newrast := ST_AddBand(rast, ST_MapAlgebra(rast, band, maexpr), 1, band);
	RETURN newrast;
    END;
    $$
    LANGUAGE 'plpgsql';

SELECT ST_Value(ST_Reclass(ST_TestRaster(1, 1, 4), 1, '1:2|2:2|3-5:10'), 1, 1);

