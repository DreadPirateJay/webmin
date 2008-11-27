#!/usr/local/bin/perl
# edit_mon.cgi
# Display a form for editing or creating a monitor

require './status-lib.pl';
$access{'edit'} || &error($text{'mon_ecannot'});
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
@handlers = &list_handlers();
if ($in{'type'}) {
	# Create a new monitor
	$type = $in{'type'};
	$title = $text{'mon_create'};
	if ($in{'clone'}) {
		# Clone of existing
		$serv = &get_service($in{'clone'});
		}
	else {
		# Totally new
		$serv = { 'notify' => 'email pager snmp sms',
			  'fails' => 1,
			  'nosched' => 0,
			  'remote' => '*' };
		}
	}
else {
	# Editing an existing monitor
	$serv = &get_service($in{'id'});
	$type = $serv->{'type'};
	$title = $text{'mon_edit'};
	}
($han) = grep { $_->[0] eq $type } @handlers;
if ($in{'type'} && !$in{'clone'}) {
	$serv->{'desc'} = $han->[1];
	}
&ui_print_header($han->[1], $title, "");

print &ui_form_start("save_mon.cgi", "post");
print &ui_hidden("type", $in{'type'}),"\n";
print &ui_hidden("id", $in{'id'}),"\n";
@tds = ( "width=30%" );
print &ui_table_start($text{'mon_header'}, "width=100%", 2, \@tds);

# Check for clone modules of the monitor type
if (-d "../$type") {
	local @st = stat("../$type");
	opendir(DIR, "..");
	foreach $m (readdir(DIR)) {
		local @lst = stat("../$m");
		if (-l "../$m" && $st[1] == $lst[1]) {
			# found a clone
			push(@clones, $m);
			}
		}
	}

# Show input for description
print &ui_table_row($text{'mon_desc'},
		    &ui_textbox("desc", $serv->{'desc'}, 50),
		    undef, \@tds);

# Show current status
if (!$in{'type'}) {
	@stats = &service_status($serv, 1);
	$stable = "<table cellpadding=1 cellspacing=1>\n";
	foreach $stat (@stats) {
		$stable .= "<tr>\n";
		if (@stats > 1 || $stat->{'remote'} ne "*") {
			$stable .=
			    "<td>".
			    ($stat->{'remote'} eq "*" ? $text{'mon_local'}
						      : $stat->{'remote'}).
			    "</td>\n";
			$stable .= "<td>:</td>\n";
			}
		$stable .= "<td>".
		      ($stat->{'desc'} ? $stat->{'desc'} :
		       $stat->{'up'} == 1 ? $text{'mon_up'} :
		       $stat->{'up'} == -1 ? $text{'mon_not'} :
		       $stat->{'up'} == -2 ? $text{'mon_webmin'} :
		       $stat->{'up'} == -3 ? $text{'mon_timeout'} :
		       $stat->{'up'} == -4 ? $text{'mon_skip'} :
			 "<font color=#ff0000>$text{'mon_down'}</font>").
			"</td>\n";
		$stable .= "</tr>\n";
		}
	$stable .= "</table>\n";
	print &ui_table_row($text{'mon_status'}, $stable,
			    undef, \@tds);
	}

# Show servers to run on
@servs = grep { $_->{'user'} } &servers::list_servers_sorted();
@servs = sort { $a->{'host'} cmp $b->{'host'} } @servs;
if (@servs) {
	# Show list of remote servers, and maybe groups
	$s = &ui_select("remotes", [ split(/\s+/, $serv->{'remote'}) ],
			 [ [ "*", "&lt;$text{'mon_local'}&gt;" ],
			   map { [ $_->{'host'}, $_->{'host'} ] } @servs ],
			 5, 1, 1),
	@groups = &servers::list_all_groups(\@servs);
	@groups = sort { $a->{'name'} cmp $b->{'name'} } @groups;
	if (@groups) {
		$s .= &ui_select("groups", [ split(/\s+/, $serv->{'groups'}) ],
			 [ map { [ $_->{'name'}, &group_desc($_) ] } @groups ],
			 5, 1, 1),
		}
	print &ui_table_row($text{'mon_remotes2'}, $s, undef, \@tds);
	}
else {
	# Only local is available
	print &ui_hidden("remotes", "*"),"\n";
	}

