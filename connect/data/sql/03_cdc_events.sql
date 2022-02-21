--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET default_tablespace = '';
SET default_with_oids = false;

---
--- drop objects
---

DROP TABLE IF EXISTS cdc_events;
DROP FUNCTION IF EXISTS fn_insert_order_event;
DROP PROCEDURE IF EXISTS usp_init_order_events;
DROP PUBLICATION IF EXISTS cdc_publication;

--
-- Name: cdc_events; Type: TABLE; 
--

CREATE TABLE cdc_events(
    order_id        SMALLINT NOT NULL PRIMARY KEY,
    customer_id     BPCHAR NOT NULL,
    order_date      DATE,
    required_date   DATE,
    shipped_date    DATE,
    order_items     JSONB,
    products        JSONB,
    customer        JSONB,
    employee        JSONB,
    shipper         JSONB,
    shipment        JSONB,
    updated_at      TIMESTAMPTZ
);

--
-- Name: fn_insert_order_event; Type: FUNCTION; 
--

CREATE OR REPLACE FUNCTION fn_insert_order_event() 
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
    AS 
$$
BEGIN
    IF (TG_OP IN ('INSERT', 'UPDATE')) THEN
        WITH product_details AS (
            SELECT p.product_id, 
                  row_to_json(p.*)::jsonb AS product_details
            FROM (
                SELECT *
                FROM products p 
                JOIN suppliers s ON p.supplier_id = s.supplier_id 
                JOIN categories c ON p.category_id = c.category_id 
            ) AS p
        ), order_items AS (
            SELECT od.order_id, 
                  jsonb_agg(row_to_json(od.*)::jsonb - 'order_id') AS order_items, 
                  jsonb_agg(pd.product_details) AS products
            FROM order_details od 
            JOIN product_details pd ON od.product_id = pd.product_id
            WHERE od.order_id = NEW.order_id
            GROUP BY od.order_id 
        ), emps AS (
            SELECT employee_id,
                  row_to_json(e.*)::jsonb AS details
            FROM employees e 
        ), emp_territories AS (
            SELECT et.employee_id, 
                  jsonb_agg(
                    row_to_json(t.*) 
                  ) AS territories 
            FROM employee_territories et
            JOIN (
                SELECT t.territory_id, t.territory_description, t.region_id, r.region_description 
                FROM territories t 
                JOIN region r ON t.region_id = r.region_id 
            ) AS t ON et.territory_id = t.territory_id 
            GROUP BY et.employee_id 
        ), emp_details AS (
            SELECT e.employee_id,
                  e.details || jsonb_build_object('territories', et.territories) AS details
            FROM emps AS e
            JOIN emp_territories AS et ON e.employee_id = et.employee_id 
        )
            INSERT INTO cdc_events
                SELECT o.order_id,
                      o.customer_id,
                      o.order_date,
                      o.required_date,
                      o.shipped_date,
                      oi.order_items,
                      oi.products,
                      row_to_json(c.*)::jsonb AS customer,
                      ed.details::jsonb AS employee,
                      row_to_json(s.*)::jsonb AS shipper,
                      jsonb_build_object(
                        'freight', o.freight,
                        'ship_name', o.ship_name,
                        'ship_address', o.ship_address,
                        'ship_city', o.ship_city,
                        'ship_region', o.ship_region,
                        'ship_postal_code', o.ship_postal_code,
                        'ship_country', o.ship_country 
                      ) AS shipment,
                      now()
                FROM orders o 
                LEFT JOIN order_items oi ON o.order_id = oi.order_id
                JOIN customers c ON o.customer_id = c.customer_id 
                JOIN emp_details ed ON o.employee_id = ed.employee_id
                JOIN shippers s ON o.ship_via = s.shipper_id 
                WHERE o.order_id = NEW.order_id
            ON CONFLICT (order_id)
            DO UPDATE
                SET order_id        = excluded.order_id,
                    customer_id     = excluded.customer_id,
                    order_date      = excluded.order_date,
                    required_date   = excluded.required_date,
                    shipped_date    = excluded.shipped_date,
                    order_items     = excluded.order_items,
                    products        = excluded.products,
                    customer        = excluded.customer,
                    shipper         = excluded.shipper,
                    shipment        = excluded.shipment,
                    updated_at      = excluded.updated_at;
    END IF;
    RETURN NULL;
