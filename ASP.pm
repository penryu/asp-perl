#####################################################################
#
# ASP - Interface for ASP PerlScript and Apache::ASP
#
# Author: Tim Hammerquist
# Revision: 1.08
# NOTES: based on Matt Sergeant's Win32-ASP module.
#
#####################################################################
#
# Copyright 2001 Tim Hammerquist.  All rights reserved.
#
# This file is distributed under the Artistic License.
# See http://www.perl.com/language/misc/Artistic.html or
# the license that comes with your perl distribution.
#
# Contact me at timmy@cpan.org with any comments,
# flames, queries, suggestions, or general curiosity.
#
#####################################################################

require 5.005;
use strict;

my ($APACHE, $WIN32);
$APACHE = $Apache::ASP::VERSION; 
$WIN32  = $^O =~ /win/i;

# IO class for filehandle wrapper
package ASP::IO;
sub TIEHANDLE   { shift->new(@_) }
sub PRINT       { shift->print(@_) }
sub PRINTF      { shift->print(sprintf(@_)) }
sub new { bless {}, shift; }
sub print {
    my $self = shift;
    ASP::Print(@_);
    1;
}

1;

package ASP;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $ASPOUT);

require CGI;

BEGIN {
    require Exporter;

    use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
        $Application $ObjectContext $Request $Response
        $Server $Session $ScriptingNamespace @DeathHooks
        );

    @ISA = qw( Exporter );
    %EXPORT_TAGS =  (
        basic => [qw(
            Print Warn die exit param param_count
            )],
        strict => [qw(
            Print Warn die exit param param_count
            $Application $ObjectContext $Request
            $Response $Server $Session
            $ScriptingNamespace
            )],
        all => [qw(
            Print Warn die exit param param_count
            $Application $ObjectContext $Request
            $Response $Server $Session
            $ScriptingNamespace
            DebugPrint HTMLPrint
            escape unescape escapeHTML unescapeHTML
            )],
    );
    Exporter::export_tags('basic');
    Exporter::export_ok_tags('all');

    $Application = $main::Application;
    $ObjectContext = $main::ObjectContext;
    $Request = $main::Request;
    $Response = $main::Response;
    $Server = $main::Server;
    $Session = $main::Session;
# $ScriptingNamespace var doesn't exist in Apache::ASP
    $ScriptingNamespace = $main::ScriptingNamespace unless $APACHE;

# Fills %ENV hash with environment variables
# Apache::ASP does this automatically
    if ( $WIN32 && !$APACHE ) {
        %ENV = ();
        for (Win32::OLE::in $Request->ServerVariables) {
            $ENV{$_} = $Request->ServerVariables($_)->Item;
        }
    }
}

$VERSION='2.0';

# make RESPONSE_FH default for print() unless using Apache::ASP
$ASPOUT = tie *RESPONSE_FH, 'ASP::IO';
select RESPONSE_FH unless $APACHE;

# attempt to send warn() output to browser
$SIG{__WARN__} = sub { ASP::Print(@_) };

# clear @DeathHooks on each call to _END for Apache::ASP
sub _END { &$_() for  @DeathHooks; @DeathHooks = (); 1; }

=head1 NAME

ASP - Interface for ASP PerlScript and Apache::ASP

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

ASP.pm is a cross-platform module designed to work with both ASP
PerlScript on IIS4, as well as mod_perl/Apache::ASP.

Apache::ASP already provides some of the functionality provided by
this module.  ASP.pm also uses some of CGI.pm's functionality to
provide a consistent ASP.pm interface across platforms.

Because of this (and to avoid redundancy), ASP.pm
attempts to detect its environment. Differences between Apache::ASP
and MS ASP are noted.

NB: ASP.pm does not compromise the user's ability to access
ASP objects directly.

=head1 NOTES

Both of the print() and warn() standard perl funcs are overloaded
to output to the browser. print() is also available via the
$ASP::ASPOUT->print() method call.

$Request->ServerVariables are only stuffed into %ENV on Win32
platforms, as Apache::ASP already provides this.

ASP.pm also exports the $ScriptingNamespace symbol (Win32 only).
This symbol allows PerlScript to call subs/functions written in
another script language. For example:

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

=head1 USE

=head2 use ASP qw(:basic);

Exports basic subs: Print, Warn, die, exit, param, param_count. Same
as C<use ASP;>

=head2 use ASP qw(:strict);

Allows the use of the ASP objects under C<use strict;>.

NOTE: This is not the only way to accomplish this, but I think it's
the cleanest, most convenient way.

=head2 use ASP qw(:all);

Exports all subs except those marked 'not exported'.

=head2 use ASP ();

Overloads print() and warn() and provides the $ASP::ASPOUT object.

=head1 FUNCTION REFERENCE

=head2 warn LIST

C<warn> (or more specifically, the __WARN__ signal) has been re-routed to
output to the browser.

FYI: When implemented, this tweak led to the removal of the prototypes
Matt placed on his subs.

WARNING: On Apache::ASP, the exported warn() function still outputs to
the server error_log, *not* the browser. Use Warn()

=head2 Warn LIST

C<Warn> is an alias for the ASP::Print method described below. The
overloading of C<warn> as described above does not currently work
in Apache::ASP, so this is provided.

=cut
sub Warn {
    ASP::Print(@_);
}

=head2 print LIST

