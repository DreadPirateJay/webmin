# solaris-lib.pl
# Networking functions for solaris

$min_virtual_number = 1;

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local(@rv, @lines, $l);
&open_execute_command(IFC, "ifconfig -a", 1, 1);
while(<IFC>) {
	s/\r|\n//g;
	if (/^\S+:/) { push(@lines, $_); }
	else { $lines[$#lines] .= $_; }
	}
close(IFC);
foreach $l (@lines) {
	local %ifc;
	$l =~ /^([^:\s]+):/; $ifc{'name'} = $1;
	$l =~ /^(\S+):/; $ifc{'fullname'} = $1;
	if ($l =~ /inet6\s+(\S+)/) { next; }	# skip IPv6 for now
	if ($l =~ /^(\S+):(\d+):\s/) { $ifc{'virtual'} = $2; }
	if ($l =~ /inet\s+(\S+)/) { $ifc{'address'} = $1; }
	if ($l =~ /netmask\s+(\S+)/) { $ifc{'netmask'} = &parse_hex($1); }
	if ($l =~ /broadcast\s+(\S+)/) { $ifc{'broadcast'} = $1; }
	if ($l =~ /ether\s+(\S+)/) { $ifc{'ether'} = $1; }
	if ($l =~ /mtu\s+(\S+)/) { $ifc{'mtu'} = $1; }
	if ($l =~ /zone\s+(\S+)/) { $ifc{'zone'} = $1; }
	$ifc{'up'}++ if ($l =~ /\<UP/);
	$ifc{'edit'} = ($ifc{'name'} !~ /ipdptp|ppp/ && !$ifc{'zone'});
	$ifc{'index'} = scalar(@rv);
	if ($ifc{'ether'}) {
		$ifc{'ether'} = join(":", map { sprintf "%2.2X", hex($_) }
					      split(/:/, $ifc{'ether'}));
		}
	push(@rv, \%ifc);
	}
return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
local $a = $_[0];
local @active = &active_interfaces();
local ($already) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @active;
if (!$already) {
	if ($a->{'virtual'} eq "") {
		local $out = &backquote_logged("ifconfig $a->{'name'} plumb 2>&1");
		if ($out) { &error(&text('aifc_eexist', $a->{'name'})); }
		}
	elsif ($gconfig{'os_version'} >= 8) {
		&system_logged("ifconfig $a->{'name'}:$a->{'virtual'} plumb >/dev/null 2>&1");
		}
	}
local $cmd = "ifconfig $a->{'name'}";
if ($a->{'virtual'} ne "") { $cmd .= ":$a->{'virtual'}"; }
$cmd .= " $a->{'address'}";
if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
else { $cmd .= " netmask +"; }
if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
else { $cmd .= " broadcast +"; }
if ($a->{'mtu'}) { $cmd .= " mtu $a->{'mtu'}"; }
if ($a->{'zone'}) { $cmd .= " zone $a->{'zone'}"; }
if ($a->{'up'}) { $cmd .= " up"; }
else { $cmd .= " down"; }
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error("$cmd : $out"); }
if ($a->{'ether'}) {
	$out = &backquote_logged(
		"ifconfig $a->{'name'} ether $a->{'ether'} 2>&1");
	if ($? && $out !~ /Device busy/) { &error($out); }
	}
}

# deactivate_interface(&details)
# Deactive an interface
sub deactivate_interface
{
local $a = $_[0];
local $cmd;
if ($a->{'virtual'} eq "") {
	$cmd = "ifconfig $a->{'name'} unplumb";
	}
elsif ($gconfig{'os_version'} >= 8) {
	$cmd = "ifconfig $a->{'name'}:$a->{'virtual'} unplumb";
	}
else {
	$cmd = "ifconfig $a->{'name'}:$a->{'virtual'} 0.0.0.0 down";
	}
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }
}

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local (@rv, $f, %mask);
push(@rv, { 'name' => 'lo0',
	    'fullname' => 'lo0',
	    'address' => '127.0.0.1',
	    'netmask' => '255.0.0.0',
	    'up' => 1,
	    'edit' => 0 });
