# Учебная практика ПМ.07 — вариант 07 «Салон красоты»

Репозиторий содержит SQL-файл варианта, скрипты автоматизации и подтверждающие результаты.
Пароли в репозитории отсутствуют.

## Исходные данные

| Параметр | Значение |
|---|---|
| СУБД | PostgreSQL 16 |
| ОС | Ubuntu Server 22.04 LTS |
| Исходная база | `pm07_v07` |
| Проверочная база | `pm07_v07_restore` |
| Предметные таблицы | `clients`, `masters`, `appointments` |
| Служебная таблица | `access_probe` |
| SQL варианта | `input.sql` |
| Операция | `pg_dump` в формате custom со сжатием + `pg_restore --list` |

## Состав репозитория

| Путь | Назначение |
|---|---|
| `input.sql` | SQL варианта 07: три предметные таблицы и `access_probe` |
| `config.env` | Параметры подключения без пароля |
| `config-test.env` | Тестовый конфиг с несуществующей базой для проверки отказа |
| `run.sh` | Каркас с функцией `run_task` из карточки варианта |
| `run-add.sh` | Копия с индивидуальным дополнением: SHA-256, размер, ротация |
| `run-test.sh` | Тестовая копия для контролируемого отказа |
| `manual.dump` | Ручная полная копия базы в формате custom |
| `manual.dump.sha256` | Контрольная сумма ручной копии |
| `rows-before.txt`, `rows-after.txt` | Контрольные значения до и после восстановления |
| `logs/run.log` | Журнал запусков |
| `backups/` | Архивы, оглавления `.toc.txt` и суммы `.sha256` |

## Подготовка базы

```sql
CREATE ROLE admin LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '<ADMIN_PASSWORD>';
CREATE ROLE app_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '<APP_PASSWORD>';
CREATE ROLE readonly LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '<READ_PASSWORD>';
CREATE DATABASE pm07_v07 OWNER admin TEMPLATE template0 ENCODING 'UTF8';
CREATE DATABASE pm07_v07_restore OWNER admin TEMPLATE template0 ENCODING 'UTF8';
```

Загрузка данных и права:

```bash
psql -h 127.0.0.1 -U admin -d pm07_v07 -v ON_ERROR_STOP=1 -f input.sql
psql -h 127.0.0.1 -U admin -d pm07_v07 -v ON_ERROR_STOP=1 \
 -c "REVOKE CREATE ON SCHEMA public FROM PUBLIC;" \
 -c "GRANT USAGE ON SCHEMA public TO app_user, readonly;" \
 -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO app_user;" \
 -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;" \
 -c "GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;" \
 -c "ALTER DEFAULT PRIVILEGES FOR ROLE admin IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO app_user;" \
 -c "ALTER DEFAULT PRIVILEGES FOR ROLE admin IN SCHEMA public GRANT SELECT ON TABLES TO readonly;"
```

## Настройка

`config.env` задаёт имя базы, адрес, порт и пути к утилитам. Пароль хранится отдельно, в профиле `auth/pgpass`:

```bash
mkdir -p auth
cat > auth/pgpass <<'EOF'
127.0.0.1:5432:pm07_v07:admin:<ADMIN_PASSWORD>
127.0.0.1:5432:pm07_v07:app_user:<APP_PASSWORD>
127.0.0.1:5432:pm07_v07:readonly:<READ_PASSWORD>
EOF
chmod 600 auth/pgpass
```

Формат строки: `хост:порт:база:пользователь:пароль`. Файл `auth/pgpass` исключён через `.gitignore` и в репозиторий не входит.

## Запуск

```bash
bash ./run.sh          # ручной запуск операции варианта
echo $?                # ожидается 0
```

Дополнение (контроль целостности и ротация):

```bash
bash ./run-add.sh
```

Проверка отказа:

```bash
bash ./run-test.sh
echo $?                # ожидается 1, в logs/run.log строка ERROR
```

## Фактические результаты

- `manual.dump` — 6602 байта, SHA-256 `a7e326d66b637fbc2bed2fcfd2c89ab1ac6e6876face42e37b2de8ed0edb0a65`;
- ручной запуск 16:45:57 — `backups/pm07_v07_20261120_164557.dump`, код 0;
- запуск по cron 17:00:01 — `backups/pm07_v07_20261120_170001.dump`;
- дополнение 17:06:30 — `backups/pm07_v07_20261120_170630.dump` и `.sha256` `b92bb0f5…25b99e`, старый тестовый файл удалён;
- восстановление в `pm07_v07_restore`: `clients`, `masters`, `appointments` — по 4 строки, SUM(id) = 10, SUM(amount) = 100; `rows-before.txt` и `rows-after.txt` совпадают.

## Безопасность

Пароли не хранятся в репозитории: профиль `auth/pgpass` исключён через `.gitignore`, в файлах репозитория реальных паролей нет. Архивы `.dump` — учебные, созданы в формате custom (gzip).
