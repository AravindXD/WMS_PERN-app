--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

-- Started on 2024-06-30 18:02:26 IST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16868)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 17217)
-- Name: map_all_crates_to_tiles(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.map_all_crates_to_tiles() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Delete all rows in the placedin table
    DELETE FROM placedin;

    -- Map all crates to all tiles
    INSERT INTO placedin (crate_id, tile_id)
    SELECT crate_id, tile_id
    FROM crate, tile;

END;
$$;


ALTER FUNCTION public.map_all_crates_to_tiles() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 17218)
-- Name: map_crates_to_tiles_in_order(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.map_crates_to_tiles_in_order() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    crate_id_var INT;
    tile_id_var INT;
    row_num INT := 1;
BEGIN
    DELETE FROM placedin;

    FOR crate_id_var IN SELECT crate_id FROM crate LOOP
        tile_id_var := (row_num - 1) % (SELECT COUNT(*) FROM tile) + 1;
        INSERT INTO placedin (crate_id, tile_id) VALUES (crate_id_var, tile_id_var);
        row_num := row_num + 1;
    END LOOP;
END;
$$;


ALTER FUNCTION public.map_crates_to_tiles_in_order() OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 17215)
-- Name: place_crate_in_tile(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.place_crate_in_tile() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    crate_record RECORD;
    tile_record RECORD;
BEGIN
    FOR crate_record IN SELECT * FROM crate LOOP
        FOR tile_record IN SELECT * FROM tile WHERE dynamic_surface_area >= crate_record.length * crate_record.breadth LOOP
            INSERT INTO placedin (crate_id, tile_id) VALUES (crate_record.crate_id, tile_record.tile_id);
            UPDATE tile SET dynamic_surface_area = dynamic_surface_area - (crate_record.length * crate_record.breadth) WHERE tile_id = tile_record.tile_id;
            EXIT; -- Exit the inner loop after placing the crate in the first suitable tile
        END LOOP;
    END LOOP;
END;
$$;


ALTER FUNCTION public.place_crate_in_tile() OWNER TO postgres;

--
-- TOC entry 235 (class 1255 OID 17184)
-- Name: populate_crates(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.populate_crates(wh_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  rack_rec RECORD;
  current_rack_id INTEGER;
  row_count INTEGER;
  col_count INTEGER;
  tile_rec RECORD;
  current_tile_id INTEGER;
  current_dynamic_surface_area NUMERIC;  -- Rename dynamic_surface_area
  crate_weight NUMERIC;
  crate_length NUMERIC;
  crate_breadth NUMERIC;
  crate_height NUMERIC;
  crate_type VARCHAR(255);
  crate_count INTEGER := 0;

BEGIN

  FOR rack_rec IN SELECT * FROM public.rack WHERE warehouse_id = wh_id LOOP

    current_rack_id := rack_rec.rack_id;

    FOR tile_rec IN SELECT * FROM public.tile WHERE rack_id = current_rack_id
      LOOP

      current_tile_id := tile_rec.tile_id;
      current_dynamic_surface_area := tile_rec.dynamic_surface_area;  -- Assign dynamic_surface_area to current_dynamic_surface_area

      LOOP
        EXIT WHEN crate_count >= 5 OR current_dynamic_surface_area <= 0;  -- Use current_dynamic_surface_area

        SELECT FLOOR(RANDOM() * 100) AS crate_weight,
               FLOOR(RANDOM() * 50) AS crate_length,
               FLOOR(RANDOM() * 30) AS crate_breadth,
               FLOOR(RANDOM() * 20) AS crate_height,
               CASE WHEN RANDOM() < 0.5 THEN 'fragile' ELSE 'non-fragile' END AS crate_type
        INTO crate_weight, crate_length, crate_breadth, crate_height, crate_type;

        IF (crate_length * crate_breadth <= current_dynamic_surface_area) AND (crate_height <= (tile_rec.z_coordinate - 0.1)) THEN
          INSERT INTO public.crate (nfc_id, weight, length, breadth, height, crate_type)
          VALUES (gen_random_uuid(), crate_weight, crate_length, crate_breadth, crate_height, crate_type);

          UPDATE public.tile
          SET dynamic_surface_area = current_dynamic_surface_area - (crate_length * crate_breadth)
          WHERE tile_id = current_tile_id;

          crate_count := crate_count + 1;
        END IF;
      END LOOP;

    END LOOP;

  END LOOP;

END;
$$;


ALTER FUNCTION public.populate_crates(wh_id integer) OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 17176)
-- Name: populate_tiles(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.populate_tiles(wh_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.populate_tiles(wh_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 232 (class 1259 OID 17069)
-- Name: access; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.access (
    admin_id integer NOT NULL,
    warehouse_id integer NOT NULL
);


ALTER TABLE public.access OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16877)
-- Name: admin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.admin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.admin_id_seq OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16986)
-- Name: admin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin (
    admin_id integer DEFAULT nextval('public.admin_id_seq'::regclass) NOT NULL,
    admin_name character varying(255) NOT NULL,
    phone_number character varying(255) NOT NULL
);


ALTER TABLE public.admin OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 16869)
-- Name: city_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.city_id_seq OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16878)
-- Name: city; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.city (
    city_id integer DEFAULT nextval('public.city_id_seq'::regclass) NOT NULL,
    city_name character varying(255) NOT NULL
);


ALTER TABLE public.city OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16875)
-- Name: crate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crate_id_seq OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16960)
-- Name: crate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crate (
    crate_id integer DEFAULT nextval('public.crate_id_seq'::regclass) NOT NULL,
    nfc_id character varying(255) NOT NULL,
    check_in_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expected_departure timestamp without time zone DEFAULT (CURRENT_TIMESTAMP + '3 days'::interval),
    weight numeric,
    length numeric,
    breadth numeric,
    height numeric,
    crate_type character varying(255)
);