local $etc = &translate_filename("/etc");
opendir(ETC, $etc);
while($f = readdir(ETC)) {
	if ($f =~ /^hostname\.(\S+):(\d+)$/ || $f =~ /^hostname\.(\S+)/) {
		local %ifc;
		$ifc{'fullname'} = $ifc{'name'} = $1;
		$ifc{'virtual'} = $2 if (defined($2));
		$ifc{'fullname'} .= ":$2" if (defined($2));
		$ifc{'index'} = scalar(@rv);
		$ifc{'edit'}++;
		$ifc{'file'} = "$etc/$f";
		open(FILE, "$etc/$f");
		chop($ifc{'address'} = <FILE>);
		close(FILE);
		if ($ifc{'address'}) {
			$ifc{'netmask'} = &automatic_netmask($ifc{'address'});
			$ifc{'broadcast'} = &compute_broadcast($ifc{'address'},
							       $ifc{'netmask'});
			}
		else {
			$ifc{'dhcp'}++;
			}
		$ifc{'up'}++;
		push(@rv, \%ifc);
		}
	}
closedir(ETC);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&open_lock_tempfile(IFACE, ">/etc/hostname.$name");
if (!$_[0]->{'dhcp'}) {
	&print_tempfile(IFACE, $_[0]->{'address'},"\n");
	}
&close_tempfile(IFACE);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&unlink_logged("/etc/hostname.$name");
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
return "Fast Ethernet" if ($_[0] =~ /^hme/);
return "Loopback" if ($_[0] =~ /^lo/);
return "Token Ring" if ($_[0] =~ /^tr/);
return "PPP" if ($_[0] =~ /^ipdptp/ || $_[0] =~ /^ppp/);
return "Ethernet";
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return $_[0] !~ /^(lo|ipdptp|ppp)/;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] eq "dhcp";
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return 1 if (&check_ipaddress($_[0]));
return gethostbyname($_[0]) ? 1 : 0;
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
{
local $dns;
&open_readfile(RESOLV, "/etc/resolv.conf");
while(<RESOLV>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/nameserver\s+(.*)/) {
		push(@{$dns->{'nameserver'}}, split(/\s+/, $1));
		}
	elsif (/domain\s+(\S+)/) {
		$dns->{'domain'} = [ $1 ];
		}
	elsif (/search\s+(.*)/) {
		$dns->{'domain'} = [ split(/\s+/, $1) ];
		}
	}
close(RESOLV);
&open_readfile(SWITCH, "/etc/nsswitch.conf");
while(<SWITCH>) {
	s/\r|\n//g;
	if (/hosts:\s+(.*)/) {
		$dns->{'order'} = $1;
		}
	}
