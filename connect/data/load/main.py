import typer
from src import set_connection, create_northwind_db


def main(
    host: str = typer.Option(..., "--host", "-h", help="Database host"),
    port: int = typer.Option(5432, "--port", "-p", help="Database port"),
    dbname: str = typer.Option(..., "--dbname", "-d", help="Database name"),
    user: str = typer.Option(..., "--user", "-u", help="Database user name"),
    password: str = typer.Option(..., prompt=True, hide_input=True, help="Database user password"),
):
    to_create = typer.confirm("To create database?")
    if to_create:
        params = {"host": host, "port": port, "dbname": dbname, "user": user, "password": password}
        set_connection(params)
        create_northwind_db()


if __name__ == "__main__":
    typer.run(main)