ALTER TABLE public.crate OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16876)
-- Name: customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_id_seq OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16980)
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer (
    customer_id integer DEFAULT nextval('public.customer_id_seq'::regclass) NOT NULL,
    customer_name character varying(255) NOT NULL
);


ALTER TABLE public.customer OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17031)
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    crate_id integer NOT NULL,
    customer_id integer NOT NULL,
    price numeric,
    order_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    order_id integer NOT NULL
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 17185)
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_order_id_seq OWNER TO postgres;

--
-- TOC entry 3717 (class 0 OID 0)
-- Dependencies: 234
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- TOC entry 233 (class 1259 OID 17094)
-- Name: placedin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.placedin (
    crate_id integer NOT NULL,
    tile_id integer NOT NULL
);


ALTER TABLE public.placedin OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 16872)
-- Name: rack_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rack_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rack_id_seq OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16906)
-- Name: rack; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rack (
    rack_id integer DEFAULT nextval('public.rack_id_seq'::regclass) NOT NULL,
    warehouse_id integer
);


ALTER TABLE public.rack OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16871)
-- Name: rack_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rack_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rack_type_id_seq OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16874)
-- Name: supplier_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.supplier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.supplier_id_seq OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16873)
-- Name: tile_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tile_id_seq OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16932)
-- Name: tile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tile (
    tile_id integer DEFAULT nextval('public.tile_id_seq'::regclass) NOT NULL,
    rack_id integer,
    row_number integer NOT NULL,
    column_number integer NOT NULL,
    dynamic_surface_area numeric,
    aruco_id character varying(255),
    x_coordinate numeric,
    y_coordinate numeric,
    z_coordinate numeric
);