END 
$$;

--
-- Name: orders_triggered; Type: TRIGGER; 
--

CREATE TRIGGER orders_triggered
  AFTER INSERT OR UPDATE
  ON orders
  FOR EACH ROW
  EXECUTE PROCEDURE fn_insert_order_event();

--
-- Name: order_details_triggered; Type: TRIGGER; 
--

CREATE TRIGGER order_details_triggered
  AFTER INSERT OR UPDATE
  ON order_details
  FOR EACH ROW
  EXECUTE PROCEDURE fn_insert_order_event();

--
-- Name: usp_init_order_events; Type: STORED_PROCEDURE; 
--

CREATE OR REPLACE PROCEDURE usp_init_order_events()
LANGUAGE plpgsql
AS $$
BEGIN
  WITH product_details AS (
      SELECT p.product_id, 
            row_to_json(p.*)::jsonb AS product_details
      FROM (
          SELECT *
          FROM products p 
          JOIN suppliers s ON p.supplier_id = s.supplier_id 
          JOIN categories c ON p.category_id = c.category_id 
      ) AS p
  ), order_items AS (
      SELECT od.order_id, 
            jsonb_agg(row_to_json(od.*)::jsonb - 'order_id') AS order_items, 
            jsonb_agg(pd.product_details) AS products
      FROM order_details od 
      JOIN product_details pd ON od.product_id = pd.product_id
      GROUP BY od.order_id 
  ), emps AS (
      SELECT employee_id,
            row_to_json(e.*)::jsonb AS details
      FROM employees e 
  ), emp_territories AS (
      SELECT et.employee_id, 
            jsonb_agg(
              row_to_json(t.*) 
            ) AS territories 
      FROM employee_territories et
      JOIN (
          SELECT t.territory_id, t.territory_description, t.region_id, r.region_description 
          FROM territories t 
          JOIN region r ON t.region_id = r.region_id 
      ) AS t ON et.territory_id = t.territory_id 
      GROUP BY et.employee_id 
  ), emp_details AS (
      SELECT e.employee_id,
            e.details || jsonb_build_object('territories', et.territories) AS details
      FROM emps AS e
      JOIN emp_territories AS et ON e.employee_id = et.employee_id 
  )
      INSERT INTO cdc_events
          SELECT o.order_id,
                o.customer_id,
                o.order_date,
                o.required_date,
                o.shipped_date,
                oi.order_items,
                oi.products,
                row_to_json(c.*)::jsonb,
                ed.details::jsonb,
                row_to_json(s.*)::jsonb,
                jsonb_build_object(
                  'freight', o.freight,
                  'ship_name', o.ship_name,
                  'ship_address', o.ship_address,
                  'ship_city', o.ship_city,
                  'ship_region', o.ship_region,
                  'ship_postal_code', o.ship_postal_code,
                  'ship_country', o.ship_country 
                ),
                now()
          FROM orders o 
          JOIN order_items oi ON o.order_id = oi.order_id
          JOIN customers c ON o.customer_id = c.customer_id 
          JOIN emp_details ed ON o.employee_id = ed.employee_id
          JOIN shippers s ON o.ship_via = s.shipper_id;
END 
$$;

--
-- Name: cdc_publication; Type: PUBLICATION; 
--
CREATE PUBLICATION cdc_publication 
    FOR TABLE cdc_events;

--
-- execute usp_init_order_events;
--
CALL usp_init_order_events();