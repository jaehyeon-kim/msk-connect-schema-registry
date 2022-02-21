import psycopg2
import typer
from typing import Dict, Union
from pathlib import Path

conn = None  # global variable


def set_connection(params: Dict[str, Union[str, int]]):
    """
    Gets connection to PostgreSQL database instance
    :param params: dictionary of psycopg2 connection parameters
    :return: db connection
    """
    try:
        global conn
        conn = psycopg2.connect(**params)
        typer.echo("Database connection created")
    except (Exception, psycopg2.DatabaseError) as err:
        typer.echo(set_connection.__name__, err)
        exit(1)


def create_northwind_db():
    """
    Create Northwind database by executing SQL scripts
    """
    try:
        global conn
        with conn:
            with conn.cursor() as curs:
                curs.execute(set_script_path("00_create_schema.sql").open("r").read())
                curs.execute(set_script_path("01_northwind_ddl.sql").open("r").read())
                curs.execute(set_script_path("02_northwind_data.sql").open("r").read())
                curs.execute(set_script_path("03_cdc_events.sql").open("r").read())
                conn.commit()
                typer.echo("Northwind SQL scripts executed")
    except (psycopg2.OperationalError, psycopg2.DatabaseError, FileNotFoundError) as err:
        typer.echo(create_northwind_db.__name__, err)
        close_conn()
        exit(1)


def set_script_path(filename: str):
    """
    Set path of a sql script
    """
    script_path = Path.joinpath(Path(__file__).parent.parent, "sql")
    return Path.joinpath(script_path, filename)


def is_cdc_events_found(schema: str = "ods", table_name: str = "cdc_events"):
    """
    Queries database for checking if cdc_events table is found
    """
    try:
        global conn
        params = conn.get_dsn_parameters()
        with conn:
            with conn.cursor() as curs:
                curs.execute(
                    f"""
                    SELECT count(*) > 0
                      FROM information_schema.tables
                     WHERE table_catalog = '{params['dbname']}'
                       AND table_schema = '{schema}' 
                       AND table_name = '{table_name}'
                    """
                )
                return curs.fetchone()[0]
    except (psycopg2.OperationalError, psycopg2.DatabaseError) as err:
        typer.echo(is_cdc_events_found.__name__, err)
        close_conn()
        exit(1)


def close_conn():
    """
    Closes database connection
    """
    if conn is not None:
        conn.close()
        typer.echo("Database connection closed")
