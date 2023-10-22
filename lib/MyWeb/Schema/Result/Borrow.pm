package MyWeb::Schema::Result::Borrow;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('borrow');
__PACKAGE__->add_columns(
	'id' => {
		data_type => 'integer',
		is_auto_increment => 1,
	},
	'user_id' => {
		data_type => 'integer',
	},
	'book_id' => {
		data_type => 'integer',
	},
	'issue_date' =>{
		data_type => 'datetime',
		size => 20,
	},
	'returned_date' =>{
		data_type => 'datetime',
		size => 20,
	},
	'status' => {
		data_type => 'varchar',
		size => 1,
	},
	"remaining_days" => {
		data_type => 'integer'
	}
	
);
__PACKAGE__-> set_primary_key('id');
__PACKAGE__-> has_many (users => "MyWeb::Schema::Result::User", "user_id");

1;
