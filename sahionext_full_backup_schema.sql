--
-- PostgreSQL database dump
--

-- Dumped from database version 14.20 (Ubuntu 14.20-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 16.3

-- Started on 2026-02-27 19:56:13

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
-- TOC entry 7 (class 2615 OID 29905)
-- Name: raw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA raw;


--
-- TOC entry 3845 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA raw; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA raw IS 'Ingestion layer. Append-only JSONB blobs. No transforms. idempotency_key on every table.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 217 (class 1259 OID 30270)
-- Name: app_analytics; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.app_analytics (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    entity_id integer,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 3846 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE app_analytics; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.app_analytics IS 'RAW-02 | App-emitted analytics: class_completed, game_played, payment_received, etc.';


--
-- TOC entry 216 (class 1259 OID 30269)
-- Name: app_analytics_event_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.app_analytics_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3847 (class 0 OID 0)
-- Dependencies: 216
-- Name: app_analytics_event_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.app_analytics_event_id_seq OWNED BY raw.app_analytics.event_id;


--
-- TOC entry 215 (class 1259 OID 30256)
-- Name: app_users; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.app_users (
    id bigint NOT NULL,
    source_id integer NOT NULL,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 3848 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE app_users; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.app_users IS 'RAW-01 | Dual-write from app on every users INSERT/UPDATE.';


--
-- TOC entry 214 (class 1259 OID 30255)
-- Name: app_users_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.app_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3849 (class 0 OID 0)
-- Dependencies: 214
-- Name: app_users_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.app_users_id_seq OWNED BY raw.app_users.id;


--
-- TOC entry 219 (class 1259 OID 30285)
-- Name: billing_webhooks; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.billing_webhooks (
    webhook_id bigint NOT NULL,
    source text DEFAULT 'payplus'::text NOT NULL,
    event_type text NOT NULL,
    idempotency_key text NOT NULL,
    payplus_sequence bigint,
    payload jsonb NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 3850 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE billing_webhooks; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.billing_webhooks IS 'RAW-03 | PayPlus webhooks. Process ORDER BY _etl_loaded_at ASC, payplus_sequence ASC. Aggregate terminal state per subscription_id before UPDATE.';


--
-- TOC entry 218 (class 1259 OID 30284)
-- Name: billing_webhooks_webhook_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.billing_webhooks_webhook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3851 (class 0 OID 0)
-- Dependencies: 218
-- Name: billing_webhooks_webhook_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.billing_webhooks_webhook_id_seq OWNED BY raw.billing_webhooks.webhook_id;


--
-- TOC entry 221 (class 1259 OID 30302)
-- Name: dead_letter; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.dead_letter (
    id bigint NOT NULL,
    source_table text NOT NULL,
    source_row_id bigint NOT NULL,
    idempotency_key text,
    rejection_reason text NOT NULL,
    payload jsonb NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_retried_at timestamp with time zone,
    resolved boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 3852 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE dead_letter; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.dead_letter IS 'RAW-04 | Rows rejected by clean layer (FK violation, bad data). Investigate and replay. Never silently drop.';


--
-- TOC entry 220 (class 1259 OID 30301)
-- Name: dead_letter_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.dead_letter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3853 (class 0 OID 0)
-- Dependencies: 220
-- Name: dead_letter_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.dead_letter_id_seq OWNED BY raw.dead_letter.id;


--
-- TOC entry 317 (class 1259 OID 31398)
-- Name: llm_audio_analyses; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_audio_analyses (
    id bigint NOT NULL,
    source_id integer,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    job_id text,
    zoom_meeting_id text,
    summary text,
    topics jsonb,
    level text,
    grammar_feedback text,
    vocabulary_feedback text,
    pronunciation_feedback text,
    general_comment text,
    vocabulary_score integer DEFAULT 0,
    grammar_score integer DEFAULT 0,
    fluency_score integer DEFAULT 0,
    engagement_level text DEFAULT 'medium'::text,
    raw_analysis jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    vocabulary_words jsonb,
    grammar_points jsonb
);


--
-- TOC entry 3854 (class 0 OID 0)
-- Dependencies: 317
-- Name: TABLE llm_audio_analyses; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_audio_analyses IS 'RAW-08 | Source: MySQL llm_audio_analyses (2,486 rows). Massive nested JSON with all AI scores. Unpacked in clean layer.';


--
-- TOC entry 316 (class 1259 OID 31397)
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_audio_analyses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3855 (class 0 OID 0)
-- Dependencies: 316
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_audio_analyses_id_seq OWNED BY raw.llm_audio_analyses.id;


--
-- TOC entry 319 (class 1259 OID 31412)
-- Name: llm_intake_queue; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_intake_queue (
    id bigint NOT NULL,
    source_id integer,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    audio_url text,
    level text DEFAULT 'unknown'::text,
    language text DEFAULT 'hebrew'::text,
    zoom_meeting_id text,
    topic text,
    priority integer DEFAULT 100 NOT NULL,
    request_id text,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 5 NOT NULL,
    error text,
    metadata jsonb,
    updated_at timestamp with time zone,
    admitted_at timestamp with time zone
);


--
-- TOC entry 3856 (class 0 OID 0)
-- Dependencies: 319
-- Name: TABLE llm_intake_queue; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_intake_queue IS 'RAW-09 | Source: MySQL llm_intake_queue (2,619 rows). Queue entries before LLM processing.';


--
-- TOC entry 318 (class 1259 OID 31411)
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_intake_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3857 (class 0 OID 0)
-- Dependencies: 318
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_intake_queue_id_seq OWNED BY raw.llm_intake_queue.id;


--
-- TOC entry 321 (class 1259 OID 31426)
-- Name: llm_request_attempts; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_request_attempts (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id text,
    attempt_number integer,
    provider text,
    model text,
    status text,
    error text,
    latency_ms integer,
    tokens_prompt integer,
    tokens_completion integer,
    cost_estimate numeric(10,6),
    worker_id text,
    total_ms integer,
    audio_file_size_bytes bigint,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    resolve_ms integer,
    download_ms integer,
    upload_ms integer,
    analyze_ms integer,
    store_ms integer
);


--
-- TOC entry 3858 (class 0 OID 0)
-- Dependencies: 321
-- Name: TABLE llm_request_attempts; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_request_attempts IS 'RAW-10 | Source: MySQL llm_request_attempts (3,180 rows). Per-attempt latency, cost, stage breakdowns.';


--
-- TOC entry 320 (class 1259 OID 31425)
-- Name: llm_request_attempts_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_request_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3859 (class 0 OID 0)
-- Dependencies: 320
-- Name: llm_request_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_request_attempts_id_seq OWNED BY raw.llm_request_attempts.id;


--
-- TOC entry 323 (class 1259 OID 31440)
-- Name: llm_request_events; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_request_events (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id text,
    event_type text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_data jsonb
);


--
-- TOC entry 3860 (class 0 OID 0)
-- Dependencies: 323
-- Name: TABLE llm_request_events; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_request_events IS 'RAW-11 | Source: MySQL llm_request_events (8,523 rows). Event log for every request state change.';


--
-- TOC entry 322 (class 1259 OID 31439)
-- Name: llm_request_events_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_request_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3861 (class 0 OID 0)
-- Dependencies: 322
-- Name: llm_request_events_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_request_events_id_seq OWNED BY raw.llm_request_events.id;


--
-- TOC entry 313 (class 1259 OID 31370)
-- Name: llm_requests; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_requests (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    request_id text,
    class_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id text,
    prompt_template_id text,
    provider text,
    model text,
    attempt_count integer DEFAULT 0 NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    schema_validation_status text,
    updated_at timestamp with time zone,
    locked_at timestamp with time zone,
    worker_id text,
    dedup_hit_count integer DEFAULT 0 NOT NULL,
    schema_definition jsonb
);


--
-- TOC entry 3862 (class 0 OID 0)
-- Dependencies: 313
-- Name: TABLE llm_requests; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_requests IS 'RAW-06 | Source: MySQL llm_requests (2,614 rows). Full request blobs. Append-only.';


--
-- TOC entry 312 (class 1259 OID 31369)
-- Name: llm_requests_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3863 (class 0 OID 0)
-- Dependencies: 312
-- Name: llm_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_requests_id_seq OWNED BY raw.llm_requests.id;


--
-- TOC entry 315 (class 1259 OID 31384)
-- Name: llm_responses; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.llm_responses (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    raw_response text,
    parsed_response jsonb,
    request_id text
);


--
-- TOC entry 3864 (class 0 OID 0)
-- Dependencies: 315
-- Name: TABLE llm_responses; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.llm_responses IS 'RAW-07 | Source: MySQL llm_responses (2,579 rows). raw_response + parsed_response blobs.';


--
-- TOC entry 314 (class 1259 OID 31383)
-- Name: llm_responses_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.llm_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3865 (class 0 OID 0)
-- Dependencies: 314
-- Name: llm_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.llm_responses_id_seq OWNED BY raw.llm_responses.id;


--
-- TOC entry 311 (class 1259 OID 31352)
-- Name: zoom_webhook_request; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.zoom_webhook_request (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    meeting_id text NOT NULL,
    session_uuid text,
    recording_start timestamp with time zone,
    recording_end timestamp with time zone,
    audio_url text,
    urls text,
    payload jsonb,
    retry_count integer DEFAULT 0 NOT NULL,
    error_message text,
    processed boolean DEFAULT false NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    llm_response_raw jsonb,
    created_at timestamp with time zone,
    webhook_payload jsonb
);


--
-- TOC entry 3866 (class 0 OID 0)
-- Dependencies: 311
-- Name: TABLE zoom_webhook_request; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON TABLE raw.zoom_webhook_request IS 'RAW-05 | Zoom recording webhooks. Renamed from zoom_processing_queue. recording_start, recording_end, audio_url extracted from payload on ingest.';


--
-- TOC entry 3867 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.idempotency_key; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON COLUMN raw.zoom_webhook_request.idempotency_key IS 'Built from session_uuid. Kept for consistency with other raw tables.';


--
-- TOC entry 3868 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.session_uuid; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON COLUMN raw.zoom_webhook_request.session_uuid IS 'Unique session identifier from Zoom. Used as natural idempotency key — no duplicate inserts possible.';


--
-- TOC entry 3869 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.audio_url; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON COLUMN raw.zoom_webhook_request.audio_url IS 'Primary m4a audio file url extracted from payload.';


--
-- TOC entry 3870 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.urls; Type: COMMENT; Schema: raw; Owner: -
--

COMMENT ON COLUMN raw.zoom_webhook_request.urls IS 'All urls found in payload comma separated, all file types.';


--
-- TOC entry 310 (class 1259 OID 31351)
-- Name: zoom_webhook_request_id_seq; Type: SEQUENCE; Schema: raw; Owner: -
--

CREATE SEQUENCE raw.zoom_webhook_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3871 (class 0 OID 0)
-- Dependencies: 310
-- Name: zoom_webhook_request_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: -
--

ALTER SEQUENCE raw.zoom_webhook_request_id_seq OWNED BY raw.zoom_webhook_request.id;


--
-- TOC entry 3558 (class 2604 OID 30273)
-- Name: app_analytics event_id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_analytics ALTER COLUMN event_id SET DEFAULT nextval('raw.app_analytics_event_id_seq'::regclass);


--
-- TOC entry 3556 (class 2604 OID 30259)
-- Name: app_users id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_users ALTER COLUMN id SET DEFAULT nextval('raw.app_users_id_seq'::regclass);


--
-- TOC entry 3560 (class 2604 OID 30288)
-- Name: billing_webhooks webhook_id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.billing_webhooks ALTER COLUMN webhook_id SET DEFAULT nextval('raw.billing_webhooks_webhook_id_seq'::regclass);


--
-- TOC entry 3564 (class 2604 OID 30305)
-- Name: dead_letter id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.dead_letter ALTER COLUMN id SET DEFAULT nextval('raw.dead_letter_id_seq'::regclass);


--
-- TOC entry 3584 (class 2604 OID 31401)
-- Name: llm_audio_analyses id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_audio_analyses ALTER COLUMN id SET DEFAULT nextval('raw.llm_audio_analyses_id_seq'::regclass);


--
-- TOC entry 3591 (class 2604 OID 31415)
-- Name: llm_intake_queue id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_intake_queue ALTER COLUMN id SET DEFAULT nextval('raw.llm_intake_queue_id_seq'::regclass);


--
-- TOC entry 3601 (class 2604 OID 31429)
-- Name: llm_request_attempts id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_attempts ALTER COLUMN id SET DEFAULT nextval('raw.llm_request_attempts_id_seq'::regclass);


--
-- TOC entry 3604 (class 2604 OID 31443)
-- Name: llm_request_events id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_events ALTER COLUMN id SET DEFAULT nextval('raw.llm_request_events_id_seq'::regclass);


--
-- TOC entry 3573 (class 2604 OID 31373)
-- Name: llm_requests id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_requests ALTER COLUMN id SET DEFAULT nextval('raw.llm_requests_id_seq'::regclass);


--
-- TOC entry 3581 (class 2604 OID 31387)
-- Name: llm_responses id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_responses ALTER COLUMN id SET DEFAULT nextval('raw.llm_responses_id_seq'::regclass);


--
-- TOC entry 3568 (class 2604 OID 31355)
-- Name: zoom_webhook_request id; Type: DEFAULT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.zoom_webhook_request ALTER COLUMN id SET DEFAULT nextval('raw.zoom_webhook_request_id_seq'::regclass);


--
-- TOC entry 3615 (class 2606 OID 30278)
-- Name: app_analytics app_analytics_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_analytics
    ADD CONSTRAINT app_analytics_pkey PRIMARY KEY (event_id);


--
-- TOC entry 3609 (class 2606 OID 30264)
-- Name: app_users app_users_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_users
    ADD CONSTRAINT app_users_pkey PRIMARY KEY (id);


--
-- TOC entry 3622 (class 2606 OID 30295)
-- Name: billing_webhooks billing_webhooks_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.billing_webhooks
    ADD CONSTRAINT billing_webhooks_pkey PRIMARY KEY (webhook_id);


--
-- TOC entry 3629 (class 2606 OID 30312)
-- Name: dead_letter dead_letter_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.dead_letter
    ADD CONSTRAINT dead_letter_pkey PRIMARY KEY (id);


--
-- TOC entry 3668 (class 2606 OID 31406)
-- Name: llm_audio_analyses llm_audio_analyses_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_audio_analyses
    ADD CONSTRAINT llm_audio_analyses_pkey PRIMARY KEY (id);


--
-- TOC entry 3678 (class 2606 OID 31420)
-- Name: llm_intake_queue llm_intake_queue_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_intake_queue
    ADD CONSTRAINT llm_intake_queue_pkey PRIMARY KEY (id);


--
-- TOC entry 3689 (class 2606 OID 31434)
-- Name: llm_request_attempts llm_request_attempts_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_attempts
    ADD CONSTRAINT llm_request_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 3697 (class 2606 OID 31448)
-- Name: llm_request_events llm_request_events_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_events
    ADD CONSTRAINT llm_request_events_pkey PRIMARY KEY (id);


--
-- TOC entry 3651 (class 2606 OID 31378)
-- Name: llm_requests llm_requests_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT llm_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 3659 (class 2606 OID 31392)
-- Name: llm_responses llm_responses_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_responses
    ADD CONSTRAINT llm_responses_pkey PRIMARY KEY (id);


--
-- TOC entry 3620 (class 2606 OID 30280)
-- Name: app_analytics uq_raw_app_analytics_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_analytics
    ADD CONSTRAINT uq_raw_app_analytics_idem UNIQUE (idempotency_key);


--
-- TOC entry 3613 (class 2606 OID 30266)
-- Name: app_users uq_raw_app_users_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.app_users
    ADD CONSTRAINT uq_raw_app_users_idem UNIQUE (idempotency_key);


--
-- TOC entry 3691 (class 2606 OID 31436)
-- Name: llm_request_attempts uq_raw_llm_attempts_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_attempts
    ADD CONSTRAINT uq_raw_llm_attempts_idem UNIQUE (idempotency_key);


--
-- TOC entry 3670 (class 2606 OID 31408)
-- Name: llm_audio_analyses uq_raw_llm_audio_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_audio_analyses
    ADD CONSTRAINT uq_raw_llm_audio_idem UNIQUE (idempotency_key);


--
-- TOC entry 3699 (class 2606 OID 31450)
-- Name: llm_request_events uq_raw_llm_events_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_request_events
    ADD CONSTRAINT uq_raw_llm_events_idem UNIQUE (idempotency_key);


--
-- TOC entry 3680 (class 2606 OID 31422)
-- Name: llm_intake_queue uq_raw_llm_intake_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_intake_queue
    ADD CONSTRAINT uq_raw_llm_intake_idem UNIQUE (idempotency_key);


--
-- TOC entry 3653 (class 2606 OID 31380)
-- Name: llm_requests uq_raw_llm_requests_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT uq_raw_llm_requests_idem UNIQUE (idempotency_key);


--
-- TOC entry 3661 (class 2606 OID 31394)
-- Name: llm_responses uq_raw_llm_responses_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_responses
    ADD CONSTRAINT uq_raw_llm_responses_idem UNIQUE (idempotency_key);


--
-- TOC entry 3627 (class 2606 OID 30297)
-- Name: billing_webhooks uq_raw_webhooks_idem; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.billing_webhooks
    ADD CONSTRAINT uq_raw_webhooks_idem UNIQUE (idempotency_key);


--
-- TOC entry 3638 (class 2606 OID 31553)
-- Name: zoom_webhook_request uq_raw_zoom_session_uuid; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.zoom_webhook_request
    ADD CONSTRAINT uq_raw_zoom_session_uuid UNIQUE (session_uuid);


--
-- TOC entry 3640 (class 2606 OID 31362)
-- Name: zoom_webhook_request zoom_webhook_request_pkey; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.zoom_webhook_request
    ADD CONSTRAINT zoom_webhook_request_pkey PRIMARY KEY (id);


--
-- TOC entry 3630 (class 1259 OID 30314)
-- Name: idx_dead_letter_created; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_dead_letter_created ON raw.dead_letter USING btree (created_at DESC);


--
-- TOC entry 3631 (class 1259 OID 30313)
-- Name: idx_dead_letter_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_dead_letter_source ON raw.dead_letter USING btree (source_table, resolved);


--
-- TOC entry 3616 (class 1259 OID 30282)
-- Name: idx_raw_analytics_entity; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_analytics_entity ON raw.app_analytics USING btree (entity_id);


--
-- TOC entry 3617 (class 1259 OID 30283)
-- Name: idx_raw_analytics_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_analytics_loaded ON raw.app_analytics USING btree (_etl_loaded_at);


--
-- TOC entry 3618 (class 1259 OID 30281)
-- Name: idx_raw_analytics_type; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_analytics_type ON raw.app_analytics USING btree (event_type);


--
-- TOC entry 3681 (class 1259 OID 87415)
-- Name: idx_raw_llm_attempts_ended; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_ended ON raw.llm_request_attempts USING btree (ended_at);


--
-- TOC entry 3682 (class 1259 OID 31438)
-- Name: idx_raw_llm_attempts_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_loaded ON raw.llm_request_attempts USING btree (_etl_loaded_at);


--
-- TOC entry 3683 (class 1259 OID 31820)
-- Name: idx_raw_llm_attempts_model; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_model ON raw.llm_request_attempts USING btree (model);


--
-- TOC entry 3684 (class 1259 OID 31819)
-- Name: idx_raw_llm_attempts_request; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_request ON raw.llm_request_attempts USING btree (request_id);


--
-- TOC entry 3685 (class 1259 OID 31841)
-- Name: idx_raw_llm_attempts_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_source ON raw.llm_request_attempts USING btree (source_id);


--
-- TOC entry 3686 (class 1259 OID 87414)
-- Name: idx_raw_llm_attempts_started; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_started ON raw.llm_request_attempts USING btree (started_at);


--
-- TOC entry 3687 (class 1259 OID 31821)
-- Name: idx_raw_llm_attempts_status; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_attempts_status ON raw.llm_request_attempts USING btree (status);


--
-- TOC entry 3662 (class 1259 OID 87418)
-- Name: idx_raw_llm_audio_created; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_audio_created ON raw.llm_audio_analyses USING btree (created_at);


--
-- TOC entry 3663 (class 1259 OID 87417)
-- Name: idx_raw_llm_audio_job; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_audio_job ON raw.llm_audio_analyses USING btree (job_id);


--
-- TOC entry 3664 (class 1259 OID 31410)
-- Name: idx_raw_llm_audio_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_audio_loaded ON raw.llm_audio_analyses USING btree (_etl_loaded_at);


--
-- TOC entry 3665 (class 1259 OID 31409)
-- Name: idx_raw_llm_audio_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_audio_source ON raw.llm_audio_analyses USING btree (source_id);


--
-- TOC entry 3666 (class 1259 OID 87416)
-- Name: idx_raw_llm_audio_zoom; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_audio_zoom ON raw.llm_audio_analyses USING btree (zoom_meeting_id);


--
-- TOC entry 3692 (class 1259 OID 31452)
-- Name: idx_raw_llm_events_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_events_loaded ON raw.llm_request_events USING btree (_etl_loaded_at);


--
-- TOC entry 3693 (class 1259 OID 31823)
-- Name: idx_raw_llm_events_request; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_events_request ON raw.llm_request_events USING btree (request_id);


--
-- TOC entry 3694 (class 1259 OID 31854)
-- Name: idx_raw_llm_events_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_events_source ON raw.llm_request_events USING btree (source_id);


--
-- TOC entry 3695 (class 1259 OID 31824)
-- Name: idx_raw_llm_events_type; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_events_type ON raw.llm_request_events USING btree (event_type);


--
-- TOC entry 3671 (class 1259 OID 31551)
-- Name: idx_raw_llm_intake_created; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_created ON raw.llm_intake_queue USING btree (created_at DESC);


--
-- TOC entry 3672 (class 1259 OID 31424)
-- Name: idx_raw_llm_intake_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_loaded ON raw.llm_intake_queue USING btree (_etl_loaded_at);


--
-- TOC entry 3673 (class 1259 OID 31818)
-- Name: idx_raw_llm_intake_request; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_request ON raw.llm_intake_queue USING btree (request_id);


--
-- TOC entry 3674 (class 1259 OID 31423)
-- Name: idx_raw_llm_intake_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_source ON raw.llm_intake_queue USING btree (source_id);


--
-- TOC entry 3675 (class 1259 OID 31550)
-- Name: idx_raw_llm_intake_status; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_status ON raw.llm_intake_queue USING btree (status, _etl_loaded_at);


--
-- TOC entry 3676 (class 1259 OID 31817)
-- Name: idx_raw_llm_intake_zoom; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_intake_zoom ON raw.llm_intake_queue USING btree (zoom_meeting_id);


--
-- TOC entry 3641 (class 1259 OID 31546)
-- Name: idx_raw_llm_requests_class; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_class ON raw.llm_requests USING btree (class_id);


--
-- TOC entry 3642 (class 1259 OID 31547)
-- Name: idx_raw_llm_requests_created; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_created ON raw.llm_requests USING btree (created_at DESC);


--
-- TOC entry 3643 (class 1259 OID 31382)
-- Name: idx_raw_llm_requests_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_loaded ON raw.llm_requests USING btree (_etl_loaded_at);


--
-- TOC entry 3644 (class 1259 OID 31812)
-- Name: idx_raw_llm_requests_model; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_model ON raw.llm_requests USING btree (model);


--
-- TOC entry 3645 (class 1259 OID 79384)
-- Name: idx_raw_llm_requests_prompt; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_prompt ON raw.llm_requests USING btree (prompt_template_id);


--
-- TOC entry 3646 (class 1259 OID 31825)
-- Name: idx_raw_llm_requests_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_source ON raw.llm_requests USING btree (source_id);


--
-- TOC entry 3647 (class 1259 OID 31545)
-- Name: idx_raw_llm_requests_status; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_status ON raw.llm_requests USING btree (status, _etl_loaded_at);


--
-- TOC entry 3648 (class 1259 OID 79383)
-- Name: idx_raw_llm_requests_user; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_user ON raw.llm_requests USING btree (user_id);


--
-- TOC entry 3649 (class 1259 OID 31813)
-- Name: idx_raw_llm_requests_worker; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_requests_worker ON raw.llm_requests USING btree (worker_id);


--
-- TOC entry 3654 (class 1259 OID 87419)
-- Name: idx_raw_llm_responses_completed; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_responses_completed ON raw.llm_responses USING btree (completed_at);


--
-- TOC entry 3655 (class 1259 OID 31396)
-- Name: idx_raw_llm_responses_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_responses_loaded ON raw.llm_responses USING btree (_etl_loaded_at);


--
-- TOC entry 3656 (class 1259 OID 87413)
-- Name: idx_raw_llm_responses_request; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_responses_request ON raw.llm_responses USING btree (request_id);


--
-- TOC entry 3657 (class 1259 OID 31866)
-- Name: idx_raw_llm_responses_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_llm_responses_source ON raw.llm_responses USING btree (source_id);


--
-- TOC entry 3610 (class 1259 OID 30268)
-- Name: idx_raw_users_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_users_loaded ON raw.app_users USING btree (_etl_loaded_at);


--
-- TOC entry 3611 (class 1259 OID 30267)
-- Name: idx_raw_users_source; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_users_source ON raw.app_users USING btree (source_id);


--
-- TOC entry 3623 (class 1259 OID 30298)
-- Name: idx_raw_webhooks_proc; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_webhooks_proc ON raw.billing_webhooks USING btree (processed, _etl_loaded_at);


--
-- TOC entry 3624 (class 1259 OID 30300)
-- Name: idx_raw_webhooks_seq; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_webhooks_seq ON raw.billing_webhooks USING btree (payplus_sequence);


--
-- TOC entry 3625 (class 1259 OID 30299)
-- Name: idx_raw_webhooks_type; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_webhooks_type ON raw.billing_webhooks USING btree (event_type);


--
-- TOC entry 3632 (class 1259 OID 64992)
-- Name: idx_raw_zoom_created; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_zoom_created ON raw.zoom_webhook_request USING btree (created_at);


--
-- TOC entry 3633 (class 1259 OID 31368)
-- Name: idx_raw_zoom_loaded; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_zoom_loaded ON raw.zoom_webhook_request USING btree (_etl_loaded_at);


--
-- TOC entry 3634 (class 1259 OID 31366)
-- Name: idx_raw_zoom_meeting; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_zoom_meeting ON raw.zoom_webhook_request USING btree (meeting_id);


--
-- TOC entry 3635 (class 1259 OID 31367)
-- Name: idx_raw_zoom_processed; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_zoom_processed ON raw.zoom_webhook_request USING btree (processed, _etl_loaded_at);


--
-- TOC entry 3636 (class 1259 OID 31365)
-- Name: idx_raw_zoom_session; Type: INDEX; Schema: raw; Owner: -
--

CREATE INDEX idx_raw_zoom_session ON raw.zoom_webhook_request USING btree (session_uuid);


--
-- TOC entry 3700 (class 2606 OID 31540)
-- Name: llm_requests llm_requests_class_id_fkey; Type: FK CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT llm_requests_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE SET NULL;


-- Completed on 2026-02-27 19:56:33

--
-- PostgreSQL database dump complete
--

