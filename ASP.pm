#####################################################################
#
# ASP - Facilitate integration of PerlScript with ASP
#
# Author: Tim Hammerquist
# Revision: 1.00
# NOTES: based on Matt Sergeant's Win32-ASP module.
#
#####################################################################
#
# Copyright 2000 Tim Hammerquist.  All rights reserved.
#
# This file is distributed under the Artistic License.
# See http://www.perl.com/language/misc/Artistic.html or
# the license that comes with your perl distribution.
#
# Contact me at cafall@voffice.net with any comments,
# flames, queries, suggestions, or general curiosity.
#
#####################################################################
use strict;

package ASP::IO;
sub TIEHANDLE	{ shift->new(@_) }
sub PRINT		{ shift->print(@_) }
sub PRINTF		{ shift->print(sprintf(@_)) }
sub new { bless {}, shift; }
sub print {
    my $self = shift;
    ASP::Print(@_);
    1;
}

1;

package ASP;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

BEGIN {
	require Exporter;
	require AutoLoader;

	use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
		$Application $ObjectContext $Request $Response
		$Server $Session $ScriptingNamespace @DeathHooks
		);

	@ISA = qw( Exporter AutoLoader );
	%EXPORT_TAGS =	(
		basic => [qw(
			Print die exit param param_count
			)],
		strict => [qw(
			Print die exit param param_count
			$Application $ObjectContext $Request
			$Response $Server $Session
			$ScriptingNamespace
			)],
		all => [qw(
			Print die exit param param_count
			$Application $ObjectContext $Request
			$Response $Server $Session
			$ScriptingNamespace
			DebugPrint HTMLPrint
			escape unescape escapeHTML unescapeHTML
			)],
	);
	Exporter::export_tags('all');
	Exporter::export_ok_tags('all');

	$Application = $main::Application;
	$ObjectContext = $main::ObjectContext;
	$Request = $main::Request;
	$Response = $main::Response;
	$Server = $main::Server;
	$Session = $main::Session;
	$ScriptingNamespace = $main::ScriptingNamespace;

	%ENV = ();
	use Sys::Hostname;
	$ENV{HOST_NAME} = hostname;
	$ENV{HOST_IP} = join '.', unpack "C4", gethostbyname hostname;
	for (Win32::OLE::in( $Request->ServerVariables )) {
		$ENV{$_} = $Request->ServerVariables($_)->Item;
	}
}

$VERSION='1.00';

my $ASPOUT = tie *RESPONSE_FH, 'ASP::IO';
select RESPONSE_FH;
$SIG{__WARN__} = sub { ASP::Print(@_) };

sub _END { map { &$_() } @DeathHooks; }

1;
__END__

=head1 NAME

ASP - a Module for ASP (PerlScript) Programming

=head1 SYNOPSIS

	use strict;
	use ASP qw(:strict);

	print "Testing, testing.<BR><BR>";
	my $item = param('item');

	if($item eq 'Select one...') {
	    die "Please select a value from the list.";
	}

	print "You selected $item.";
	exit;

=head1 DESCRIPTION

This module is based on Matt Sergeant's excellent
Win32::ASP module, which can be found at
E<lt>F<http://www.fastnetltd.ndirect.co.uk/Perl>E<gt>.
After using Mr. Sergeant's module, I took on the task of
customizing and optimizing it for my own purposes. Feel
free to use it if you find it useful.

=head1 NOTES

Both of the print() and warn() standard perl funcs are overloaded
to output to the browser. print() is also available via the
$ASP::ASPOUT->print() method call.

$Request->ServerVariables are stuffed in %ENV
to more closely resemble CGI.pm

ASP.pm now exports the $ScriptingNamespace symbol. This symbol
allows PerlScript to call subs/functions written in another script
language. For example:

    <%@ language=PerlScript %>
    <%
        use ASP qw(:strict);
        print $ScriptingNamespace->SomeSub("arg1");
    %>
    <SCRIPT language=VBScript runat=server>
    Function SomeSub (str)
        SomeSub = SomethingThatReturnsSomething()
    End Function
    </SCRIPT>

