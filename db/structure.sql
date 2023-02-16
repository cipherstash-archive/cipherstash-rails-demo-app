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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: ore_64_8_v1_term; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ore_64_8_v1_term AS (
	bytes bytea
);


--
-- Name: ore_64_8_v1; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ore_64_8_v1 AS (
	terms public.ore_64_8_v1_term[]
);


--
-- Name: compare_ore_64_8_v1(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compare_ore_64_8_v1(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    cmp_result integer;
  BEGIN
    -- Recursively compare blocks bailing as soon as we can make a decision
    RETURN compare_ore_array(a.terms, b.terms);
  END
$$;


--
-- Name: compare_ore_64_8_v1_term(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compare_ore_64_8_v1_term(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    eq boolean := true;
    unequal_block smallint := 0;
    hash_key bytea;
    target_block bytea;

    left_block_size CONSTANT smallint := 16;
    right_block_size CONSTANT smallint := 32;
    right_offset CONSTANT smallint := 136; -- 8 * 17

    indicator smallint := 0;
  BEGIN
    IF a IS NULL AND b IS NULL THEN
      RETURN 0;
    END IF;

    IF a IS NULL THEN
      RETURN -1;
    END IF;

    IF b IS NULL THEN
      RETURN 1;
    END IF;

    IF bit_length(a.bytes) != bit_length(b.bytes) THEN
      RAISE EXCEPTION 'Ciphertexts are different lengths';
    END IF;

    FOR block IN 0..7 LOOP
      -- Compare each PRP (byte from the first 8 bytes) and PRF block (8 byte
      -- chunks of the rest of the value).
      -- NOTE:
      -- * Substr is ordinally indexed (hence 1 and not 0, and 9 and not 8).
      -- * We are not worrying about timing attacks here; don't fret about
      --   the OR or !=.
      IF
        substr(a.bytes, 1 + block, 1) != substr(b.bytes, 1 + block, 1)
        OR substr(a.bytes, 9 + left_block_size * block, left_block_size) != substr(b.bytes, 9 + left_block_size * BLOCK, left_block_size)
      THEN
        -- set the first unequal block we find
        IF eq THEN
          unequal_block := block;
        END IF;
        eq = false;
      END IF;
    END LOOP;

    IF eq THEN
      RETURN 0::integer;
    END IF;

    -- Hash key is the IV from the right CT of b
    hash_key := substr(b.bytes, right_offset + 1, 16);

    -- first right block is at right offset + nonce_size (ordinally indexed)
    target_block := substr(b.bytes, right_offset + 17 + (unequal_block * right_block_size), right_block_size);

    indicator := (
      get_bit(
        encrypt(
          substr(a.bytes, 9 + (left_block_size * unequal_block), left_block_size),
          hash_key,
          'aes-ecb'
        ),
        0
      ) + get_bit(target_block, get_byte(a.bytes, unequal_block))) % 2;

    IF indicator = 1 THEN
      RETURN 1::integer;
    ELSE
      RETURN -1::integer;
    END IF;
  END;
$$;


--
-- Name: compare_ore_array(public.ore_64_8_v1_term[], public.ore_64_8_v1_term[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compare_ore_array(a public.ore_64_8_v1_term[], b public.ore_64_8_v1_term[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    cmp_result integer;
  BEGIN
    IF array_length(a, 1) = 0 AND array_length(b, 1) = 0 THEN
      RETURN 0;
    END IF;
    IF array_length(a, 1) = 0 THEN
      RETURN -1;
    END IF;
    IF array_length(b, 1) = 0 THEN
      RETURN 1;
    END IF;

    cmp_result := compare_ore_64_8_v1_term(a[1], b[1]);
    IF cmp_result = 0 THEN
      RETURN compare_ore_array(array_remove(a, 1), array_remove(b, 1));
    END IF;
    
    RETURN cmp_result;
  END
$$;


--
-- Name: ore_64_8_v1_eq(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_eq(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) = 0
$$;


--
-- Name: ore_64_8_v1_gt(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_gt(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) = 1
$$;


--
-- Name: ore_64_8_v1_gte(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_gte(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) != -1
$$;


--
-- Name: ore_64_8_v1_lt(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_lt(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) = -1
$$;


--
-- Name: ore_64_8_v1_lte(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_lte(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) != 1
$$;


--
-- Name: ore_64_8_v1_neq(public.ore_64_8_v1, public.ore_64_8_v1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_neq(a public.ore_64_8_v1, b public.ore_64_8_v1) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1(a, b) <> 0
$$;


--
-- Name: ore_64_8_v1_term_eq(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_eq(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) = 0
$$;


--
-- Name: ore_64_8_v1_term_gt(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_gt(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) = 1
$$;


--
-- Name: ore_64_8_v1_term_gte(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_gte(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) != -1
$$;


--
-- Name: ore_64_8_v1_term_lt(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_lt(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) = -1
$$;


--
-- Name: ore_64_8_v1_term_lte(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_lte(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) != 1
$$;


--
-- Name: ore_64_8_v1_term_neq(public.ore_64_8_v1_term, public.ore_64_8_v1_term); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ore_64_8_v1_term_neq(a public.ore_64_8_v1_term, b public.ore_64_8_v1_term) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT compare_ore_64_8_v1_term(a, b) <> 0
$$;


--
-- Name: <; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.< (
    FUNCTION = public.ore_64_8_v1_term_lt,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    COMMUTATOR = OPERATOR(public.>),
    NEGATOR = OPERATOR(public.>=),
    RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);


--
-- Name: <; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.< (
    FUNCTION = public.ore_64_8_v1_lt,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    COMMUTATOR = OPERATOR(public.>),
    NEGATOR = OPERATOR(public.>=),
    RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);


--
-- Name: <=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<= (
    FUNCTION = public.ore_64_8_v1_term_lte,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    COMMUTATOR = OPERATOR(public.>=),
    NEGATOR = OPERATOR(public.>),
    RESTRICT = scalarlesel,
    JOIN = scalarlejoinsel
);


--
-- Name: <=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<= (
    FUNCTION = public.ore_64_8_v1_lte,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    COMMUTATOR = OPERATOR(public.>=),
    NEGATOR = OPERATOR(public.>),
    RESTRICT = scalarlesel,
    JOIN = scalarlejoinsel
);


--
-- Name: <>; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<> (
    FUNCTION = public.ore_64_8_v1_term_neq,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    NEGATOR = OPERATOR(public.=),
    MERGES,
    HASHES,
    RESTRICT = eqsel,
    JOIN = eqjoinsel
);


--
-- Name: <>; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.<> (
    FUNCTION = public.ore_64_8_v1_neq,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    NEGATOR = OPERATOR(public.=),
    MERGES,
    HASHES,
    RESTRICT = eqsel,
    JOIN = eqjoinsel
);


--
-- Name: =; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.= (
    FUNCTION = public.ore_64_8_v1_term_eq,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    NEGATOR = OPERATOR(public.<>),
    MERGES,
    HASHES,
    RESTRICT = eqsel,
    JOIN = eqjoinsel
);


--
-- Name: =; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.= (
    FUNCTION = public.ore_64_8_v1_eq,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    NEGATOR = OPERATOR(public.<>),
    MERGES,
    HASHES,
    RESTRICT = eqsel,
    JOIN = eqjoinsel
);


--
-- Name: >; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.> (
    FUNCTION = public.ore_64_8_v1_term_gt,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    COMMUTATOR = OPERATOR(public.<),
    NEGATOR = OPERATOR(public.<=),
    RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);


--
-- Name: >; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.> (
    FUNCTION = public.ore_64_8_v1_gt,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    COMMUTATOR = OPERATOR(public.<),
    NEGATOR = OPERATOR(public.<=),
    RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);


--
-- Name: >=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.>= (
    FUNCTION = public.ore_64_8_v1_term_gte,
    LEFTARG = public.ore_64_8_v1_term,
    RIGHTARG = public.ore_64_8_v1_term,
    COMMUTATOR = OPERATOR(public.<=),
    NEGATOR = OPERATOR(public.<),
    RESTRICT = scalarlesel,
    JOIN = scalarlejoinsel
);


--
-- Name: >=; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR public.>= (
    FUNCTION = public.ore_64_8_v1_gte,
    LEFTARG = public.ore_64_8_v1,
    RIGHTARG = public.ore_64_8_v1,
    COMMUTATOR = OPERATOR(public.<=),
    NEGATOR = OPERATOR(public.<),
    RESTRICT = scalarlesel,
    JOIN = scalarlejoinsel
);


--
-- Name: ore_64_8_v1_btree_ops; Type: OPERATOR FAMILY; Schema: public; Owner: -
--

CREATE OPERATOR FAMILY public.ore_64_8_v1_btree_ops USING btree;


--
-- Name: ore_64_8_v1_btree_ops; Type: OPERATOR CLASS; Schema: public; Owner: -
--

CREATE OPERATOR CLASS public.ore_64_8_v1_btree_ops
    DEFAULT FOR TYPE public.ore_64_8_v1 USING btree FAMILY public.ore_64_8_v1_btree_ops AS
    OPERATOR 1 public.<(public.ore_64_8_v1,public.ore_64_8_v1) ,
    OPERATOR 2 public.<=(public.ore_64_8_v1,public.ore_64_8_v1) ,
    OPERATOR 3 public.=(public.ore_64_8_v1,public.ore_64_8_v1) ,
    OPERATOR 4 public.>=(public.ore_64_8_v1,public.ore_64_8_v1) ,
    OPERATOR 5 public.>(public.ore_64_8_v1,public.ore_64_8_v1) ,
    FUNCTION 1 (public.ore_64_8_v1, public.ore_64_8_v1) public.compare_ore_64_8_v1(public.ore_64_8_v1,public.ore_64_8_v1);


--
-- Name: ore_64_8_v1_term_btree_ops; Type: OPERATOR FAMILY; Schema: public; Owner: -
--

CREATE OPERATOR FAMILY public.ore_64_8_v1_term_btree_ops USING btree;


--
-- Name: ore_64_8_v1_term_btree_ops; Type: OPERATOR CLASS; Schema: public; Owner: -
--

CREATE OPERATOR CLASS public.ore_64_8_v1_term_btree_ops
    DEFAULT FOR TYPE public.ore_64_8_v1_term USING btree FAMILY public.ore_64_8_v1_term_btree_ops AS
    OPERATOR 1 public.<(public.ore_64_8_v1_term,public.ore_64_8_v1_term) ,
    OPERATOR 2 public.<=(public.ore_64_8_v1_term,public.ore_64_8_v1_term) ,
    OPERATOR 3 public.=(public.ore_64_8_v1_term,public.ore_64_8_v1_term) ,
    OPERATOR 4 public.>=(public.ore_64_8_v1_term,public.ore_64_8_v1_term) ,
    OPERATOR 5 public.>(public.ore_64_8_v1_term,public.ore_64_8_v1_term) ,
    FUNCTION 1 (public.ore_64_8_v1_term, public.ore_64_8_v1_term) public.compare_ore_64_8_v1_term(public.ore_64_8_v1_term,public.ore_64_8_v1_term);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_admin_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_admin_comments (
    id bigint NOT NULL,
    namespace character varying,
    body text,
    resource_type character varying,
    resource_id bigint,
    author_type character varying,
    author_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_admin_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_admin_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_admin_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_admin_comments_id_seq OWNED BY public.active_admin_comments.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patients (
    id bigint NOT NULL,
    full_name character varying,
    email character varying,
    age integer,
    weight double precision,
    allergies character varying,
    medications character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: patients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.patients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: patients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.patients_id_seq OWNED BY public.patients.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: active_admin_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_admin_comments ALTER COLUMN id SET DEFAULT nextval('public.active_admin_comments_id_seq'::regclass);


--
-- Name: patients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients ALTER COLUMN id SET DEFAULT nextval('public.patients_id_seq'::regclass);


--
-- Name: active_admin_comments active_admin_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_admin_comments
    ADD CONSTRAINT active_admin_comments_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_active_admin_comments_on_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_admin_comments_on_author ON public.active_admin_comments USING btree (author_type, author_id);


--
-- Name: index_active_admin_comments_on_namespace; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_admin_comments_on_namespace ON public.active_admin_comments USING btree (namespace);


--
-- Name: index_active_admin_comments_on_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_admin_comments_on_resource ON public.active_admin_comments USING btree (resource_type, resource_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20230206223641'),
('20230206234321'),
('20230216010729');


