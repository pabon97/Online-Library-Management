package Dancer2::Plugin::FormValidator::Validator::Numeric;

use strict;
use warnings;

use Moo;
use utf8;
use Scalar::Util qw(looks_like_number);
use namespace::clean;

with 'Dancer2::Plugin::FormValidator::Role::Validator';

sub message {
    return {
        en => '%s must be numeric',
        ru => '%s должно содержать числовое значение',
        de => '%s muss eine Zahl sein',
    };
}

sub validate {
    my ($self, $field, $input) = @_;

    if ($self->_field_defined_and_non_empty($field, $input)) {
        return looks_like_number($input->{$field});
    }

    return 1;
}

1;