=head1 INSTALLATION

This module can be installed via my PPM repository at

   http://dichosoft.com/perl

=head1 USE

=head2 use ASP qw(:basic);

Exports basic subs: Print, Warn, die, exit, param, param_count.

=head2 use ASP qw(:strict);

Allows the use of the ASP objects under C<use strict;>.

NOTE: This is not the only way to accomplish this, but I think it's
the cleanest, most convenient way.

=head2 use ASP qw(:all);

Same as C<use ASP;>. Exports all subs except those marked 'not exported'.

=head2 use ASP ();

Overloads print() and warn() and provides the $ASP::ASPOUT object.

=head1 FUNCTION REFERENCE

=head2 warn LIST

C<warn> (or more specifically, the __WARN__ signal) has been re-routed to
output to the browser.

FYI: When implemented, this tweak led to the removal of the prototypes
Matt placed on his subs.

=head2 print LIST

C<print> is overloaded to write to the browser by default. The inherent
behavior of print has not been altered and you can still use an alternate
filehandle as you normally would. This allows you to use print just
as you would in CGI scripts. The following statement would need no
modification between CGI and ASP PerlScript:

    print param('URL'), " was requested by ", $ENV{REMOTE_HOST}, "\n";

=head2 Print LIST

Prints a string or comma separated list of strings to the browser. Use
as if you were using C<print> in a CGI application. Print gets around ASP's
limitations of 128k in a single $Response->Write() call.

NB: C<print> calls Print, so you could use either, but
print more closely resembles perl.

=cut
sub Print {
	for (@_) {
		if ( length($_) > 128000 ) {
			ASP::Print( unpack('a128000a*', $_) );
		} else {
			$main::Response->Write($_);
		}
	}
}

=head2 DebugPrint LIST

Output is displayed between HTML comments so the output doesn't
interfere with page aesthetics.

=cut
sub DebugPrint { ASP::Print("<!--\n", @_, "\n-->"); }

=head2 HTMLPrint LIST

The same as C<Print> except the output is HTML-encoded so that
any HTML tags appear as sent, i.e. E<lt> becomes &lt;, E<gt> becomes &gt; etc.

=cut
sub HTMLPrint { map { ASP::Print($Server->HTMLEncode($_)) } @_ ; }

=head2 die LIST

Prints the contents of LIST to the browser and then exits. die
automatically calls $Response->End for you, it also executes any
cleanup code you have added with C<AddDeathHook>.

=cut
sub die {
	ASP::Print(@_, "</BODY></HTML>");
	_END;
	$main::Response->End();
	CORE::die();
}

=head2 exit

Exits the current script. $Response->End is called automatically for you.
Any cleanup code added with C<AddDeathHook> is also called.

=cut
sub exit {
	_END;
	$main::Response->End();
	CORE::exit();
}

=head2 escape LIST

Escapes (URL-encodes) a list. Uses ASP object method
$Server->URLEncode().

=cut
sub escape { map { $Server->URLEncode($_) } @_; }

=head2 unescape LIST

Unescapes a URL-encoded list. Algorithms ripped from CGI.pm
method of the same name.

=cut
sub unescape {
	map {
		tr/+/ /;
		s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	} @_;
}

=head2 escapeHTML LIST

Escapes a list of HTML. Uses ASP object method $Server->HTMLEncode().

If passed an array reference, escapeHTML will return a reference
to the escaped array.

=cut
sub escapeHTML {
	my ($flag, @args) = (0, @_);
	@args = @{$args[0]} and $flag++ if ref $args[0] eq "ARRAY"; 
	map { $_ = $Server->HTMLEncode($_) } @args;
	$flag ? \@args : @args;
}

=head2 unescapeHTML LIST