ALTER TABLE public.tile OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 16870)
-- Name: warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.warehouse_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.warehouse_id_seq OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16884)
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse (
    warehouse_id integer DEFAULT nextval('public.warehouse_id_seq'::regclass) NOT NULL,
    city_id integer,
    warehouse_name character varying(255) NOT NULL
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- TOC entry 3503 (class 2604 OID 17186)
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- TOC entry 3708 (class 0 OID 17069)
-- Dependencies: 232
-- Data for Name: access; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.access (admin_id, warehouse_id) FROM stdin;
1	1
2	2
3	3
\.


--
-- TOC entry 3706 (class 0 OID 16986)
-- Dependencies: 230
-- Data for Name: admin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin (admin_id, admin_name, phone_number) FROM stdin;
1	ARAVIND	9940219332
2	SIDHARTH	1234567890
3	Vignesh	987654321
\.


--
-- TOC entry 3700 (class 0 OID 16878)
-- Dependencies: 224
-- Data for Name: city; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.city (city_id, city_name) FROM stdin;
1	Chennai
2	Delhi
3	Mumbai
\.


--
-- TOC entry 3704 (class 0 OID 16960)
-- Dependencies: 228
-- Data for Name: crate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crate (crate_id, nfc_id, check_in_time, expected_departure, weight, length, breadth, height, crate_type) FROM stdin;
18	45a441f1-5175-4601-b24e-0fe560978dde	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	38	1	1	1	fragile
19	fb7f7955-0500-48a5-ac24-5c831e4fc398	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	43	11	1	1	fragile
20	1d1a9661-d0a2-4eb2-852b-3a2cff15c8c1	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	35	12	1	1	non-fragile
21	2403dbcb-2897-40a1-9931-9f874f7678bc	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	11	32	1	1	fragile
22	628c7c4a-ac53-4299-876e-8e8f0d3ef389	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	87	38	1	1	fragile
23	0c162c68-f083-45c9-92c9-2fdf6fd32895	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	45	1	17	1	fragile
24	2baccdb0-5e39-4d12-be4b-146df89a512c	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	75	1	13	1	fragile
25	09e48259-92b7-412d-8369-96c4d5377ada	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	17	1	24	1	fragile
26	af559c25-fce1-4c46-a3e8-cf2d31b5330a	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	60	1	20	1	non-fragile
27	73204605-ae29-4039-bbd5-8d8fa88efabc	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	1	31	1	1	fragile
28	a1b86a1f-c05c-4aac-906c-8baf828de94b	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	75	22	1	1	fragile
29	efae6772-b1b9-4399-82eb-b5b86449dbb9	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	38	39	1	1	non-fragile
30	200dd15e-6c73-4d67-a6ce-a42f2fd0e0db	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	35	41	1	1	non-fragile
31	14494861-5eb1-4e58-9532-472bb14ce9a3	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	34	44	1	1	fragile
32	7e0eddf5-dc72-4c98-9b5c-01ccbee004c1	2024-04-20 20:34:08.116547	2024-04-23 20:34:08.116547	85	1	21	1	non-fragile
\.


--
-- TOC entry 3705 (class 0 OID 16980)
-- Dependencies: 229
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer (customer_id, customer_name) FROM stdin;
1	VAGEESH
2	NANTHAN
3	ABHINAV
4	NoNNiranjan
\.


--
-- TOC entry 3707 (class 0 OID 17031)
-- Dependencies: 231
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (crate_id, customer_id, price, order_date, order_id) FROM stdin;
18	1	100.0	2024-04-20 22:46:22.816819	1
19	2	120.0	2024-04-20 22:46:22.816819	2
20	3	80.0	2024-04-20 22:46:22.816819	3
21	1	50.0	2024-04-20 22:46:22.816819	4
22	2	150.0	2024-04-20 22:46:22.816819	5
23	3	90.0	2024-04-20 22:46:22.816819	6
24	4	70.0	2024-04-20 22:46:22.816819	7
25	1	30.0	2024-04-20 22:46:22.816819	8
26	2	110.0	2024-04-20 22:46:22.816819	9
27	3	95.0	2024-04-20 22:46:22.816819	10
28	4	65.0	2024-04-20 22:46:22.816819	11
29	1	85.0	2024-04-20 22:46:22.816819	12
30	2	75.0	2024-04-20 22:46:22.816819	13
31	3	60.0	2024-04-20 22:46:22.816819	14
32	4	120.0	2024-04-20 22:46:22.816819	15
\.


--
-- TOC entry 3709 (class 0 OID 17094)
-- Dependencies: 233
-- Data for Name: placedin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.placedin (crate_id, tile_id) FROM stdin;
18	1
19	2
20	3
21	4
22	5
23	6
24	7
25	8
26	9
27	10
28	11
29	12
30	13
31	14
32	15
\.


--
-- TOC entry 3702 (class 0 OID 16906)
-- Dependencies: 226
-- Data for Name: rack; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rack (rack_id, warehouse_id) FROM stdin;
1	1
2	1
3	1
4	2
5	2
6	2
7	3
8	3
9	3
\.


--
-- TOC entry 3703 (class 0 OID 16932)
-- Dependencies: 227
-- Data for Name: tile; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tile (tile_id, rack_id, row_number, column_number, dynamic_surface_area, aruco_id, x_coordinate, y_coordinate, z_coordinate) FROM stdin;
2	1	1	2	0.50	RACK-1-ROW1-COL2	1.0	0.0	0.2
3	1	1	3	0.50	RACK-1-ROW1-COL3	3.0	0.0	0.3
4	1	1	4	0.50	RACK-1-ROW1-COL4	6.0	0.0	0.4
5	1	1	5	0.50	RACK-1-ROW1-COL5	10.0	0.0	0.5
6	1	2	1	0.50	RACK-1-ROW2-COL1	10.0	0.5	0.6
7	1	2	2	0.50	RACK-1-ROW2-COL2	11.0	1.0	0.7
8	1	2	3	0.50	RACK-1-ROW2-COL3	13.0	1.5	0.8
9	1	2	4	0.50	RACK-1-ROW2-COL4	16.0	2.0	0.9
10	1	2	5	0.50	RACK-1-ROW2-COL5	20.0	2.5	1.0
11	1	3	1	0.50	RACK-1-ROW3-COL1	20.0	3.5	1.1
12	1	3	2	0.50	RACK-1-ROW3-COL2	21.0	4.5	1.2
13	1	3	3	0.50	RACK-1-ROW3-COL3	23.0	5.5	1.3
14	1	3	4	0.50	RACK-1-ROW3-COL4	26.0	6.5	1.4
15	1	3	5	0.50	RACK-1-ROW3-COL5	30.0	7.5	1.5
16	1	4	1	0.50	RACK-1-ROW4-COL1	30.0	9.0	1.6
17	1	4	2	0.50	RACK-1-ROW4-COL2	31.0	10.5	1.7
18	1	4	3	0.50	RACK-1-ROW4-COL3	33.0	12.0	1.8
19	1	4	4	0.50	RACK-1-ROW4-COL4	36.0	13.5	1.9
20	1	4	5	0.50	RACK-1-ROW4-COL5	40.0	15.0	2.0
21	1	5	1	0.50	RACK-1-ROW5-COL1	40.0	17.0	2.1
22	1	5	2	0.50	RACK-1-ROW5-COL2	41.0	19.0	2.2
23	1	5	3	0.50	RACK-1-ROW5-COL3	43.0	21.0	2.3
24	1	5	4	0.50	RACK-1-ROW5-COL4	46.0	23.0	2.4
25	1	5	5	0.50	RACK-1-ROW5-COL5	50.0	25.0	2.5
26	2	1	1	0.50	RACK-2-ROW1-COL1	50.0	25.0	2.6
27	2	1	2	0.50	RACK-2-ROW1-COL2	51.0	25.0	2.7
28	2	2	1	0.50	RACK-2-ROW2-COL1	51.0	25.5	2.8
29	2	2	2	0.50	RACK-2-ROW2-COL2	52.0	26.0	2.9
30	2	3	1	0.50	RACK-2-ROW3-COL1	52.0	27.0	3.0
31	2	3	2	0.50	RACK-2-ROW3-COL2	53.0	28.0	3.1
32	3	1	1	0.50	RACK-3-ROW1-COL1	53.0	28.0	3.2
33	3	1	2	0.50	RACK-3-ROW1-COL2	54.0	28.0	3.3
34	3	1	3	0.50	RACK-3-ROW1-COL3	56.0	28.0	3.4
35	3	1	4	0.50	RACK-3-ROW1-COL4	59.0	28.0	3.5
36	3	1	5	0.50	RACK-3-ROW1-COL5	63.0	28.0	3.6
37	3	2	1	0.50	RACK-3-ROW2-COL1	63.0	28.5	3.7
38	3	2	2	0.50	RACK-3-ROW2-COL2	64.0	29.0	3.8
39	3	2	3	0.50	RACK-3-ROW2-COL3	66.0	29.5	3.9
40	3	2	4	0.50	RACK-3-ROW2-COL4	69.0	30.0	4.0
41	3	2	5	0.50	RACK-3-ROW2-COL5	73.0	30.5	4.1
42	3	3	1	0.50	RACK-3-ROW3-COL1	73.0	31.5	4.2
43	3	3	2	0.50	RACK-3-ROW3-COL2	74.0	32.5	4.3
44	3	3	3	0.50	RACK-3-ROW3-COL3	76.0	33.5	4.4
45	3	3	4	0.50	RACK-3-ROW3-COL4	79.0	34.5	4.5
46	3	3	5	0.50	RACK-3-ROW3-COL5	83.0	35.5	4.6
48	4	1	2	0.50	RACK-4-ROW1-COL2	1.0	0.0	0.2
49	4	1	3	0.50	RACK-4-ROW1-COL3	3.0	0.0	0.3
50	4	2	1	0.50	RACK-4-ROW2-COL1	3.0	0.5	0.4
51	4	2	2	0.50	RACK-4-ROW2-COL2	4.0	1.0	0.5
52	4	2	3	0.50	RACK-4-ROW2-COL3	6.0	1.5	0.6
53	4	3	1	0.50	RACK-4-ROW3-COL1	6.0	2.5	0.7
54	4	3	2	0.50	RACK-4-ROW3-COL2	7.0	3.5	0.8
55	4	3	3	0.50	RACK-4-ROW3-COL3	9.0	4.5	0.9
56	4	4	1	0.50	RACK-4-ROW4-COL1	9.0	6.0	1.0
57	4	4	2	0.50	RACK-4-ROW4-COL2	10.0	7.5	1.1
58	4	4	3	0.50	RACK-4-ROW4-COL3	12.0	9.0	1.2
59	4	5	1	0.50	RACK-4-ROW5-COL1	12.0	11.0	1.3
60	4	5	2	0.50	RACK-4-ROW5-COL2	13.0	13.0	1.4
61	4	5	3	0.50	RACK-4-ROW5-COL3	15.0	15.0	1.5
62	5	1	1	0.50	RACK-5-ROW1-COL1	15.0	15.0	1.6
63	5	1	2	0.50	RACK-5-ROW1-COL2	16.0	15.0	1.7
64	5	1	3	0.50	RACK-5-ROW1-COL3	18.0	15.0	1.8
65	5	2	1	0.50	RACK-5-ROW2-COL1	18.0	15.5	1.9
66	5	2	2	0.50	RACK-5-ROW2-COL2	19.0	16.0	2.0
67	5	2	3	0.50	RACK-5-ROW2-COL3	21.0	16.5	2.1
68	5	3	1	0.50	RACK-5-ROW3-COL1	21.0	17.5	2.2
69	5	3	2	0.50	RACK-5-ROW3-COL2	22.0	18.5	2.3
70	5	3	3	0.50	RACK-5-ROW3-COL3	24.0	19.5	2.4
71	5	4	1	0.50	RACK-5-ROW4-COL1	24.0	21.0	2.5
72	5	4	2	0.50	RACK-5-ROW4-COL2	25.0	22.5	2.6
73	5	4	3	0.50	RACK-5-ROW4-COL3	27.0	24.0	2.7
74	6	1	1	0.50	RACK-6-ROW1-COL1	27.0	24.0	2.8
75	6	1	2	0.50	RACK-6-ROW1-COL2	28.0	24.0	2.9
76	6	1	3	0.50	RACK-6-ROW1-COL3	30.0	24.0	3.0
77	6	1	4	0.50	RACK-6-ROW1-COL4	33.0	24.0	3.1
78	6	1	5	0.50	RACK-6-ROW1-COL5	37.0	24.0	3.2
79	6	2	1	0.50	RACK-6-ROW2-COL1	37.0	24.5	3.3
80	6	2	2	0.50	RACK-6-ROW2-COL2	38.0	25.0	3.4
81	6	2	3	0.50	RACK-6-ROW2-COL3	40.0	25.5	3.5
82	6	2	4	0.50	RACK-6-ROW2-COL4	43.0	26.0	3.6
83	6	2	5	0.50	RACK-6-ROW2-COL5	47.0	26.5	3.7
84	6	3	1	0.50	RACK-6-ROW3-COL1	47.0	27.5	3.8
85	6	3	2	0.50	RACK-6-ROW3-COL2	48.0	28.5	3.9
86	6	3	3	0.50	RACK-6-ROW3-COL3	50.0	29.5	4.0
87	6	3	4	0.50	RACK-6-ROW3-COL4	53.0	30.5	4.1
88	6	3	5	0.50	RACK-6-ROW3-COL5	57.0	31.5	4.2
89	6	4	1	0.50	RACK-6-ROW4-COL1	57.0	33.0	4.3
90	6	4	2	0.50	RACK-6-ROW4-COL2	58.0	34.5	4.4
91	6	4	3	0.50	RACK-6-ROW4-COL3	60.0	36.0	4.5
92	6	4	4	0.50	RACK-6-ROW4-COL4	63.0	37.5	4.6
93	6	4	5	0.50	RACK-6-ROW4-COL5	67.0	39.0	4.7
95	7	1	2	0.50	RACK-7-ROW1-COL2	1.0	0.0	0.2
96	7	1	3	0.50	RACK-7-ROW1-COL3	3.0	0.0	0.3
97	7	1	4	0.50	RACK-7-ROW1-COL4	6.0	0.0	0.4
98	7	1	5	0.50	RACK-7-ROW1-COL5	10.0	0.0	0.5
99	7	2	1	0.50	RACK-7-ROW2-COL1	10.0	0.5	0.6
100	7	2	2	0.50	RACK-7-ROW2-COL2	11.0	1.0	0.7
101	7	2	3	0.50	RACK-7-ROW2-COL3	13.0	1.5	0.8
102	7	2	4	0.50	RACK-7-ROW2-COL4	16.0	2.0	0.9
103	7	2	5	0.50	RACK-7-ROW2-COL5	20.0	2.5	1.0
104	7	3	1	0.50	RACK-7-ROW3-COL1	20.0	3.5	1.1
105	7	3	2	0.50	RACK-7-ROW3-COL2	21.0	4.5	1.2
106	7	3	3	0.50	RACK-7-ROW3-COL3	23.0	5.5	1.3
107	7	3	4	0.50	RACK-7-ROW3-COL4	26.0	6.5	1.4
108	7	3	5	0.50	RACK-7-ROW3-COL5	30.0	7.5	1.5
109	7	4	1	0.50	RACK-7-ROW4-COL1	30.0	9.0	1.6
110	7	4	2	0.50	RACK-7-ROW4-COL2	31.0	10.5	1.7
111	7	4	3	0.50	RACK-7-ROW4-COL3	33.0	12.0	1.8
112	7	4	4	0.50	RACK-7-ROW4-COL4	36.0	13.5	1.9
113	7	4	5	0.50	RACK-7-ROW4-COL5	40.0	15.0	2.0
114	7	5	1	0.50	RACK-7-ROW5-COL1	40.0	17.0	2.1
115	7	5	2	0.50	RACK-7-ROW5-COL2	41.0	19.0	2.2
116	7	5	3	0.50	RACK-7-ROW5-COL3	43.0	21.0	2.3
117	7	5	4	0.50	RACK-7-ROW5-COL4	46.0	23.0	2.4
118	7	5	5	0.50	RACK-7-ROW5-COL5	50.0	25.0	2.5
119	8	1	1	0.50	RACK-8-ROW1-COL1	50.0	25.0	2.6
120	8	1	2	0.50	RACK-8-ROW1-COL2	51.0	25.0	2.7
121	8	1	3	0.50	RACK-8-ROW1-COL3	53.0	25.0	2.8
122	8	1	4	0.50	RACK-8-ROW1-COL4	56.0	25.0	2.9
123	8	2	1	0.50	RACK-8-ROW2-COL1	56.0	25.5	3.0
124	8	2	2	0.50	RACK-8-ROW2-COL2	57.0	26.0	3.1
125	8	2	3	0.50	RACK-8-ROW2-COL3	59.0	26.5	3.2
126	8	2	4	0.50	RACK-8-ROW2-COL4	62.0	27.0	3.3
127	8	3	1	0.50	RACK-8-ROW3-COL1	62.0	28.0	3.4
128	8	3	2	0.50	RACK-8-ROW3-COL2	63.0	29.0	3.5
129	8	3	3	0.50	RACK-8-ROW3-COL3	65.0	30.0	3.6
130	8	3	4	0.50	RACK-8-ROW3-COL4	68.0	31.0	3.7
131	8	4	1	0.50	RACK-8-ROW4-COL1	68.0	32.5	3.8
132	8	4	2	0.50	RACK-8-ROW4-COL2	69.0	34.0	3.9
133	8	4	3	0.50	RACK-8-ROW4-COL3	71.0	35.5	4.0
134	8	4	4	0.50	RACK-8-ROW4-COL4	74.0	37.0	4.1
135	9	1	1	0.50	RACK-9-ROW1-COL1	74.0	37.0	4.2
136	9	1	2	0.50	RACK-9-ROW1-COL2	75.0	37.0	4.3
137	9	2	1	0.50	RACK-9-ROW2-COL1	75.0	37.5	4.4
138	9	2	2	0.50	RACK-9-ROW2-COL2	76.0	38.0	4.5
139	9	3	1	0.50	RACK-9-ROW3-COL1	76.0	39.0	4.6
140	9	3	2	0.50	RACK-9-ROW3-COL2	77.0	40.0	4.7
141	9	4	1	0.50	RACK-9-ROW4-COL1	77.0	41.5	4.8
142	9	4	2	0.50	RACK-9-ROW4-COL2	78.0	43.0	4.9
1	1	1	1	0.50	RACK-1-ROW1-COL1	0.0	0.0	0.1
47	4	1	1	0.50	RACK-4-ROW1-COL1	0.0	0.0	0.1
94	7	1	1	0.50	RACK-7-ROW1-COL1	0.0	0.0	0.1
\.


--
-- TOC entry 3701 (class 0 OID 16884)
-- Dependencies: 225
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.warehouse (warehouse_id, city_id, warehouse_name) FROM stdin;
1	1	Central Warehouse 
2	2	Main Distribution Center 
3	3	Southern Hub
\.


--
-- TOC entry 3718 (class 0 OID 0)
-- Dependencies: 223
-- Name: admin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.admin_id_seq', 3, true);


--
-- TOC entry 3719 (class 0 OID 0)
-- Dependencies: 215
-- Name: city_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.city_id_seq', 3, true);


--
-- TOC entry 3720 (class 0 OID 0)
-- Dependencies: 221
-- Name: crate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crate_id_seq', 32, true);


--
-- TOC entry 3721 (class 0 OID 0)
-- Dependencies: 222
-- Name: customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customer_id_seq', 4, true);


--
-- TOC entry 3722 (class 0 OID 0)
-- Dependencies: 234
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 15, true);


