#!/usr/local/bin/perl
# Display entries in the auto-whitelist
# XXX delete all

require './spam-lib.pl';
&can_use_check("awl");
&ui_print_header(undef, $text{'awl_title'}, "");
&ReadParse();
$formno = 0;

# Check if we need a username
if (&supports_auto_whitelist() == 2) {
	print &ui_form_start("edit_awl.cgi");
	print "<b>$text{'awl_user'}</b>\n";
	print &ui_user_textbox("user", $in{'user'}),"\n",
	      &ui_submit($text{'awl_uok'});
	print &ui_form_end();

	if (!$in{'user'}) {
		# Can't do any more
		&ui_print_footer("", $text{'index_return'});
		return;
		}
	}

# Open the DBM, or give up
$awf = &get_auto_whitelist_file($in{'user'});
$ok = &open_auto_whitelist_dbm($in{'user'});
if (!&can_edit_awl($in{'user'})) {
	&ui_print_endpage("<b>".&text('awl_cannotuser',
		"<tt>".&html_escape($in{'user'})."</tt>")."</b>");
	}
elsif (!defined(getpwnam($in{'user'}))) {
	&ui_print_endpage("<b>".&text('awl_nouser',
		"<tt>".&html_escape($in{'user'})."</tt>")."</b>");
	}
elsif (!$awf) {
	&ui_print_endpage("<b>".&text('awl_nofile',
		"<tt>".&html_escape($in{'user'})."</tt>")."</b>");
	}
elsif ($ok == 0) {
	&ui_print_endpage("<b>".&text('awl_cannot', $awf)."</b>");
	}
elsif ($ok < 0) {
	&ui_print_endpage("<b>".&text('awl_empty', $awf)."</b>");
	}

# Show search form
@keys = sort { $a cmp $b } keys %awl;
@keys = grep { !/\|totscore/ } @keys;
print &ui_form_start("edit_awl.cgi");
print "<b>$text{'awl_search'}</b>\n";
print &ui_textbox("search", $in{'search'}, 30),"\n",
      &ui_submit($text{'awl_ok'});
print &ui_hidden("user", $in{'user'});
print &ui_form_end();
$formno++;
if ($in{'search'}) {
	@keys = grep { /\Q$in{'search'}\E/i } @keys;
	print &text('awl_searching',
		    "<i>".&html_escape($in{'search'})."</i>"),"<p>\n";
	}

if (@keys > $max_awl_keys && !$in{'search'}) {
	# Too many to show
	print "<b>",&text('awl_toomany', scalar(@keys),
			  $max_awl_keys),"</b><p>\n";
	}
else {
	# Show table
	print &ui_form_start("delete_awl.cgi", "post");
	print &ui_hidden("search", $in{'search'});
	print &ui_hidden("user", $in{'user'});
	@links = ( &select_all_link("d", $formno),
		   &select_invert_link("d", $formno) );
	@tds = ( "width=5" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'awl_email'},
				  $text{'awl_ip'},
				  $text{'awl_score'} ], \@tds);
	foreach $k (@keys) {
		($email, $ip, $rest) = split(/\|/, $k);
		if ($ip eq "ip=none") {
			$ip = $text{'awl_none'};
			}
		elsif ($ip =~ /^ip=(\S+)$/) {
			$ip = $1;
			}
		else {
			$ip = $text{'awl_unknown'};
			}
		print &ui_checked_columns_row([ $email, $ip, $awl{$k} ],
					      \@tds, "d", $k);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'awl_delete'} ] ]);
	}
&close_auto_whitelist_dbm();

# Show delete buttons
print "<hr>\n";
print &ui_buttons_start();
if ($in{'user'} || &supports_auto_whitelist() == 1) {
	# Delete for this user
	print &ui_buttons_row("deleteone_awl.cgi",
		      $text{'awl_deleteone'}, &text('awl_deleteonedesc',
				"<tt>".&html_escape($in{'user'})."</tt>"),
		      &ui_hidden("user", $in{'user'}));
	}
if (&supports_auto_whitelist() == 2) {
	# Delete for all users
	print &ui_buttons_row("deleteall_awl.cgi",
		      $text{'awl_deleteall'}, $text{'awl_deletealldesc'});
	}
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});
