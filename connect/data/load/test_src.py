import os
import src


class TestDatabase:
    def setup_class(self):
        params = {
            "host": os.getenv("host"),
            "dbname": os.getenv("dbname"),
            "user": os.getenv("user"),
            "password": os.getenv("password"),
        }
        src.set_connection(params)

    def teardown_class(self):
        src.close_conn()

    def test_is_cdc_events_found(self):
        assert src.is_cdc_events_found() == True