# Show emailing schedule
print &ui_table_row($text{'mon_nosched'},
		    &ui_select("nosched", int($serv->{'nosched'}),
			       [ [ 1, $text{'no'} ],
				 [ 0, $text{'mon_warndef'} ],
				 [ 3,  $text{'mon_warn1'} ],
				 [ 2,  $text{'mon_warn0'} ],
				 [ 4,  $text{'mon_warn2'} ],
				 [ 5,  $text{'mon_warn3'} ] ]),
		    undef, \@tds);

# Show number of failures
print &ui_table_row($text{'mon_fails'},
		    &ui_textbox("fails", $serv->{'fails'}, 5),
		    undef, \@tds);

# Show notification mode
$notify = "";
%notify = map { $_, 1 } split(/\s+/, $serv->{'notify'});
foreach $n (&list_notification_modes()) {
	$notify .= &ui_checkbox("notify", $n, $text{'mon_notify'.$n},
				$notify{$n})."\n";
	delete($notify{$n});
	}
foreach $n (keys %notify) {
	# Don't clear set but un-usable modes
	print &ui_hidden("notify", $n);
	}
print &ui_table_row($text{'mon_notify'}, $notify,
		    undef, \@tds);

# Show extra address to email
print &ui_table_row($text{'mon_email'},
		    &ui_textbox("email", $serv->{'email'}, 60),
		    undef, \@tds);

# Show template to use
@tmpls = &list_templates();
if (@tmpls) {
	if ($in{'type'}) {
		($deftmpl) = grep { $_->{'desc'} eq $config{'def_tmpl'}} @tmpls;
		if ($deftmpl) {
			$tid = $deftmpl->{'id'};
			}
		}
	else {
		$tid = $serv->{'tmpl'};
		}
	print &ui_table_row($text{'mon_tmpl'},
		&ui_select("tmpl", $tid,
			   [ [ "", "&lt;$text{'mon_notmpl'}&gt;" ],
			     map { [ $_->{'id'}, $_->{'desc'} ] } @tmpls ]));
	}

# Which clone module to use
if (@clones) {
	local %minfo = &get_module_info($type);
	print &ui_table_row($text{'mon_clone'},
		   &ui_select("clone", $serv->{'clone'},
			      [ [ "", $minfo{'desc'} ],
				map { local %cminfo = &get_module_info($_);
				      [ $_, $cminfo{'desc'} ] } @clones ]),
		   undef, \@tds);
	}

# Skip if some other monitor is down
@servs = &list_services();
if (@servs) {
	print &ui_table_row($text{'mon_depend'},
	  &ui_select("depend", $serv->{'depend'},
		 [ [ "", "&nbsp;" ],
		   map { [ $_->{'id'}, $_->{'desc'}.
				       " (".&nice_remotes($_).")" ] }
		     sort { $a->{'desc'} cmp $b->{'desc'} } @servs ]),
	  undef, \@tds);
	}

print &ui_table_end();
print "<p>\n";
print &ui_table_start($text{'mon_header2'}, "width=100%", 2, \@tds);

# Show commands to run on up/down
print &ui_table_row($text{'mon_ondown'},
		    &ui_textbox("ondown", $serv->{'ondown'}, 60),
		    undef, \@tds);

print &ui_table_row($text{'mon_onup'},
		    &ui_textbox("onup", $serv->{'onup'}, 60),
		    undef, \@tds);

print &ui_table_row(" ", "<font size=-1>$text{'mon_oninfo'}</font>",
		    undef, \@tds);

# Radio button for where to run commands
print &ui_table_row($text{'mon_runon'},
		    &ui_radio("runon", $serv->{'runon'} ? 1 : 0,
			      [ [ 0, $text{'mon_runon0'} ],
				[ 1, $text{'mon_runon1'} ] ]),
		    undef, \@tds);

print &ui_table_end();

# Display inputs for this monitor type
if ($type =~ /^(\S+)::(\S+)$/) {
	# From another module
	($mod, $mtype) = ($1, $2);
	&foreign_require($mod, "status_monitor.pl");
	print "<p>\n";
	print &ui_table_start($text{'mon_header3'}, "width=100%", 4,
			      \@tds);
	print &foreign_call($mod, "status_monitor_dialog", $mtype, $serv);
	print &ui_table_end();
	}
else {
	# From this module
	do "./${type}-monitor.pl";
	$func = "show_${type}_dialog";
	if (defined(&$func)) {
		print "<p>\n";
		print &ui_table_start($text{'mon_header3'}, "width=100%", 4,
				      \@tds);
		&$func($serv);
		print &ui_table_end();
		}
	}

# Show create/delete buttons
if ($in{'type'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "newclone", $text{'mon_clone2'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

