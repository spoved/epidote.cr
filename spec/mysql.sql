create table my_model
(
	id int auto_increment,
	name varchar(255) null,
	unique_name varchar(255) null,
	default_value varchar(255) default "a string" null,
	not_nil_value int not null,
	uuid binary null,
	extra_data json null,
	constraint my_model_pk
		primary key (id)
);

create unique index my_model_unique_name_uindex
	on my_model (unique_name);

create unique index table_name_id_unique_name_uindex
	on my_model (id, unique_name);

