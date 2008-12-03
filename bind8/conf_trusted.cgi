#!/usr/local/bin/perl
# Show a form for setting up DNSSEC verification and trusted keys
# XXX quick button to setup defaults?

require './bind8-lib.pl';
&ReadParse();
$access{'defaults'} || &error($text{'trusted_ecannot'});
&ui_print_header(undef, $text{'trusted_title'}, "",
		 undef, undef, undef, undef, &restart_links());
$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

print &ui_form_start("save_trusted.cgi");
print &ui_table_start($text{'trusted_header'}, undef, 2);

# DNSSEC enabled?
print &choice_input($text{'trusted_dnssec'}, 'dnssec-enable', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);

# Trusted DLVs
@dtable = ( );
$i = 0;
foreach $d (&find("dnssec-lookaside", $mems),
	    { 'values' => [ '.' ] }) {
	$dlv = $d->{'values'}->[0];
	$dlv = "" if ($dlv eq ".");
	push(@dtable, [ &ui_opt_textbox("anchor_$i", $d->{'values'}->[2],
					30, $text{'trusted_none'}),
			&ui_opt_textbox("dlv_$i", $dlv, 20,
					$text{'trusted_root'}) ]);
	$i++;
	}
print &ui_table_row($text{'trusted_dlvs'},
	&ui_columns_table([ $text{'trusted_anchor'}, $text{'trusted_dlv'} ],
			  undef,
			  \@dtable), 3);

# Trusted keys
@ktable = ( );
$tkeys = &find("trusted-keys", $conf);
$tkeys ||= { 'members' => [ ] };
$i = 0;
foreach $k (@{$tkeys->{'members'}}, { }) {
	@v = @{$k->{'values'}};
	push(@ktable, [ &ui_opt_textbox("zone_$i", $k->{'name'}, 20,
					$text{'trusted_none'}),
		 	&ui_textbox("flags_$i", $v[0], 6),
		 	&ui_textbox("proto_$i", $v[1], 6),
		 	&ui_textbox("alg_$i", $v[2], 6),
			&ui_textarea("key_$i", $v[3], 4, 30, "hard") ]);
	$i++;
	}
print &ui_table_row($text{'trusted_keys'},
	&ui_columns_table([ $text{'trusted_zone'}, $text{'trusted_flags'},
			    $text{'trusted_proto'}, $text{'trusted_alg'},
			    $text{'trusted_key'} ],
			  undef,
			  \@ktable), 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
