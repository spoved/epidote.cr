create keyspace if not exists epidote_test with replication = { 'class': 'SimpleStrategy',
'replication_factor': 1 };

create table if not exists epidote_test.my_model (
    uuid UUID primary key,
    name VARCHAR,
    default_value VARCHAR,
    not_nil_value int,
    extra_data map < VARCHAR,
    VARCHAR >
);