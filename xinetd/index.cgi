#!/usr/local/bin/perl
# index.cgi
# Display all xinetd services

require './xinetd-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("xinetd", "man", "doc", "google"));

# Check for config file
if (!-r $config{'xinetd_conf'}) {
	print "<p>",&text('index_econf', "<tt>$config{'xinetd_conf'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@conf = &get_xinetd_config();
($defs) = grep { $_->{'name'} eq 'defaults' } @conf;
foreach $m (@{$defs->{'members'}}) {
	$ddisable{$m->{'value'}}++ if ($m->{'name'} eq 'disabled');
	}

# Show table header
print "<form action=mass_enable.cgi method=post>\n";
@links = ( &select_all_link("serv"),
	   &select_invert_link("serv"),
	   "<a href='edit_serv.cgi?new=1'>$text{'index_add_inet'}</a>" );
print &ui_links_row(\@links);
@tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'index_name'},
			  $text{'index_type'},
			  $text{'index_port'},
			  $text{'index_proto'},
			  $text{'index_user'},
			  $text{'index_server'},
			  $text{'index_enabled'} ], 100, 0, \@tds);

# Show one row for each service
foreach $x (@conf) {
	next if ($x->{'name'} ne 'service');
	local $q = $x->{'quick'};
	local @s;
	if ($q->{'type'}->[0] eq 'UNLISTED') {
		# Port and protocol specified
		@s = ( $x->{'name'}, undef, $q->{'port'}->[0],
		       $q->{'protocol'}->[0] );
		}
	elsif ($q->{'protocol'}) {
		# Protocol specified, find port from service
		if ($config{'lookup_servs'}) {
			@s = getservbyname($x->{'value'}, $q->{'protocol'}->[0]);
			}
		if (!@s) {
			@s = ( $x->{'name'}, undef, $q->{'port'}->[0],
			       $q->{'protocol'}->[0] );
			}
		}
	else {
		# Only service specified, check protocols based on socket type,
		# or failing that all protocols
		if ($config{'lookup_servs'}) {
			local @protos;
			if ($q->{'socket_type'}->[0] eq 'stream') {
				@protos = ( 'tcp' );
				}
			elsif ($q->{'socket_type'}->[0] eq 'dgram') {
				@protos = ( 'udp' );
				}
			else {
				@protos = &list_protocols();
				}
			foreach $p (@protos) {
				@s = getservbyname($x->{'value'}, $p);
				last if (@s);
				}
			}
		}
	local @cols;
	push(@cols, "<a href='edit_serv.cgi?idx=$x->{'index'}'>".
		    &html_escape($x->{'value'})."</a>");
	push(@cols, &indexof('RPC', @{$q->{'type'}}) < 0 ?
		     $text{'index_inet'} : $text{'index_rpc'});
	if (@s) {
		push(@cols, &html_escape($s[2]) ||
			     "<i>$text{'index_noport'}</i>");
		push(@cols, &html_escape(uc($s[3])));
		}
	else {
		push(@cols, "<i>$text{'index_noport'}</i>", "");
		}
	push(@cols, $q->{'user'} ? &html_escape($q->{'user'}->[0]) : "");
	push(@cols, &indexof('INTERNAL', @{$q->{'type'}}) >= 0 ?
		     $text{'index_internal'} : $q->{'redirect'} ?
		     &text('index_redirect', "<tt>".&html_escape($q->{'redirect'}->[0])."</tt>") :
		     &html_escape($q->{'server'}->[0]));
	$id = $q->{'id'}->[0] || $x->{'value'};
	push(@cols, $q->{'disable'}->[0] eq 'yes' || $ddisable{$id} ?
	      "<font color=#ff0000>$text{'no'}</font>" : $text{'yes'});
	print &ui_checked_columns_row(\@cols, \@tds, "serv", $x->{'index'});
	}
print &ui_columns_end();
print &ui_links_row(\@links);

print "<input type=submit name=enable value='$text{'index_enable'}'>\n";
print "<input type=submit name=disable value='$text{'index_disable'}'>\n";
print "</form>\n";

print &ui_hr();

print &ui_buttons_start();
print &ui_buttons_row("edit_defaults.cgi", $text{'index_defaults'},
		      $text{'index_defaultsmsg'});

if ($pid = &is_xinetd_running()) {
	print &ui_buttons_row("restart.cgi", $text{'index_apply'},
			      $text{'index_applymsg'});
	}
else {
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startmsg'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

