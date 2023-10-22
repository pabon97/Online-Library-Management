package Library;
use FindBin;
use Dancer2;
use Dancer2::Plugin::DBIC;
use Digest::SHA qw(sha1_hex);
use Dancer2::Plugin::Database;
use Dancer2::Core::Request::Upload;

# use  Dancer2::Session::Simple;
# use Dancer2::Plugin::FlashNote;
# use Dancer2::Plugin::Auth::Tiny;
use MyWeb::Schema;
use MyWeb::Schema::Result::Book;
use MyWeb::Schema::Result::User;
use MyWeb::Schema::Result::Admin;
use MyWeb::Schema::Result::Borrow;

our $VERSION = '0.1';

# Reusable date function (current date)


sub getCurrentDate {
	my ( $sec, $min,  $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

	my $month= $mon+1;
	my $current_year= $year+1900;

	my $current_date = "$current_year/$month/$mday";
	return $current_date;
}

# Reusable date function (returned date)


sub getReturnedDate {
	my ( $sec, $min,  $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

	my $returned_month= $mon+2;
	my $current_year= $year+1900;

	my $returned_date = "$current_year/$returned_month/$mday";
	return $returned_date;
}


#get all books
get '/' => sub{
	my $result = schema->resultset('Book');
	my @books = $result->search({}, { select => ['id','title', 'image_url', 'created_at', 'updated_at', 'author', 'description'] });
	template 'index' => { books => \@books };
};


get '/admin/registration' => sub {

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'admin/adminregistration', {flash_message => $flash_message};

};

post '/admin/registration' => sub {
	my $admin_data = params();

	#return $admin_data->{email};

	my $admin_exists = schema->resultset('Admin')->find({email=> $admin_data->{email}});

	#    return $admin_data;

	if ($admin_exists){

		#  return $admin_exists->email;
		app->session->write('flash_message', 'Email already exists');
		redirect '/admin/registration';

	}
	my $admin_salt = 'newadminsalt';
	my $hashed_admin_pass = sha1_hex($admin_data->{password} . $admin_salt);

	my $newAdmin = schema->resultset('Admin')->create(
		{
			username => $admin_data->{name},
			email => $admin_data->{email},
			password => $hashed_admin_pass

		}
	);

	app->session->write('flash_message', 'Admin Registered successfully');
	redirect '/admin/registration';


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

	# return $admin_login->{email};
	my $admin_exists = schema->resultset('Admin')->find({email => $admin_data ->{email}});

	# return $user_exists->user_id;

	if($admin_exists){
		my $salt = "newadminsalt";
		my $hashed_password = sha1_hex($admin_data ->{password} . $salt);

		if($hashed_password eq $admin_exists->password){

			# store the admin in session
			session admin =>{email=> $admin_exists->email, name=> $admin_exists->username, role=>'Admin'};
			redirect '/profile';
		}


	}
	app->session->write('flash_message', 'Wrong Credentials');
	redirect '/admin/login';


};

#Admin dashboard route
get '/dashboard'=> sub {
	if (session 'admin') {

		template 'dashboard';

	}else {
		return redirect uri_for ('/admin/login');
	}

};

# Admin show all books

get '/dashboard/allbooks' => sub {
	if (session 'admin'){
		my @allbooks = schema->resultset('Book')->all();

		# return \@allbooks

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/allbooks' => {books => \@allbooks, flash_message=> $flash_message};
	}else {
		return redirect uri_for('/admin/login');
	}
};


# Admin add book
get '/dashboard/addbook' => sub{

	if (session 'admin'){

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/addbook', {flash_message => $flash_message};
	}else {
		return redirect uri_for ('/admin/login');
	}
};

#Admin add a new book

post '/dashboard/addbook' => sub {
	my $new_book = params();
	my $upload = request->upload('file');
	my $created_at = getCurrentDate();
	my $updated_at = getReturnedDate();
	my $image_url;

	if ($upload) {
		my $dir = path(config->{appdir}, 'uploads');
		mkdir $dir if not -e $dir;
		my $path = path($dir, $upload->basename);

		# return $path;
		$upload->link_to($path);
		$image_url = "uploads/" . $upload->basename;

		# return  $image_url;
	}


	#  return $new_book->{upload};

	my $newBook = schema->resultset('Book')->create(
		{
			title => $new_book->{title},
			author => $new_book->{author},
			description=> $new_book->{description},
			image_url=> $image_url,
			created_at=> $created_at,
			updated_at=> $updated_at,


		}
	);
	app->session->write('flash_message', 'Book added successfully');
	redirect '/dashboard/addbook';
};

# Admin Update book

get '/dashboard/updatebook/:id' => sub {
	if (session 'admin'){
		my $bookInfo = schema->resultset('Book')->find({id=> params->{id}});

		# Check for a flash message in the stash
		my $flash_message = app->session->read('flash_message');

		# Clear the flash message
		app->session->write('flash_message', undef);
		template 'admin/updatebook', {bookInfo => $bookInfo, flash_message=> $flash_message};
	}else {
		return redirect uri_for('/admin/login');
	}
};

# Admin update single book
post '/dashboard/updatebook/:id' => sub {

	# my $book_id = route_parameters->get("id");
	# return $book_id;
	my $book_info = schema->resultset('Book')->find({id=> params->{id}});

	#return $book_info;
	my $createdTime = getCurrentDate();
	my $returnedTime = getReturnedDate();

	# return $book_info->{id}
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
		my $createdTime = getCurrentDate();
		my $returnedTime = getReturnedDate();

		# Update the book details
		$book_info->update(
			{
				title => $title,
				author => $author,
				description => $description,
				image_url => $file,
				created_at => $createdTime,
				updated_at => $returnedTime,
			}
		);
		app->session->write('flash_message', 'Book Updated successfully');
	} else {
		app->session->write('flash_message', 'Failed to update');
	}

	# redirect '/dashboard/updatebook/:id'

};


#Admin Delete book

get '/dashboard/allbooks/:id'=> sub{

	# my $delete_book = params();
	# return $delete_book->{id}
	my $item = schema->resultset('Book')->find({id=> params->{id}});

	# return $item;
	if ($item) {
		$item->delete;  # Delete the book if it exists
		app->session->write('flash_message', 'Book deleted successfully');
	} else {
		app->session->write('flash_message', 'Book not found');  # Set an error message
	}
	redirect '/dashboard/allbooks';
};


#show login page
get '/login' => sub {
	template 'user/login';
};

post '/login' => sub {
	my $login_data = params();
	my $user_exists = schema->resultset('User')->find({email => params->{email}});

	# return $user_exists->user_id;

	if($user_exists){
		my $salt = "saltstring";
		my $hashed_password = sha1_hex($login_data->{password} . $salt);

		if($hashed_password eq $user_exists->password){

			# store the user in session
			session user =>{email=> $user_exists->email, name=> $user_exists->username, role=>'User'};

			# session('is_logged_in'=> 1);
			redirect '/profile';
		}


	}
	return "Wrong credentials!!";


};

#set session for logged in user

get '/profile' => sub {
	my $session_active = session('user') ? session('user') : session('admin');
	if (not $session_active) {
		redirect '/login';
	}
	template 'profile' ,{data=> $session_active};
};

#show registration page
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
	my $user_exists = schema->resultset('User')->find({email => $user_data->{email}});
	if($user_exists){

		app->session->write('flash_message', 'User already exists');
		redirect '/registration';
	}

	my $salt = "saltstring";
	my $hashed_password = sha1_hex($user_data->{password} . $salt);
	my $newUser = schema->resultset('User')->create(
		{
			username => $user_data->{name},
			email => $user_data->{email},
			password => $hashed_password,
		}

	);
	app->session->write('flash_message', 'User Registered successfully');
	redirect '/registration';

};

