package Dancer2::Plugin::FormValidator::Extension::DBIC::Exist;

use strict; use warnings;

use Moo;
use utf8;
use namespace::clean;

with 'Dancer2::Plugin::FormValidator::Role::Validator';

sub message {
    return {
        en => '%s does not exists',
        ru => '%s не существует',
        de => '%s existiert nicht',
    };
}

sub validate {
    my ($self, $field, $input, $source, $attribute) = @_;

    if ($self->_field_defined_and_non_empty($field, $input)) {
        return !!$self->extension->schema->resultset($source)->single(
            {
                $attribute => $input->{$field},
            }
        );
    }

    return 1;
}

1;