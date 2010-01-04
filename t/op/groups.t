#!./perl

$ENV{PATH} ="/bin:/usr/bin:/usr/xpg4/bin:/usr/ucb" .
    exists $ENV{PATH} ? ":$ENV{PATH}" : "" unless $^O eq 'VMS';
$ENV{LC_ALL} = "C"; # so that external utilities speak English
$ENV{LANGUAGE} = 'C'; # GNU locale extension

BEGIN {
    # fake "use strict"
    $^H |= 0x602;

    chdir 't';
    @INC = '../lib';

    require Config;
    Config->import;
}

sub quit {
    print "1..0 # Skip: no `id` or `groups`\n";
    exit 0;
}

unless (eval { my($foo) = getgrgid(0); 1 }) {
    print "1..0 # Skip: getgrgid() not implemented\n";
    exit 0;
}

quit() if (($^O eq 'MSWin32' || $^O eq 'NetWare' || $^O eq 'VMS')
           or $^O =~ /lynxos/i);

# We have to find a command that prints all (effective
# and real) group names (not ids).  The known commands are:
# groups
# id -Gn
# id -a
# Beware 1: some systems do just 'id -G' even when 'id -Gn' is used.
# Beware 2: id -Gn or id -a format might be id(name) or name(id).
# Beware 3: the groups= might be anywhere in the id output.
# Beware 4: groups can have spaces ('id -a' being the only defense against this)
# Beware 5: id -a might not contain the groups= part.
#
# That is, we might meet the following:
#
# foo bar zot				# accept
# foo 22 42 bar zot			# accept
# 1 22 42 2 3				# reject
# groups=(42),foo(1),bar(2),zot me(3)	# parsed by $GROUP_RX1
# groups=22,42,1(foo),2(bar),3(zot(me))	# parsed by $GROUP_RX2
#
# and the groups= might be after, before, or between uid=... and gid=...
my $GROUP_RX1 = qr/
    ^
    (?<gr_name>.+)
    \(
        (?<gid>\d+)
    \)
    $
/x;
my $GROUP_RX2 = qr/
    ^
    (?<gid>\d+)
    \(
        (?<gr_name>.+)
    \)
    $
/x;

my $command;
my $groups;
GROUPS: {
    # prefer 'id' over 'groups' (is this ever wrong anywhere?)
    # and 'id -a' over 'id -Gn' (the former is good about spaces in group names)

    $command = 'id -a 2>/dev/null';
    $groups = `$command`;
    if ( $groups ne '' ) {
	# $groups is of the form:
	# uid=39957(gsar) gid=22(users) groups=33536,39181,22(users),0(root),1067(dev)
	# FreeBSD since 6.2 has a fake id -a:
	# uid=1001(tobez) gid=20(staff) groups=20(staff), 0(wheel), 68(dialer)
	last GROUPS if $groups =~ /groups=/;
    }

    $command = 'id -Gn 2>/dev/null';
    $groups = `$command`;
    if ( $groups ne '' ) {
	# $groups could be of the form:
	# users 33536 39181 root dev
	last GROUPS if $groups !~ /^(\d|\s)+$/;
    }

    $command = 'groups 2>/dev/null';
    $groups = `$command`;
    if ( $groups ne '' ) {
	# may not reflect all groups in some places, so do a sanity check
	if (-d '/afs') {
	    print <<EOM;
# These test results *may* be bogus, as you appear to have AFS,
# and I can't find a working 'id' in your PATH (which I have set
# to '$ENV{PATH}').
#
# If these tests fail, report the particular incantation you use
# on this platform to find *all* the groups that an arbitrary
# user may belong to, using the 'perlbug' program.
EOM
	}
	last GROUPS;
    }

    # Okay, not today.
    quit();
}

chomp($groups);

diag_variable( groups => $groups );

# Remember that group names can contain whitespace, '-', '(parens)',
# et cetera. That is: do not \w, do not \S.
my @extracted_groups;
if ($groups =~ /groups=(.+)( [ug]id=|$)/) {
    my $gr = $1;

    my @g = split /, ?/, $gr;
    # prefer names over numbers
    for (@g) {
	if ( /$GROUP_RX1/ || /$GROUP_RX2/ ) {
	    push @extracted_groups, $+{gr_name} || $+{gid};
	}
	else {
	    print "# ignoring group entry [$_]\n";
	}
    }

    diag_variable( gr => $gr );
    diag_variable( g => join ',', @g );
    diag_variable( ex_gr => join ',', @extracted_groups );
}
else {
    # Help?
    print "1..0 # Skip: can't parse `$command`\n";
    exit 0;
}

