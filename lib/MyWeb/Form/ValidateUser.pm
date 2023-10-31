package MyWeb::Form::ValidateUser;
    use Moo;
    with 'Dancer2::Plugin::FormValidator::Role::Profile';

    sub profile {
         return{
            username =>  [ qw(required alpha_num length_min:4 length_max:32) ],
            email => [ qw(required email length_max:127) ],
            password => [ qw(required length_max:40) ]
         }
    }