Unescapes an HTML-encoded list.

If passed an array reference, unescapeHTML will return a reference
to the un-escaped array.

=cut
sub unescapeHTML {
	my ($flag, @args) = (0, @_);
	@args = @{$args[0]} and $flag++ if ref $args[0] eq "ARRAY"; 
	map {
		s/&amp;/&/gi;
		s/&quot;/"/gi;
		s/&nbsp;/ /gi;
		s/&gt;/>/gi;
		s/&lt;/</gi;
		s/&#(\d+);/chr($1)/ge;
		s/&#x([0-9a-f]+);/chr(hex($1))/gi;
	} @args
	$flag ? \@args : @args;
}

=head2 param EXPR [, EXPR]

=over 4

Simplifies parameter access and makes switch from GET to POST transparent.

Given the following querystring:

	myscript.asp?x=a&x=b&y=c

    param()      returns ('x', 'y')
    param('y')   returns 'c'
    param('x')   returns ('a', 'b')
    param('x',1) returns 'a'
    param('x',2) returns 'b'

=cut
sub param {
	unless (@_) {
		my @keys;
		push( @keys, $_ ) for ( Win32::OLE::in $main::Request->QueryString );
		push( @keys, $_ ) for ( Win32::OLE::in $main::Request->Form );
		return @keys;
	}
	$_[1] = 1 unless defined $_[1];
	unless (wantarray) {
		if ($main::ENV{'REQUEST_METHOD'} eq 'GET') {
			return $main::Request->QueryString($_[0])->Item($_[1]);
		} else {
			return $main::Request->Form($_[0])->Item($_[1]);
		}
	} else {
		my ($i, @ret);
		if ($main::ENV{'REQUEST_METHOD'} eq 'GET') {
			my $count = $main::Request->QueryString($_[0])->{Count};
			for ($i = 1; $i <= $count; $i++ ) {
				push @ret, $main::Request->QueryString($_[0])->Item($i);
			}
		} else {
			my $count = $main::Request->Form($_[0])->{Count};
			for ($i = 1; $i <= $count; $i++) {
				push @ret, $main::Request->Form($_[0])->Item($i);
			}
		}
		return @ret;
	}
}

=head2 param_count EXPR

Returns the number of times EXPR appears in the request (Form or
QueryString).

For example, if URL is

	myscript.asp?x=a&x=b&y=c

then

	param_count('x');

returns 2.

=cut
sub param_count {
	if ($main::('REQUEST_METHOD')->Item eq 'GET') {
		return $main::Request->QueryString($_[0])->{Count};
	} else {
		return $main::Request->Form($_[0])->{Count};
	}
}

=head2 AddDeathHook LIST

Allows cleanup code to be executed when you C<die> or C<exit>.
Useful for closing database connections in the event of a
fatal error.

	<%
	my $conn = Win32::OLE-new('ADODB.Connection');
	$conn->Open("MyDSN");
	$conn->BeginTrans();
	ASP::AddDeathHook( sub { $Conn->Close if $Conn; } );
	%>

Death hooks should be executed on a graceful exit of the script too
but this hasn't been confirmed. If anyone has any luck, let me know.

AddDeathHook is not exported.

=cut
sub AddDeathHook { push @DeathHooks, @_; }

=head2 BinaryWrite LIST

Performs the same function as $Response->BinaryWrite() but gets around
Perl's lack of unicode support, and the null padding it uses to get around
this. Example:

	ASP::BinaryWrite($val);

BinaryWrite is not exported.

=cut
sub BinaryWrite {
	use Win32::OLE::Variant;
	for (@_) {
		if (length($_) > 128000) {
			BinaryWrite ( unpack('a128000a*', $_) );
		} else {
			$main::Response->BinaryWrite(
				Win32::OLE::Variant->new( VT_UI1, $_ )
			);
		}
	}
}

