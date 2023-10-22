package MyWeb::Schema::Result::User;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
	'id' => {
		data_type => 'integer',
		is_auto_increment => 1,
	},
	'username' => {
		data_type => 'varchar',
		size => 255,
	},
	'email' => {
		data_type => 'varchar',
		size => 255,
	},
	'password' =>{
		data_type => 'datetime',
		size => 20,
	},
	
	'status' =>{
		data_type => 'tinyint',
		size => 1,
	},
	'last_login' => {
		data_type => 'datetime',
		size => 20,
	},
	
);
__PACKAGE__-> set_primary_key('id');
__PACKAGE__-> has_many(borrows => "MyWeb::Schema::Result::Borrow", 'user_id');

1;