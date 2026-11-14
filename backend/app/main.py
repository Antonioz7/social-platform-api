import psycopg
from fastapi import FastAPI, HTTPException
from psycopg.rows import dict_row

app = FastAPI()

@app.get("/health/db")
def health_db():
    try:
        with psycopg.connect(connect_timeout=3) as conn:
            conn.execute("SELECT 1").fetchone()
    except psycopg.Error as exc:
        print(exc, flush=True)
        raise HTTPException(
            status_code=503,
            detail="PostgreSQL no está disponible",
        ) from exc

    return {"status": "ok"}

@app.get("/users/{username}/feed")
def get_feed(username: str):
    with psycopg.connect(connect_timeout=3, row_factory=dict_row) as conn:
        return conn.execute(
            """
            SELECT autor.username, p.content, p.created_at
            FROM users AS lector
            JOIN follows AS f ON f.follower_id = lector.id
            JOIN posts AS p ON p.user_id = f.following_id
            JOIN users AS autor ON autor.id = p.user_id
            WHERE lector.username = %s
              AND p.author_hidden_at IS NULL
              AND p.admin_hidden_at IS NULL
            ORDER BY p.created_at DESC, p.id DESC
            LIMIT 20
            """,
            (username,),
        ).fetchall()