--
-- TOC entry 3723 (class 0 OID 0)
-- Dependencies: 218
-- Name: rack_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_id_seq', 1, true);


--
-- TOC entry 3724 (class 0 OID 0)
-- Dependencies: 217
-- Name: rack_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rack_type_id_seq', 1, false);


--
-- TOC entry 3725 (class 0 OID 0)
-- Dependencies: 220
-- Name: supplier_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.supplier_id_seq', 1, false);


--
-- TOC entry 3726 (class 0 OID 0)
-- Dependencies: 219
-- Name: tile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tile_id_seq', 142, true);


--
-- TOC entry 3727 (class 0 OID 0)
-- Dependencies: 216
-- Name: warehouse_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.warehouse_id_seq', 3, true);


--
-- TOC entry 3525 (class 2606 OID 17073)
-- Name: access access_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access
    ADD CONSTRAINT access_pkey PRIMARY KEY (admin_id, warehouse_id);


--
-- TOC entry 3519 (class 2606 OID 16993)
-- Name: admin admin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (admin_id);


--
-- TOC entry 3505 (class 2606 OID 16883)
-- Name: city city_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.city
    ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);


--
-- TOC entry 3515 (class 2606 OID 16969)
-- Name: crate crate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crate
    ADD CONSTRAINT crate_pkey PRIMARY KEY (crate_id);