# These two functions are ripped from CGI.pm
sub expire_calc {
    my($time) = @_;
    my(%mult) = ('s'=>1,
                 'm'=>60,
                 'h'=>60*60,
                 'd'=>60*60*24,
                 'M'=>60*60*24*30,
                 'y'=>60*60*24*365);
    # format for time can be in any of the forms...
    # "now" -- expire immediately
    # "+180s" -- in 180 seconds
    # "+2m" -- in 2 minutes
    # "+12h" -- in 12 hours
    # "+1d"  -- in 1 day
    # "+3M"  -- in 3 months
    # "+2y"  -- in 2 years
    # "-3m"  -- 3 minutes ago(!)
    # If you don't supply one of these forms, we assume you are
    # specifying the date yourself
    my $offset;
    if ( !$time || $time eq 'now' ) {
        $offset = 0;
    } elsif ( $time =~ /^([+-]?\d+)([mhdMy]?)/ ) {
        $offset = ($mult{$2} || 1)*$1;
    } else {
        return $time;
    }
    return ($time + $offset);
}

sub date {
	my($time,$format) = @_;
	my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
	my(@WDAY) = qw/Sun Mon Tue Wed Thu Fri Sat/;

	# pass through preformatted dates for the sake of expire_calc()
	return $time if ("$time" =~ m/^[^0-9]/o);

	# make HTTP/cookie date string from GMT'ed time
	# (cookies use '-' as date separator, HTTP uses ' ')
	my($sc) = ' ';
	$sc = '-' if $format eq "cookie";
	my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);
	$year += 1900;
	return sprintf( "%s, %02d$sc%s$sc%04d %02d:%02d:%02d GMT",
		$WDAY[$wday], $mday, $MON[$mon], $year, $hour, $min, $sec );
}

=head2 SetCookie Name, Value [, HASH]

Sets the cookie Name with the value Value. HASH is optional, and contains any of
the following optional parameters:

    -expires => CGI.pm style expires value
    -domain => domain that the cookie is returned to; eg, ".domain.com"
    -path => a path that the cookie is returned to.
    -secure => cookie only returned under SSL if true.

If Value is a hash ref, then it creates a cookie dictionary. (see either
the ASP docs, or my Introduction to PerlScript for more info on Cookie
Dictionaries).

Example:

	ASP::SetCookie("Options", { bg=>'white', text=>'black' }, (
	    -expires => "+3h",
	    -domain => ".dichosoft.com",
	    -path => "/perl",
	    -secure => 0 )
	    );

SetCookie is not exported.

=cut
sub SetCookie {
	my ($name, $value, %hash) = @_;
	if( ref($value) eq 'HASH') {
		$value = join "&", map {$main::Server->URLEncode($_)."=".$main::Server->URLEncode($$value{$_})} keys(%$value);
	}
	$main::Response->AddHeader('Set-Cookie', join("",
		"$name=$value",
		($hash{-path} ? "; path=$hash{-path}" : ""),
		($hash{-domain} ? "; domain=$hash{-domain}" : ""),
		($hash{-secure} ? "; secure" : ""),
		($hash{-expires} ? "; expires=".&date( &expire_calc( $hash{-expires} ) ) : ""),
	) );
}

=head1 AUTHOR

Tim Hammerquist E<lt>F<tim@dichosoft.com>E<gt>

=head1 HISTORY

=over 4

=item Version 1.00

The escapeHTML() and unescapeHTML() functions now accept array refs as well
as lists, as Win32::ASP::HTMLEncode() was supposed to.
Thanks to Matt Sergeant for the fix.

=item Version 0.97

Optimized and debugged.

=item Version 0.77

Overloaded warn() and subsequently removed prototypes.

Exported $ScriptingNamespace object.

Added methods escape(), unescape(), escapeHTML(), unescapeHTML().
Thanks to Bill Odom for pointing these out!

Re-implemented SetCookie and BinaryWrite functions.

=item Version 0.11

Optimized and debugged.

=back

=cut