close(SWITCH);
$dns->{'files'} = [ "/etc/resolv.conf", "/etc/nsswitch.conf" ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf and nsswitch.conf files
sub save_dns_config
{
&lock_file("/etc/resolv.conf");
&open_readfile(RESOLV, "/etc/resolv.conf");
local @resolv = <RESOLV>;
close(RESOLV);
&open_tempfile(RESOLV, ">/etc/resolv.conf");
foreach (@{$_[0]->{'nameserver'}}) {
	&print_tempfile(RESOLV, "nameserver $_\n");
	}
if ($_[0]->{'domain'}) {
	if ($_[0]->{'domain'}->[1]) {
		&print_tempfile(RESOLV, "search ",join(" ", @{$_[0]->{'domain'}}),"\n");
		}
	else {
		&print_tempfile(RESOLV, "domain $_[0]->{'domain'}->[0]\n");
		}
	}
foreach (@resolv) {
	&print_tempfile(RESOLV, $_) if (!/^\s*(nameserver|domain|search)\s+/);
	}
&close_tempfile(RESOLV);
&unlock_file("/etc/resolv.conf");

&lock_file("/etc/nsswitch.conf");
&open_readfile(SWITCH, "/etc/nsswitch.conf");
local @switch = <SWITCH>;
close(SWITCH);
&open_tempfile(SWITCH, ">/etc/nsswitch.conf");
foreach (@switch) {
	if (/hosts:\s+/) {
		&print_tempfile(SWITCH, "hosts:\t$_[0]->{'order'}\n");
		}
	else {
		&print_tempfile(SWITCH, $_);
		}
	}
&close_tempfile(SWITCH);
&unlock_file("/etc/nsswitch.conf");
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
return &common_order_input("order", $_[0]->{'order'},
	[ [ "files", "Hosts" ], [ "dns", "DNS" ], [ "nis", "NIS" ],
	  [ "nisplus", "NIS+" ], [ "ldap", "LDAP" ] ]);
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
if (defined($in{'order'})) {
	$in{'order'} =~ /\S/ || &error($text{'dns_eorder'});
	$_[0]->{'order'} = $in{'order'};
	}
else {
	local($i, @order);
	for($i=0; defined($in{"order_$i"}); $i++) {
		push(@order, $in{"order_$i"}) if ($in{"order_$i"});
		}
	$_[0]->{'order'} = join(" ", @order);
	}
}

# get_hostname()
sub get_hostname
{
local $hn = &read_file_contents("/etc/nodename");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
&system_logged("hostname $_[0] >/dev/null 2>&1");
if (-r "/etc/nodename") {
	&open_tempfile(NODENAME, ">/etc/nodename");
	&print_tempfile(NODENAME, $_[0],"\n");
	&close_tempfile(NODENAME);
	}
undef(@main::get_system_hostname);      # clear cache
}

# get_domainname()
sub get_domainname
{
local $d;
&execute_command("domainname", undef, \$d, undef);
chop($d);
return $d;
}

# save_domainname(domain)
sub save_domainname
{
&system_logged("domainname ".quotemeta($_[0]));
&lock_file("/etc/defaultdomain");
if ($_[0]) {
	&open_tempfile(DOMAIN, ">/etc/defaultdomain");
	&print_tempfile(DOMAIN, $_[0],"\n");
	&close_tempfile(DOMAIN);
	}
else {
	&unlink_file("/etc/defaultdomain");
	}
&unlock_file("/etc/defaultdomain");
}

sub routing_config_files
{
return ( "/etc/defaultrouter", "/etc/notrouter", "/etc/gateways" );
}

# get_defaultrouters()
# Returns a list of all default routers
sub get_defaultrouters
{
local @defrt;
&open_readfile(DEFRT, "/etc/defaultrouter");
while(<DEFRT>) {
	s/#.*$//g;
	if (/(\S+)/) { push(@defrt, $1); }
	}
close(DEFRT);
return @defrt;
}

sub routing_input
{
# show default router(s) input
local @defrt = &get_defaultrouters();
print &ui_table_row($text{'routes_defaults'},
	&ui_textarea("defrt", join("\n", @defrt), 3, 40));

# show router input
local $notrt = (-r "/etc/notrouter");
local $gatew = (-r "/etc/gateways");
print &ui_table_row($text{'routes_forward'},
	&ui_radio("router", $gatew && !$notrt ? 0 :
			    !$gatew && !$notrt ? 1 : 2,
		  [ [ 0, $text{'yes'} ],
		    [ 1, $text{'routes_possible'} ],
		    [ 2, $text{'no'} ] ]));
}

sub parse_routing
{
local @defrt = split(/\s+/, $in{'defrt'});
foreach $d (@defrt) {
	gethostbyname($d) || &error(&text('routes_edefault', $d));
	}
&lock_file("/etc/defaultrouter");
if (@defrt) {
	&open_tempfile(DEFRT, ">/etc/defaultrouter");
	foreach $d (@defrt) { &print_tempfile(DEFRT, $d,"\n"); }
	&close_tempfile(DEFRT);
	}
else {
	&unlink_file("/etc/defaultrouter");
	}
&unlock_file("/etc/defaultrouter");

&lock_file("/etc/gateways");
&lock_file("/etc/notrouter");
if ($in{'router'} == 0) {
	&create_empty_file("/etc/gateways");
	&unlink_file("/etc/notrouter");
	}
elsif ($in{'router'} == 2) {
	&create_empty_file("/etc/notrouter");
	&unlink_file("/etc/gateways");
	}
else {
	&unlink_file("/etc/gateways");
	&unlink_file("/etc/notrouter");
	}
&unlock_file("/etc/gateways");
&unlock_file("/etc/notrouter");
}

# create_empty_file(filename)
sub create_empty_file
{
if (!-r $_[0]) {
	&open_tempfile(EMPTY,">$_[0]");
	&close_tempfile(EMPTY);
	}
}

sub os_feedback_files
{
opendir(DIR, "/etc");
local @f = map { "/etc/$_" } grep { /^hostname\./ } readdir(DIR);
closedir(DIR);
return ( @f, "/etc/netmasks", "/etc/resolv.conf", "/etc/nsswitch.conf",
	 "/etc/defaultrouter", "/etc/notrouter", "/etc/gateways" );
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) boot time
# settings.
sub get_default_gateway
{
local @defrt = &get_defaultrouters();
return @defrt ? ( $defrt[0] ) : ( );
}

# set_default_gateway(gateway, device)
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
&lock_file("/etc/defaultrouter");
if ($_[0]) {
	&open_tempfile(DEF, ">/etc/defaultrouter");
	&print_tempfile(DEF, $_[0],"\n");
	&close_tempfile(DEF);
	}
else {
	&unlink_file("/etc/defaultrouter");
	}
&unlock_file("/etc/defaultrouter");
}