--
-- TOC entry 3517 (class 2606 OID 16985)
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- TOC entry 3523 (class 2606 OID 17188)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- TOC entry 3509 (class 2606 OID 16911)
-- Name: rack rack_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_pkey PRIMARY KEY (rack_id);


--
-- TOC entry 3511 (class 2606 OID 16941)
-- Name: tile tile_aruco_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tile
    ADD CONSTRAINT tile_aruco_id_key UNIQUE (aruco_id);


--
-- TOC entry 3513 (class 2606 OID 16939)
-- Name: tile tile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tile
    ADD CONSTRAINT tile_pkey PRIMARY KEY (tile_id);


--
-- TOC entry 3507 (class 2606 OID 16889)
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (warehouse_id);


--
-- TOC entry 3526 (class 1259 OID 17160)
-- Name: idx_admin_id_access; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_admin_id_access ON public.access USING btree (admin_id);


--
-- TOC entry 3520 (class 1259 OID 17157)
-- Name: idx_crate_id_orders; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crate_id_orders ON public.orders USING btree (crate_id);


--
-- TOC entry 3528 (class 1259 OID 17162)
-- Name: idx_crate_id_placedin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crate_id_placedin ON public.placedin USING btree (crate_id);


--
-- TOC entry 3521 (class 1259 OID 17158)
-- Name: idx_customer_id_orders; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_customer_id_orders ON public.orders USING btree (customer_id);


