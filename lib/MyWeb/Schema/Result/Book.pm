package MyWeb::Schema::Result::Book;

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('books');
__PACKAGE__->add_columns(
	'id' => {
		data_type => 'integer',
		is_auto_increment => 1,
	},
	'title' => {
		data_type => 'varchar',
		size => 255,
	},
	'image_url' => {
		data_type => 'varchar',
		size => 255,
	},
	'created_at' =>{
		data_type => 'datetime',
		size => 20,
	},
	'updated_at' =>{
		data_type => 'datetime',
		size => 20,
	},
	'author' => {
		data_type => 'varchar',
		size => 255,
	},
	"description" => {
		data_type => 'varchar',
		size => 255,
	},
	"stock" =>{
		data_type => 'integer'
	}

);
__PACKAGE__-> set_primary_key('id');

1;