C<print> is overloaded to write to the browser by default. The inherent
behavior of print has not been altered and you can still use an alternate
filehandle as you normally would. This allows you to use print just
as you would in CGI scripts. The following statement would need no
modification between CGI and ASP with ASP.pm:

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
        }
        else {
            $main::Response->Write($_);
        }
    }
}

=head2 DebugPrint LIST

Output is displayed between HTML comments so the output doesn't
interfere with page aesthetics.

=cut
sub DebugPrint {
    ASP::Print("<!--\n", @_, "\n-->");
}

=head2 HTMLPrint LIST

The same as C<Print> except the output is HTML-encoded so that
any HTML tags appear as sent, i.e. E<lt> becomes &lt;, E<gt> becomes &gt; etc.

=cut
sub HTMLPrint {
    map {
        ASP::Print($main::Server->HTMLEncode($_))
    } @_ ;
}

=head2 die LIST

Prints the contents of LIST to the browser and then exits. die
automatically calls $Response->End for you, it also executes any
cleanup code you have added with C<AddDeathHook>.

=cut
sub die {
    ASP::Print(@_, "</BODY></HTML>");
    ASP::exit();
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

=head2 escape STRING

Escapes (URL-encodes) a string. Uses ASP object method
$Server->URLEncode().

=cut
sub escape {
    my $str = shift;
    return $main::Server->URLEncode($str);
}

=head2 unescape STRING

Unescapes a URL-encoded string. Algorithms ripped from CGI.pm
method of the same name.

=cut
sub unescape {
    my $str = shift;
    $str =~ tr/+/ /;
    $str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $str;
}

=head2 escapeHTML STRING

Escapes an HTML string. Uses ASP object method $Server->HTMLEncode().

=cut
sub escapeHTML {
    my $arg = shift;
    return $main::Server->HTMLEncode($arg);
}

=head2 unescapeHTML STRING

Unescapes an HTML-encoded list.

=cut
sub unescapeHTML {
    my $arg = shift;
    for ($arg) {
        s/&amp;/&/gi;
        s/&quot;/"/gi;
        s/&nbsp;/ /gi;
        s/&gt;/>/gi;
        s/&lt;/</gi;
        s/&#(\d+);/chr($1)/ge;
        s/&#x([0-9a-f]+);/chr(hex($1))/gi;
    }
    return $arg;
}

=head2 param EXPR [, EXPR]

Simplifies parameter access and makes switch from GET to POST transparent.

Given the following querystring:

    myscript.asp?x=a&x=b&y=c

    param()      returns ('x', 'y')
    param('y')   returns 'c'
    param('x')   returns ('a', 'b')
    param('x',1) returns 'a'
    param('x',2) returns 'b'

NOTE: Under Apache::ASP, param() simply passes the arguments
to CGI::param() because Apache::ASP doesn't support the $obj->{Count}
property used in this function.

=cut
sub param {
    if ($APACHE) {
        return (wantarray) ? (CGI::param(@_)) : scalar(CGI::param(@_));
    }
    unless (@_) {
        my @keys;
        push( @keys, $_ ) for ( Win32::OLE::in $main::Request->QueryString );
        push( @keys, $_ ) for ( Win32::OLE::in $main::Request->Form );
        return @keys;
    }
    $_[1] = 1 unless defined $_[1];
    unless (wantarray) {
        if ($main::Request->ServerVariables('REQUEST_METHOD')->Item eq 'GET') {
            return $main::Request->QueryString($_[0])->Item($_[1]);
        }
        else {
            return $main::Request->Form($_[0])->Item($_[1]);
        }
    }
    else {
        my ($i, @ret);
        if ($main::Request->ServerVariables('REQUEST_METHOD')->Item eq 'GET') {
            my $count = $main::Request->QueryString($_[0])->{Count};
            for ($i = 1; $i <= $count; $i++ ) {
                push @ret, $main::Request->QueryString($_[0])->Item($i);
            }
        }
        else {
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

NOTE: Under Apache::ASP, param_count() performs some manipulation
using CGI::param() because Apache::ASP doesn't support the
$obj->{Count} property used in this function.

=cut
sub param_count {
    if ($APACHE) {
        return scalar( @{[ CGI::param($_[0]) ]} );
    }
    if ($main::Request->ServerVariables('REQUEST_METHOD')->Item eq 'GET') {
        return $main::Request->QueryString($_[0])->{Count};
    }
    else {
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

Death hooks are not executed except by explicitly calling the die() or exit()
methods provided by ASP.pm.

AddDeathHook is not exported.

=cut
sub AddDeathHook { push @DeathHooks, @_; }

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

=head1 AUTHOR

Tim Hammerquist E<lt>F<tim@dichosoft.com>E<gt>

=head1 HISTORY

=over 4

=item Version 2

(un)?escape(HTML)? functions were misbehaving. At the moment, they
accept and return only a single scalar string. This changed the API
slightly, but they should at least behave in a predictable manner.

Added a two test scripts to be added to distribution. They require a
running ASP/PerlScript or Apache/mod_perl/Apache::ASP server.

=item Version 1.07

Added Warn() because warn() overloading doesn't appear to work
under Apache::ASP.

Was forced to clear @DeathHooks array after calling _END() because
of the persistent state of Apache::ASP holding over contents across
executions.

Removed BinaryWrite(), SetCookie(), and Autoload functionality.

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

=head1 SEE ALSO

ASP::NextLink(3)

=cut
1;
__END__
