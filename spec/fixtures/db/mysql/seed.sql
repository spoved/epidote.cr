create schema if not exists epidote_test;

create table if not exists epidote_test.my_model (
    id int auto_increment primary key,
    name varchar(255) null,
    unique_name varchar(255) null,
    default_value varchar(255) default 'a string' null,
    not_nil_value int not null,
    uuid binary(16) null,
    extra_data json null,
    constraint my_model_unique_name_uindex unique (unique_name),
    constraint table_name_id_unique_name_uindex unique (id, unique_name)
);