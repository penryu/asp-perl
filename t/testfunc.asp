<%
use strict;
use ASP;
%>
<HTML>
<HEAD>
    <TITLE>ASP-<%= $ASP::VERSION %> Test 2</TITLE>
</HEAD>
<BODY>
<PRE>
Testing param():
    parameters: <%= join(", ", param() ) %>
    values:
<% print map {"        $_=@{[param($_)]}\n"} param() ; %>
Testing param_count():
<%
for my $var (param) {
    print "$var appears @{[param_count($var)]} time(s).\n";
    print "    $var = @{[param($var)]}\n";
}
%>
Testing warn(): (check error logs if nothing appears)
    <% warn "warn() works"; %>

Testing Warn():
    <% Warn "Warn() works"; %>

Testing print():
    <% print "print() works"; %>

Testing Print():
    <% Print "Print() works"; %>

Testing DebugPrint() (view source to verify):
    <% ASP::DebugPrint "DebugPrint works if this is commented out"; %>

Testing HTMLPrint():
    <% ASP::HTMLPrint "<B><I>ASP::HTMLPrint worked unless this is bold or italic.</I></B>"; %>

Testing escape("Boyle's Hell.doc"):
    <%= ASP::escape("Boyle's Hell.doc") %>

Testing unescape( escape("Boyle's Hell.doc") ):
    <%= ASP::unescape(ASP::escape "Boyle's Hell.doc") %>

Testing escapeHTML() on a tiny, one-cell table:
    <%= ASP::escapeHTML("<TABLE><TR><TD>Hi!</TD></TR></TABLE>") %>

Testing unescapeHTML() on output of escapeHTML(): (works if table appears)
    <%= ASP::unescapeHTML(
        ASP::escapeHTML("<TABLE><TR><TD>Hi!</TD></TR></TABLE>")
        ) %>

Testing AddDeathHook(): (check error_log)
    <% ASP::AddDeathHook( sub { warn "AddDeathHook called.\n" } ); %>

Testing %ENV: (mainly for Win32 servers)
<% print map {"    '$_'='$ENV{$_}'\n"} sort keys %ENV; %>

Testing die() (die() calls exit()):
</PRE>
<% die "die() worked if source contains &lt;/BODY&gt;&lt;/HTML&gt;"; %>