# list_routes()
# Returns a list of active routes
sub list_routes
{
local @rv;
&open_execute_command(ROUTES, "netstat -rn", 1, 1);
while(<ROUTES>) {
	s/\s+$//;
	if (/^([0-9\.]+|default)\s+([0-9\.]+)\s+\S+\s+\S+\s+\S+(\s+(\S+))?$/) {
		local $r = { 'dest' => $1 eq "default" ? "0.0.0.0" : $1,
			     'gateway' => $2,
			     'iface' => $4 };
		$r->{'netmask'} = $r->{'dest'} eq '0.0.0.0' ? undef :
				  $r->{'dest'} =~ /\.0\.0\.0$/ ? "255.0.0.0" :
				  $r->{'dest'} =~ /\.0\.0$/ ? "255.255.0.0" :
				  $r->{'dest'} =~ /\.0$/ ? "255.255.255.0" :
							   undef;
		push(@rv, $r);
		}
	}
close(ROUTES);
return @rv;
}

# delete_route(&route)
# Delete one active route, as returned by list_routes. Returns an error message
# on failure, or undef on success
sub delete_route
{
local ($route) = @_;
local $cmd = "route delete";
if (!$route->{'dest'} || $route->{'dest'} eq '0.0.0.0') {
	$cmd .= " default";
	}
else {
	$cmd .= " $route->{'dest'}";
	}
if ($route->{'gateway'}) {
	$cmd .= " $route->{'gateway'}";
	}
elsif ($route->{'iface'}) {
	local @act = &active_interfaces();
	local ($aiface) = grep { $_->{'fullname'} eq $route->{'iface'} } @act;
	if ($aiface) {
		$cmd .= " $aiface->{'address'}";
		}
	}
if ($route->{'netmask'}) {
	$cmd .= " $route->{'netmask'}";
	}
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# create_route(&route)
# Adds a new active route
sub create_route
{
local ($route) = @_;
local $cmd = "route add ";
if (!$route->{'dest'}) {
	$cmd .= " default";
	}
else {
	$cmd .= " $route->{'dest'}";
	}
if ($route->{'gateway'}) {
	$cmd .= " $route->{'gateway'}";
	}
elsif ($route->{'iface'}) {
	local @act = &active_interfaces();
	local ($aiface) = grep { $_->{'fullname'} eq $route->{'iface'} } @act;
	if ($aiface) {
		$cmd .= " $aiface->{'address'}";
		}
	}
if ($route->{'netmask'}) {
	$cmd .= " $route->{'netmask'}";
	}
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# apply_network()
# Apply the interface and routing settings, by activating all interfaces and
# adding the default route
sub apply_network
{
local (%done, $b, $a);
foreach $b (&boot_interfaces()) {
	&apply_interface($b);
	$done{$b->{'fullname'}}++;
	}
foreach $a (&active_interfaces()) {
	if (!$done{$a->{'fullname'}} && !$a->{'zone'}) {
		&deactive_interface($a);
		}
	}
local @infile = &get_defaultrouters();
local @routes = &list_routes();
local @inmem = map { $_->{'gateway'} }
		   grep { $_->{'dest'} eq "0.0.0.0" } @routes;
if (join(" ", @infile) ne join(" ", @inmem)) {
	# Fix up default routes
	local $r;
	foreach $r (@inmem) {
		&system_logged("route delete default $r >/dev/null 2>&1");
		}
	foreach $r (@infile) {
		&system_logged("route add default $r >/dev/null 2>&1");
		}
	}
}

# apply_interface(&iface)
# Calls an OS-specific function to make a boot-time interface active
sub apply_interface
{
if ($_[0]->{'dhcp'}) {
	local $out = &backquote_logged("cd / ; ifconfig $_[0]->{'fullname'} 0.0.0.0 ; ifconfig $_[0]->{'fullname'} dhcp 2>&1 </dev/null");
	return $? || $out =~ /error/i ? $out : undef;
	}
else {
	&activate_interface($_[0]);
	}
}

# automatic_netmask(address)
# Returns the netmask for some address, based on /etc/netmasks
sub automatic_netmask
{
local ($address) = @_;
local %mask;
&open_readfile(MASK, "/etc/netmasks");
while(<MASK>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/([0-9\.]+)\s+([0-9\.]+)/) {
		$mask{$1} = $2;
		}
	}
close(MASK);
local ($a1, $a2, $a3, $a4) = split(/\./, $address);
local $netmask = "255.255.255.0";
local $netaddr;
foreach $netaddr (keys %mask) {
	$mask{$netaddr} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
	local $na = sprintf "%d.%d.%d.%d",
			int($a1) & int($1),
			int($a2) & int($2),
			int($a3) & int($3),
			int($a4) & int($4);
	$netmask = $mask{$netaddr} if ($na eq $netaddr);
	}
return $netmask;
}

1;

