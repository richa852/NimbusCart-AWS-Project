"""
NimbusCart API
A small Flask REST API backed by PostgreSQL.

Routes:
    GET  /health  -> liveness check, no DB dependency
    GET  /items   -> returns all products
    POST /items   -> inserts a product, returns the created row

The API creates its own schema on first successful DB interaction
(CREATE TABLE IF NOT EXISTS). Nothing outside the app touches the schema.
"""
import os
import time

from flask import Flask, jsonify, request
import psycopg2
import psycopg2.extras

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "nimbuscart")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")

_SCHEMA_READY = False


def get_connection():
    """Open a fresh connection to Postgres."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )


def ensure_schema(conn):
    """Create the products table if it doesn't already exist.

    This runs lazily on first real DB interaction rather than at
    import time, so /health can respond 200 even before the DB
    is reachable.
    """
    global _SCHEMA_READY
    if _SCHEMA_READY:
        return
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS products (
                id     SERIAL PRIMARY KEY,
                name   TEXT NOT NULL,
                price  NUMERIC NOT NULL,
                stock  INTEGER NOT NULL
            );
            """
        )
    conn.commit()
    _SCHEMA_READY = True


@app.get("/health")
def health():
    """Liveness check. Deliberately does not touch the database."""
    return jsonify(status="ok"), 200


@app.get("/items")
def list_items():
    conn = get_connection()
    try:
        ensure_schema(conn)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, price, stock FROM products ORDER BY id;")
            rows = cur.fetchall()
        return jsonify(rows), 200
    finally:
        conn.close()


@app.post("/items")
def create_item():
    body = request.get_json(silent=True) or {}
    name = body.get("name")
    price = body.get("price")
    stock = body.get("stock")

    if name is None or price is None or stock is None:
        return jsonify(error="name, price and stock are required"), 400

    conn = get_connection()
    try:
        ensure_schema(conn)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO products (name, price, stock) VALUES (%s, %s, %s) "
                "RETURNING id, name, price, stock;",
                (name, price, stock),
            )
            row = cur.fetchone()
        conn.commit()
        return jsonify(row), 201
    finally:
        conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