# # Workaround [perl #71788] $) is truncated on Mac OS X
# #
# # getgroups(2) is limited to NGROUPS_MAX=16 but DirectoryService(8)
# # will enumerate the full list apparently everywhere else including
# # /usr/bin/id, /usr/bin/groups, getgrouplist(3) and the
# # DirectoryService(8) APIs
# #
# # getgroups(2) also is unaware of group membership provided by Active
# # Directory though again, every other API works.
# #
# if ( $^O eq 'darwin' ) 
#     require POSIX;
#{
#     my @dropped_groups;
# 
#     # As a work around, preferentially remove things from Active
#     # Directory. I observed that the supplementary Active Directory
#     # groups vanished once the the computer had been away from the
#     # network for awhile. The base group was provided by Active
#     # Directory and remained available regardless. It's ok to remove
#     # our base group here because we're doing explict work to compare
#     # only the supplementary groups.
#     #
#     push @dropped_groups, grep {   /\\/ } @extracted_groups;
#     @extracted_groups =   grep { ! /\\/ } @extracted_groups;
# 
#     # As a further, different work around, truncate the list of
#     # groups.
#     require POSIX;
#     push @dropped_groups,
#         splice @extracted_groups, POSIX::NGROUPS_MAX();
# 
#     if ( @dropped_groups ) {
#         diag_variable( dropped => join ',', @dropped_groups );
#     }
# }

print "1..2\n";

my $pwgid = $( + 0;
my ($pwgnam) = getgrgid($pwgid);
$pwgnam //= '';

print "# pwgid=$pwgid pwgnam=$pwgnam \$(=$(\n";

# Lookup perl's own groups from $(
my @gids = split ' ', $(;
my %gid_count;
my @gr_name;
for my $gid ( @gids ) {
    ++ $gid_count{$gid};

    my ($group) = getgrgid $gid;

    # Why does this test prefer to not test groups which we don't have
    # a name for? One possible answer is that my primary group comes
    # from from my entry in the user database but isn't mentioned in
    # the group database.  Are there more reasons?
    next if ! defined $group;

    # Ignore any groups in $( that we failed to parse successfully out
    # of the `id -a` mess above.
    next if ! grep { $_ eq $group } @extracted_groups;

    push @gr_name, $group;
}
diag_variable( gr_name => join ',', @gr_name );

# Validate against only the supplementary groups.
my %basegroup;
if ($Config{myuname} =~ /^cygwin_nt/i) { # basegroup on CYGWIN_NT has id = 0.
    $basegroup{$pwgid} = 0;
    $basegroup{$pwgnam} = 0 if defined $pwgnam;
} else {
    $basegroup{$pwgid} = 0;
    $basegroup{$pwgnam} = 1 if defined $pwgnam;
}
my @extracted_supplementary_groups =
    sort
    uniq(
        grep { ! exists $basegroup{$_} }
        @extracted_groups
    );
diag_variable( ex_gr => join ',', @extracted_supplementary_groups );

# Dedupe, sort, and test with only the supplementary groups.
my @gr_sup_name =
    sort
    uniq(
        grep { ! exists $basegroup{$_} }
        @gr_name
    );

my $ok1 = 0;
if ( "@gr_sup_name" eq "@extracted_supplementary_groups"
     || ( ! @gr_sup_name
          && 1 == @extracted_supplementary_groups
          && $pwgid eq $extracted_supplementary_groups[0] )
) {
    print "ok 1\n";
    $ok1 = 1;
}
elsif ($Config{myuname} =~ /^cygwin_nt/i) { # basegroup on CYGWIN_NT has id = 0.
    # Retry in default unix mode
    %basegroup = ( $pwgid => 1, $pwgnam => 1 );
    @extracted_supplementary_groups =
        grep { ! $basegroup{$_} ++ }
        @extracted_groups;

    if ( "@gr_sup_name" eq "@extracted_supplementary_groups"
         || ( ! @gr_sup_name
              && 1 == @extracted_supplementary_groups
              && $pwgid eq $extracted_supplementary_groups[0] )
    ) {
	print "ok 1 # This Cygwin behaves like Unix (Win2k?)\n";
	$ok1 = 1;
    }
}


unless ($ok1) {
    diag_variable( gr_sup_name => join ',', @gr_sup_name );
    diag_variable( ex_sup_name => join ',', @extracted_supplementary_groups );
    print "not ok 1\n";
}

# multiple 0's indicate GROUPSTYPE is currently long but should be short
$gid_count{'0'} //= 0;
if ( 0 == $pwgid || $gid_count{0} < 2 ) {
    print "ok 2\n";
}
else {
    print "not ok 2 (groupstype should be type short, not long)\n";
}

sub diag_variable {
    my ( $label, $content ) = @_;

    # I wanted to align all the diagnostic prints of the info to the
    # same column. The "die" below is for my convenience as a test
    # author to so I'm forced to "get it right" when setting the
    # spacing.
    die length $label if length $label > 11;

    printf "# %-11s=%s\n", $label, $content;
}

sub uniq {
    my %seen;
    return
        grep { ! $seen{$_}++ }
        @_;
}
