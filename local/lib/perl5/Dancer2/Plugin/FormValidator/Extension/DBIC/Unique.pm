package Dancer2::Plugin::FormValidator::Extension::DBIC::Unique;

use strict; use warnings;

use Moo;
use utf8;
use namespace::clean;

with 'Dancer2::Plugin::FormValidator::Role::Validator';

sub message {
    return {
        en => '%s is already exists',
        ru => '%s уже существует',
        de => '%s ist bereits vorhanden',
    };
}

sub validate {
    my ($self, $field, $input, $source, $attribute) = @_;

    if ($self->_field_defined_and_non_empty($field, $input)) {
        return not $self->extension->schema->resultset($source)->single(
            {
                $attribute => $input->{$field},
            }
        );
    }

    return 1;
}

1;