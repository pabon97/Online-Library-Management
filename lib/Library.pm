package Library;
use Data::Dumper;
use FindBin;
use Dancer2;
use Dancer2::Plugin::FormValidator;
use Dancer2::Plugin::DBIC;
use Digest::SHA qw(sha1_hex);
use Dancer2::Plugin::Database;
use Dancer2::Core::Request::Upload;
use CHI;
use DateTime;
use Date::Calc qw(Delta_Days);
use File::Slurp;
use GD;
use IPC::System::Simple qw(systemx);

use Dancer2::Plugin::Email;
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Try::Tiny;

# use  Dancer2::Session::Simple;
# use Dancer2::Plugin::FlashNote;
# use Dancer2::Plugin::Auth::Tiny;
use MyWeb::Schema;
use MyWeb::Schema::Result::Book;
use MyWeb::Schema::Result::User;
use MyWeb::Schema::Result::Admin;
use MyWeb::Schema::Result::Borrow;

# our $userValidator = Myweb::Form::ValidateUser->new;
our $VERSION = '0.1';

# configure cache
my $cache = CHI->new(
	driver     => 'Memory',   # Use the same driver you configured
	global     => 1,          # Make it a global cache
);


# Reusable date function (current date)
sub getCurrentDate {
	my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my ( $sec, $min,  $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

	my $month= $mon+1;
	my $current_year= $year+1900;

	my $current_date = "$current_year-$month-$mday";
	my $upload_time = "$mday $months[$mon]-$hour-$min-$sec-$current_year";
	return ( $current_date, $upload_time);

}

# Reusable date function (returned date)
sub getReturnedDate {
	my ( $sec, $min,  $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

	my $returned_month= $mon+2;
	my $current_year= $year+1900;

	my $returned_date = "$current_year-$returned_month-$mday";
	return $returned_date;
}


# Reusable registration function for admin & login

sub registration_user_or_admin {
	my ($data, $resultset, $salt, $redirect_route) = @_;
	my $user_exists = schema->resultset($resultset)->find({email=> $data->{email}});
	if ($user_exists) {
		app->session->write('flash_message', 'User already exists');
		redirect $redirect_route;
	}

	    my $hashed_password = sha1_hex($data->{password} . $salt);
		my $newUser = schema->resultset($resultset)->create(
		{
			username=> $data->{name},
			email=> $data->{email},
			password=> $hashed_password,
			($resultset eq 'User' ? ('status'=> 0) : ()),
		}
	);
 
	
	app->session->write('flash_message', "$resultset Registered Successfully");
	redirect $redirect_route;
}

# Reusable Login function for user & admin
sub login_user_or_admin {

	# login_data => form data, user_type=> admin or user which is from session $salt => hashpassword
	my ($login_data, $user_type, $resultset,  $salt) = @_;
	my $user_exists = schema->resultset($resultset)->find({email=> $login_data->{email}});

	#   return $user_exists->email;
	if($user_exists){
		my $newsalt = $salt;
		my $hashed_password = sha1_hex($login_data->{password} . $newsalt);

		# return "$hashed_password login pass: $user_exists->password";
		# return $user_exists->password;
		if ($hashed_password eq $user_exists->password) {
			if ($user_type eq 'user' && $user_exists->status == 0) {
				return "Inactive $user_type";
			}
			session $user_type => {
				id=> $user_exists->{id},
				email=> $user_exists->{email},
				name=> $user_exists->{username},
				role=> ucfirst($user_type),
			};
			redirect '/profile';
		}
	}
	return 'Wrong Credentials';

}


#get all books
get '/' => sub{
	my $active_session = session('user') ? session('user') : session('admin');
	my $key = 'book_data';
	my $books = $cache->get($key);
	my $data_source = 'cache';
	if ($books) {
		return template 'index' => { books => $books, data => $active_session, source=> $data_source};
	}else {
		my $result = schema->resultset('Book');
		my @books = $result->search({}, { select => ['id','title', 'image_url', 'created_at', 'updated_at', 'author', 'description'] });

		# cache the book data for 10 mins(600 s)
		$cache->set($key, \@books, '600s');
		$data_source = "Database"; # Data was fetched from the database
		return template 'index' => { books => \@books, data=>$active_session, source=> $data_source };
	}


};


# Admin registration
get '/admin/registration' => sub {

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'admin/adminregistration', {flash_message => $flash_message};

};

post '/admin/registration' => sub {
	my $admin_data = params();
	registration_user_or_admin($admin_data, 'Admin', 'newadminsalt', '/admin/registration');

};

# admin login route
get '/admin/login'=> sub {

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'admin/adminlogin', {flash_message=> $flash_message};
};

post '/admin/login' => sub {
	my $admin_data = params();

	# my $salt = "saltstring";
	# return login_user_or_admin($admin_data,'admin','Admin',$salt);

	my $admin_exists = schema->resultset('Admin')->find({email => $admin_data ->{email}});

	# return $admin_exists->id;
	if($admin_exists){
		my $salt = "newadminsalt";
		my $hashed_password = sha1_hex($admin_data ->{password} . $salt);

		if($hashed_password eq $admin_exists->password){

			# store the admin in session
			session admin =>{email=> $admin_exists->email, name=> $admin_exists->username, id=>$admin_exists->id, role=>'Admin'};
			redirect '/profile';
		}


	}
	app->session->write('flash_message', 'Wrong Credentials');
	redirect '/admin/login';

};

# user registration page
get '/registration' => sub {

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'user/registration', {flash_message=> $flash_message};
};

# add new users to db
post '/registration' => sub {
	my $user_data = params();
	registration_user_or_admin($user_data, "User", "saltstring", "/registration");

};


#show login page
get '/login' => sub {
	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'user/login', {flash_message=> $flash_message};
};

post '/login' => sub {
	my $login_data = params();

	# my $salt = 'saltstring';
	# return login_user_or_admin($login_data, 'user', "User", $salt);

	my $user_exists = schema->resultset('User')->find({email => params->{email}});

	# return $user_exists->borrow_status;

	if($user_exists && $user_exists->status == 1){
		my $salt = "saltstring";
		my $hashed_password = sha1_hex($login_data->{password} . $salt);

		if($hashed_password eq $user_exists->password){

			# store the user in session
			session user =>{email=> $user_exists->email, name=> $user_exists->username, id=>$user_exists->id, role=>'User'};

			# session('is_logged_in'=> 1);
			redirect '/profile';
		}


	}
	# return "Wrong credentials or Inactive User";
	app->session->write('flash_message', 'Wrong Credentials or Inactive User');
	redirect '/login';


};

#set session for logged in user
# profile route
get '/profile' => sub {
	my $session_active = session('user') ? session('user') : session('admin');

	# return $session_active->{id};
	if (not $session_active) {
		redirect '/login';
	}
	template 'profile' ,{data=> $session_active};
};


#Logout route
get '/logout' => sub {
	app-> destroy_session;
	redirect '/';
};


#Admin dashboard route
get '/dashboard'=> sub {
	my $session_active = session('user') ? session('user') : session('admin');

	# Check if $session_active is defined and not empty
	if (!$session_active) {
		if (session('user')) {

			# Redirect to the user login route
			redirect '/login';
		} elsif (session('admin')) {

			# Redirect to the admin login route
			redirect '/admin/login';
		}
	}

	# return $session_active->{id};
	if ($session_active) {
		my @books = schema->resultset('Book')->all();
		my @users = schema->resultset('User')->all();
		my @borrows = schema->resultset('Borrow')->all();

		# for user dashboard user can see total returned books for users
		my @total_returned_user = schema->resultset('Borrow')->search({status=>0});

		#  user dashboard user total borrowed book && admin can see total borrowed books of users
		my @user_borrowed = schema->resultset('Borrow')->search(
			{
				status=> {'>'=> 0},
				user_id=> $session_active->{id},
			}
		);
		my @user_returned = schema->resultset('Borrow')->search(
			{
				status=> {'<'=> 1},
				user_id=> $session_active->{id},
			}
		);

		# return \@total_returned;

		template 'dashboard', {books => \@books, users=> \@users, borrows=> \@borrows, data=>$session_active, totalreturned=> \@total_returned_user, userborrowed=> \@user_borrowed, userreturned=> \@user_returned};


	}else {
		return redirect uri_for ('/admin/login');
	}

};


get '/dashboard/userinfo' => sub{
	my $session_active = session('user');
	if ( $session_active ) {
		my $borrow_info = schema->resultset('Borrow')->search({ user_id => $session_active->{id} },{ columns => [qw/id status/] });
		my @borrow_data = $borrow_info->all;

		# return $session_active->{borrow_status};
		# return $sum_status;
		template 'user/userinfo', {data=> $session_active, borrowdatas=> \@borrow_data };
	}else {
		return redirect uri_for('/login');
	}
};

post '/dashboad/userinfo/:id'=> sub {
	my $user_borrow = schema->resultset('Borrow')->find({id=> params->{id}});

	#  return $user_borrow->status;
	if ($user_borrow->status == 1) {
		$user_borrow->update({ status => 0 });
		return 'Book Returned';
	}else {
		return 'Book not returned';
	}

};

# Show all users in admin table
get '/dashboard/allusers' => sub {
	my $session_active = session('admin');
	if (session 'admin'){
		my @allusers = schema->resultset('User')->all();
		my @allborrows = schema->resultset('Borrow')->all();

		# return \@allbooks

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/allusers' => {users => \@allusers, borrows=> \@allborrows, flash_message=> $flash_message, data=>$session_active};
	}else {
		return redirect uri_for('/admin/login');
	}
};

# Approve single User by id
post '/dashboard/allusers/:id'=> sub{
	my $user_status = schema->resultset('User')->find({id=> params->{id}});

	# return $user_status->status;

	if ($user_status->status == 0) {
		$user_status->update({ status => 1 });
		return 'Status updated';
	}elsif ($user_status->status == 1) {
		return 'User already approved';
	}else {
		return 'Status not updated';
	}

};

# Delete user by id in admin table
get '/dashboard/allusers/:id'=> sub{
	my $User = schema->resultset('User')->find({id=> params->{id}});

	# return $User;
	if ($User) {
		$User->delete;  # Delete the book if it exists
		app->session->write('flash_message', 'User removed successfully');
	} else {
		app->session->write('flash_message', 'User not found');  # Set an error message
	}
	redirect '/dashboard/allusers';
};

# Admin show all books

get '/dashboard/allbooks' => sub {
	my $session_active = session('admin');
	if (session 'admin'){
		my @allbooks = schema->resultset('Book')->all();

		# return \@allbooks

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/allbooks' => {books => \@allbooks, flash_message=> $flash_message, data=>$session_active};
	}else {
		return redirect uri_for('/admin/login');
	}
};


# Admin add book
get '/dashboard/addbook' => sub{
	my $session_active = session('admin');

	if (session 'admin'){

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/addbook', {flash_message => $flash_message, data=> $session_active};
	}else {
		return redirect uri_for ('/admin/login');
	}
};

#Admin add a new book

post '/dashboard/addbook' => sub {
	my $new_book = params();
	my $upload = request->upload('file');
	my ($current_date, $upload_time) = getCurrentDate();
	my $updated_at = getReturnedDate();
	my $image_url;

	if (!$upload) {
		return 'No file uploaded';
	}

	my $file_extension = lc($upload->basename);
	$file_extension =~ s/.*\.//;

	# return $file_extension;

	if ($file_extension !~ /^(jpg|jpeg|png)$/) {
		return "File type not allowed. Only .jpg, .jpeg, and .png files are accepted.";
	}

	my $max_file_size = 2 * 1024 * 1024; #2 MB
	 # return $upload->size;
	if($upload->size > $max_file_size){
		my $content = $upload->content;

		#   return length($content);
		if(length($content) > $max_file_size){
			$content = substr($content, 0, $max_file_size);
			$upload->content($content);
		}

		#   return length($content);

	}

	if ($upload) {
		my $dir = path(config->{appdir}, 'public','uploads');

		# /home/pabon/Library/uploads
		# return $dir;
		mkdir $dir if not -e $dir;
		my $file_name = $upload_time ."-". $upload->basename;
		my $path = path($dir,$file_name);

		# return $upload->basename;
		# return $path;
		$upload->link_to($path);
		$image_url = "uploads/" . $file_name;

		# return $image_url;
	}


	#  return $new_book->{upload};

	my $newBook = schema->resultset('Book')->create(
		{
			title => $new_book->{title},
			author => $new_book->{author},
			description=> $new_book->{description},
			image_url=> $image_url,
			created_at=> $current_date,
			updated_at=> $updated_at,


		}
	);
	my $key = 'book_data';
	$cache->remove($key);
	app->session->write('flash_message', 'Book added successfully');
	redirect '/dashboard/addbook';
};

# Admin Update book

get '/dashboard/updatebook/:id' => sub {
	my $active_session = session('admin');
	if ($active_session ){
		my $bookInfo = schema->resultset('Book')->find({id=> params->{id}});

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/updatebook', {bookInfo => $bookInfo, flash_message=> $flash_message, data=> $active_session};
	}else {
		return redirect uri_for('/admin/login');
	}
};

# Admin update single book
post '/dashboard/updatebook/:id' => sub {
	my $book_info = schema->resultset('Book')->find({id=> params->{id}});

	#return $book_info;

	my $upload = request->upload('file');
	my $image_url;
	if ($upload) {
		my $dir = path(config->{appdir}, 'public','uploads');
		mkdir $dir if not -e $dir;
		my $basename = $upload->basename;
		my $path = path($dir, $basename);
		$upload->link_to($path);

		# $image_url = "/uploads/" . $upload->basename;
		$image_url = "/uploads/$basename";
		print "Image URL: $image_url\n";
	}

	# Update the book details
	if ($book_info) {

		# Retrieve updated values from the form
		my $title = params->{'title'};
		my $author = params->{'author'};
		my $description = params->{'description'};

		# Only update the 'image_url' column if a new image was uploaded
		my $file = $image_url || $book_info->image_url;
		my ($current_date) = getCurrentDate();

		# my $updated_time = getCurrentDate();

		# Update the book details
		$book_info->update(
			{
				title => $title,
				author => $author,
				description => $description,
				image_url => $file,
				created_at => $current_date,
				updated_at => $current_date,
			}
		);
		my $key = 'book_data';
		$cache->remove($key);
		app->session->write('flash_message', 'Book Updated successfully');
	} else {
		app->session->write('flash_message', 'Failed to update');
	}

	# redirect '/dashboard/updatebook/:id'

};


#Admin Delete book

get '/dashboard/allbooks/:id'=> sub{

	my $item = schema->resultset('Book')->find({id=> params->{id}});

	# return $item;
	if ($item) {
		$item->delete;  # Delete the book if it exists
		my $key = 'book_data';
		$cache->remove($key);
		app->session->write('flash_message', 'Book deleted successfully');
	} else {
		app->session->write('flash_message', 'Book not found');  # Set an error message
	}
	redirect '/dashboard/allbooks';
};


#show details of books
get '/book/details/:id'=> sub {
	my $session_active = session('user');
	my $autheticateduserid = $session_active->{id};
	my $book = schema->resultset('Book')->find(params->{id});
	my ($current_date) = getCurrentDate();
	# return $book->title;

	# Search for both status 0 and 1
	my $borrow_status = [0, 1];

	#  check the user has already borrowed the book or not

	my $user_id_borrow = schema->resultset('Borrow')->search(
		{
			user_id => $autheticateduserid,
			book_id => params->{id},
			returned_date => {'!='=> undef},
			status => $borrow_status,
		}
	)->single;

	# return $user_id_borrow->status;
	
	# Calculate the difference in days only if the user has borrowed the book means status == 1
    if ($user_id_borrow && $user_id_borrow->status == 1) {
		# MySQL date strings
        my $date_str1 = $current_date;
        my $date_str2 = $user_id_borrow->returned_date;

        my ($year1, $month1, $day1) = split('-', $date_str1);
        my ($year2, $month2, $day2) = split('-', $date_str2);

        if ($year1 && $month1 && $day1 && $year2 && $month2 && $day2) {
            my $difference = Delta_Days($year1, $month1, $day1, $year2, $month2, $day2);

            if ($difference == 3) {
                my $email_status = send_reminder_email($session_active->{email}, $book->title, $difference);
				# return $email_status;
                return "You have only $difference days remaining to return the book";
            } elsif ($difference == 0) {
				my $email_status = send_reminder_email($session_active->{email}, $book->title, $difference);
				# return $email_status
                return "You have $difference days. you have not returned the book";
            } elsif ($difference < 0) {
				my $email_status = send_reminder_email($session_active->{email}, $book->title, $difference);
				# return $email_status;
                return 'You have not returned the book; you will be charged for each day';
            } else {
                return "You still have $difference days for returning the book";
            }
        }
    } 
	# elsif ($user_id_borrow && $user_id_borrow->status == 0) {
    #     return 'You have not borrowed the book';
    # }
	# return $user_id_borrow->status;
	my $status_message;

	#    return $status_message;

	if ($user_id_borrow) {
		if($user_id_borrow->status == 0){
			$status_message = 'Borrow';
		} elsif($user_id_borrow->status == 1){
			$status_message = 'Already borrowed';
		}

	} else {
		$status_message = 'Borrow';
	}

	# return $autheticateduserid;

	my $base_url = $ENV{DB_HOST};
	template 'user/bookdetails', { book => $book, db_host=> $base_url, data=>$session_active, status=> $status_message };


};

# send reminder mail who have borrowed books

sub send_reminder_email {
  my ($user_email, $book_title, $difference) = @_;

  my $email_body;
  if ($difference == 3) {
	$email_body = "You have only $difference days remaining to return the book";
  } elsif ($difference == 0) {
	$email_body = "Your date is expired. you have not returned the book"
  } elsif ($difference < 0) {
	$email_body = "You have not returned the book, now you will be charged for 2 dollar each day.";
    }
    my $email_status;
	try {
       email {
		from=> $ENV{SMTP_USERNAME},
		to=> $user_email,
		subject=> 'Library Reminder',
		body=> "Dear $user_email, $email_body: $book_title.",
		type    => 'html', # can be 'html' or 'plain'
		# headers => {
        #         "X-Mailer"          => 'This fine Dancer2 application',
        #         "X-Accept-Language" => 'en',
        #     },	
	   }
	} catch {
		my $error = $_;
		if ($error) {
		  $email_status = "Could not send email: $error";
		}
		else {
			$email_status = "System error is: $@";
		}
       
	    
    };
	return $email_status;

	#Create and send the email with a reminder message
	# my $email_status;
    # my $email = Email::Simple->create(
    #     header => [
    #         To      => $user_email,
    #         From    => 'pabon@orangetoolz.com',  # Replace with your email
    #         Subject => 'Library Reminder',
    #     ],
    #     body => "Dear $user_email, $email_body: $book_title.",
    # );

	# try {
    #     sendmail($email);
    #     # Log that the reminder email was sent
    #     $email_status = "Reminder email sent successfully to $user_email.\n";
    # } catch {
    #     $email_status = "Error sending reminder email: $_";
    # };
	# return $email_status;
}

   

get '/book/borrow/:id'=> sub{

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'user/bookdetails', {flash_message=> $flash_message,};

};

post '/book/borrow'=> sub{

	if (session 'user'){

		# accessing the email of current authenticated user from session
		my $authenticatedUserEmail = session('user')->{email};

		# return $authenticatedUserEmail->{id};

		# retrieving current user details from db
		my $currentUser = schema->resultset('User')->find({email=> $authenticatedUserEmail});

		# return $currentUser->status;

		# retrieving the book that user requested.
		my $borrowBook = schema->resultset('Book')->find(params->{book_id});

		my ($current_date) = getCurrentDate();
		my $returnedDate = getReturnedDate();
		my $remaining_days = 30;

		my $newBorrowRecord = schema->resultset('Borrow')->create(
			{
				user_id=> $currentUser->id,
				book_id=> $borrowBook->id,
				issue_date=> $current_date,
				returned_date=> $returnedDate,
				remaining_days=> $remaining_days,

				# status 1 means borrowed and 0 means returned.
				status=> 1
			}
		);

		app->session->write('flash_message', 'Book borrowed successfully');

		# redirect '/book/borrow/:id';


	}else {
		return redirect uri_for ('/login');
	}


};


true;