--
-- TOC entry 3529 (class 1259 OID 17164)
-- Name: idx_tile_id_placedin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tile_id_placedin ON public.placedin USING btree (tile_id);


--
-- TOC entry 3527 (class 1259 OID 17161)
-- Name: idx_warehouse_id_access; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_warehouse_id_access ON public.access USING btree (warehouse_id);


--
-- TOC entry 3540 (class 2606 OID 17219)
-- Name: access access_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access
    ADD CONSTRAINT access_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admin(admin_id) ON DELETE CASCADE;


--
-- TOC entry 3541 (class 2606 OID 17224)
-- Name: access access_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access
    ADD CONSTRAINT access_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(warehouse_id) ON DELETE CASCADE;


--
-- TOC entry 3542 (class 2606 OID 17084)
-- Name: access fk_access_admin; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access
    ADD CONSTRAINT fk_access_admin FOREIGN KEY (admin_id) REFERENCES public.admin(admin_id) ON DELETE CASCADE;


--
-- TOC entry 3543 (class 2606 OID 17089)
-- Name: access fk_access_warehouse; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access
    ADD CONSTRAINT fk_access_warehouse FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(warehouse_id) ON DELETE CASCADE;


--
-- TOC entry 3536 (class 2606 OID 17229)
-- Name: orders fk_orders_crate; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_crate FOREIGN KEY (crate_id) REFERENCES public.crate(crate_id) ON DELETE CASCADE;


