# Mini Twitter

Proyecto Mini Twitter con la base de datos preparada para conectar el backend.

## Requisitos

- Docker Desktop con Docker Compose.
- Copiar `.env.example` como `.env` en la raíz del proyecto. `.env` contiene las credenciales locales y no debe subirse a Git.

## Iniciar PostgreSQL

Desde la raíz del proyecto, ejecuta:

```powershell
docker compose up -d db
docker compose ps
```

Espera a que el servicio `db` muestre el estado `healthy`. Para detenerlo, ejecuta `docker compose down`.

La conexión desde una aplicación que corre en tu computadora es:

| Parámetro | Valor |
| --- | --- |
| Motor | PostgreSQL 16 |
| Host | `localhost` |
| Puerto | `5434` |
| Base predeterminada | El valor de `POSTGRES_DB` en `.env` |
| Usuario y contraseña | Los valores de `POSTGRES_USER` y `POSTGRES_PASSWORD` en `.env` |

Si el backend corre como otro servicio de Docker Compose, conéctalo al host `db` y al puerto `5432`.

## Esquema

El esquema inicial está en [`database/migrations/001_initial_schema.sql`](database/migrations/001_initial_schema.sql). Crea los tipos enumerados y las tablas de usuarios, publicaciones, comentarios, likes, seguimientos, reportes, revisiones de reportes e historial de moderación, además de sus restricciones e índices.

Docker aplica automáticamente los archivos SQL de `database/migrations/` en orden alfabético cuando inicializa por primera vez el volumen `db-data`. Mantén el prefijo numérico para que las migraciones se ejecuten en el orden correcto. Los archivos de inicialización no se vuelven a ejecutar sobre un volumen existente.

Para aplicar el esquema inicial a otra base vacía dentro del contenedor, por ejemplo `minix_dev`:

```powershell
docker compose exec db sh -c 'createdb -U "$POSTGRES_USER" minix_dev'
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d minix_dev -v ON_ERROR_STOP=1 --single-transaction -f /docker-entrypoint-initdb.d/001_initial_schema.sql'
```

`createdb` se ejecuta una sola vez para esa base. Para ver las tablas:

```powershell
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d minix_dev -c "\\dt"'
```

## Añadir migraciones

Después de crear una base, agrega cada cambio de esquema en un archivo SQL nuevo con prefijo numérico, por ejemplo `002_...sql`. En desarrollo, aplica el nuevo archivo una sola vez a cada base existente. La inicialización de Docker solo procesa esos archivos automáticamente cuando el volumen está vacío; más adelante, el backend o el flujo de despliegue deberá llevar el registro de migraciones aplicadas.
