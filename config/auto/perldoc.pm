# Copyright: 2001-2005 The Perl Foundation.  All Rights Reserved.
# $Id$

=head1 NAME

config/auto/perldoc - Check whether perldoc works

=head1 DESCRIPTION

Determines whether perldoc exists on the system.

=cut

package auto::perldoc;

use strict;
use vars qw($description $result @args);

use base qw(Parrot::Configure::Step::Base);

use Parrot::Configure::Step ':auto', 'capture_output';

$description = "Determining whether perldoc is installed...";

@args = qw(verbose);

sub runstep {
    my $self = shift;
    my $version = 0;
    my $a = capture_output( 'perldoc -ud c99da7c4.tmp perldoc' ) || undef;
    
    if (defined $a) {
        if ($a =~ m/^Unknown option:/) {
	    $a = capture_output( 'perldoc perldoc' ) || '';
	    $version = 1;
	    $result = 'yes, old version';
	} else {
	    if (open FH, "< c99da7c4.tmp") {
		local $/;
		$a = <FH>;
		close FH;
	        $version = 2;
	        $result = 'yes';
	    } else {
		$a = undef;
	    }
	}
	unless (defined $a && $a =~ m/perldoc/) {
	    $version = 0;
	    $result = 'failed';
	}
    } else {
	$result = 'no';
    }
    unlink "c99da7c4.tmp";

    Parrot::Configure::Data->set(
	has_perldoc => $version != 0 ? 1 : 0,
	new_perldoc => $version == 2 ? 1 : 0
    );
}

1;