--
-- TOC entry 3537 (class 2606 OID 17234)
-- Name: orders fk_orders_customer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON DELETE CASCADE;


--
-- TOC entry 3544 (class 2606 OID 17239)
-- Name: placedin fk_placedin_crate; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.placedin
    ADD CONSTRAINT fk_placedin_crate FOREIGN KEY (crate_id) REFERENCES public.crate(crate_id) ON DELETE CASCADE;


--
-- TOC entry 3545 (class 2606 OID 17244)
-- Name: placedin fk_placedin_tile; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.placedin
    ADD CONSTRAINT fk_placedin_tile FOREIGN KEY (tile_id) REFERENCES public.tile(tile_id) ON DELETE CASCADE;


--
-- TOC entry 3532 (class 2606 OID 17249)
-- Name: rack fk_rack_warehouse; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT fk_rack_warehouse FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(warehouse_id) ON DELETE CASCADE;


--
-- TOC entry 3534 (class 2606 OID 17254)
-- Name: tile fk_tile_rack; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tile
    ADD CONSTRAINT fk_tile_rack FOREIGN KEY (rack_id) REFERENCES public.rack(rack_id) ON DELETE CASCADE;


--
-- TOC entry 3530 (class 2606 OID 17259)
-- Name: warehouse fk_warehouse_city; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT fk_warehouse_city FOREIGN KEY (city_id) REFERENCES public.city(city_id) ON DELETE CASCADE;