#Logout route

get '/logout' => sub {
	app-> destroy_session;
	redirect '/';
};

#show details of books
get '/book/details/:id'=> sub {
	my $book = schema->resultset('Book')->find(params->{id});
	template 'user/bookdetails', { book => $book };

};

get '/book/borrow/:id'=> sub{

	# Check for a flash message in the stash
	my $flash_message = app->session->read('flash_message');

	# Clear the flash message
	app->session->write('flash_message', undef);
	template 'user/bookdetails', {flash_message=> $flash_message};


};

post '/book/borrow'=> sub{

	if (session 'user'){

		# accessing the email of current authenticated user from session
		my $authenticatedUserEmail = session('user')->{email};

		# retrieving current user details from db
		my $currentUser = schema->resultset('User')->find({email=> $authenticatedUserEmail});

		# return $currentUser->id;

		# retrieving the book that user requested.
		my $borrowBook = schema->resultset('Book')->find(params->{book_id});

		# return $borrowBook->id;

		my $currentDate = getCurrentDate();
		my $returnedDate = getReturnedDate();

		my $newBorrowRecord = schema->resultset('Borrow')->create(
			{
				user_id=> $currentUser->id,
				book_id=> $borrowBook->id,
				issue_date=> $currentDate,
				returned_date=> $returnedDate,
			}
		);

		app->session->write('flash_message', 'Borrowed Book Successfully');
		redirect '/book/borrow/:id';


	}else {
		return redirect uri_for ('/login');
	}


};


true;
