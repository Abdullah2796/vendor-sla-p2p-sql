-- Halden Networks (fictional) - vendor operations database
-- PostgreSQL 14+. Load with:  psql -d vendor_ops -f sql/00_schema.sql  (run from the repo root)

DROP TABLE IF EXISTS invoices, purchase_orders, incidents, sla_policy, vendors, projects CASCADE;

CREATE TABLE projects (
    project_id        INT PRIMARY KEY,
    project_name      TEXT NOT NULL,
    programme         TEXT NOT NULL,
    customer_segment  TEXT NOT NULL,
    go_live_date      DATE NOT NULL,
    device_count      INT  NOT NULL
);

CREATE TABLE vendors (
    vendor_id           INT PRIMARY KEY,
    vendor_name         TEXT NOT NULL,
    category            TEXT NOT NULL,
    contract_tier       TEXT NOT NULL,
    payment_terms_days  INT  NOT NULL
);

CREATE TABLE sla_policy (
    priority               TEXT PRIMARY KEY,
    response_target_min    INT NOT NULL,
    resolution_target_hrs  INT NOT NULL
);

CREATE TABLE incidents (
    incident_id   INT PRIMARY KEY,
    opened_at     TIMESTAMP NOT NULL,
    project_id    INT  NOT NULL REFERENCES projects,
    asset_id      INT  NOT NULL,          -- site / gateway cluster within the project
    vendor_id     INT  NOT NULL REFERENCES vendors,
    priority      TEXT NOT NULL REFERENCES sla_policy,
    category      TEXT NOT NULL,
    responded_at  TIMESTAMP,
    resolved_at   TIMESTAMP            -- NULL = still open at extract time
);

CREATE TABLE purchase_orders (
    po_id        INT PRIMARY KEY,
    vendor_id    INT NOT NULL REFERENCES vendors,
    project_id   INT NOT NULL REFERENCES projects,
    created_at   TIMESTAMP NOT NULL,
    approved_at  TIMESTAMP,
    po_amount    NUMERIC(12,2) NOT NULL,
    status       TEXT NOT NULL          -- Open / Closed / Cancelled
);

CREATE TABLE invoices (
    invoice_id      INT PRIMARY KEY,
    po_id           INT NOT NULL REFERENCES purchase_orders,
    received_date   DATE NOT NULL,
    approved_date   DATE,
    due_date        DATE NOT NULL,
    paid_date       DATE,               -- NULL = not paid yet
    invoice_amount  NUMERIC(12,2) NOT NULL
);

\copy projects        FROM 'data/projects.csv'        CSV HEADER
\copy vendors         FROM 'data/vendors.csv'         CSV HEADER
\copy sla_policy      FROM 'data/sla_policy.csv'      CSV HEADER
\copy incidents       FROM 'data/incidents.csv'       CSV HEADER NULL ''
\copy purchase_orders FROM 'data/purchase_orders.csv' CSV HEADER
\copy invoices        FROM 'data/invoices.csv'        CSV HEADER NULL ''

CREATE INDEX ON incidents (vendor_id, opened_at);
CREATE INDEX ON incidents (asset_id, category, opened_at);
CREATE INDEX ON invoices (po_id);