--
-- TOC entry 3538 (class 2606 OID 17039)
-- Name: orders orders_crate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_crate_id_fkey FOREIGN KEY (crate_id) REFERENCES public.crate(crate_id);


--
-- TOC entry 3539 (class 2606 OID 17044)
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- TOC entry 3546 (class 2606 OID 17099)
-- Name: placedin placedin_crate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.placedin
    ADD CONSTRAINT placedin_crate_id_fkey FOREIGN KEY (crate_id) REFERENCES public.crate(crate_id);


--
-- TOC entry 3547 (class 2606 OID 17109)
-- Name: placedin placedin_tile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.placedin
    ADD CONSTRAINT placedin_tile_id_fkey FOREIGN KEY (tile_id) REFERENCES public.tile(tile_id);


--
-- TOC entry 3533 (class 2606 OID 16912)
-- Name: rack rack_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(warehouse_id);


--
-- TOC entry 3535 (class 2606 OID 16942)
-- Name: tile tile_rack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tile
    ADD CONSTRAINT tile_rack_id_fkey FOREIGN KEY (rack_id) REFERENCES public.rack(rack_id);


--
-- TOC entry 3531 (class 2606 OID 16890)
-- Name: warehouse warehouse_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.city(city_id);


--
-- TOC entry 3716 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2024-06-30 18:02:26 IST

--
-- PostgreSQL database dump complete
--

