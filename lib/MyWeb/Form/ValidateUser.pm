package MyWeb::Form::ValidateUser;
# use Dancer2::Plugin::FormValidator;
   use Moo;
    with 'Dancer2::Plugin::FormValidator::Role::Profile';

### First create form validation profile class.
 
package RegisterForm {

 
    ### Here you need to declare fields => validators.
 
    sub profile {
        return {
            username     => [ qw(required length_min:4 length_max:32) ],
            email        => [ qw(required email length_max:127 unique:Users,email) ],
            password     => [ qw(required length_min:6 length_max:40) ],
            status      => [ qw(required enum:active, inactive) ],
        };
    }
}
 
### Now you can use it in your Dancer2 project.
 
1;