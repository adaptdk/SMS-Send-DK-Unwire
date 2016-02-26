package SMS::Send::DK::Unwire;

use 5.006;
use strict;
use warnings;

use Carp;
use LWP::UserAgent;
use Encode qw(encode FB_CROAK);

use base qw(SMS::Send::Driver);

=head1 NAME

SMS::Send::DK::Unwire - An SMS::Send driver for Unwire

It is an object object-oriented interface that inherits from SMS::Send::Driver

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

	use SMS::Send;

	# Initiate sender
	# User your credentials from Unwire - See README
	$sender= SMS::Send->new( "DK::Unwire",
		_login    => $unwire_login,
		_password => $unwire_password,
	);

	# Send SMS
	# Provide your own: $from, $to, $message, $callback anb $sessid if you need
	# to keep track of statuscodes.
	my $ok = '';
	eval {
		my $ok= $sender->send_sms(
			_from => $from,
			to => $to,
			text => encode('iso-8859-1', $message),
			_callbackurl => $callback,
			_sessionid => "$sessid",
			_validity => 8*60,
		);
	}

	if (ok and !$@) {
		print "SMS sent!";
	} else {
		print "Error - ok: $ok - \$@: $@\n";
	}

=head1 METHODS

Just a couple: "new" and "send_sms"

=head2 new

Initiate a sender object. See SYNOPSIS.

=cut

sub new {
	my $class= shift;
	my %param= @_;

	croak "_login and _password are mandatory" unless  $param{_login} && $param{_password};

	$param{ua} ||= LWP::UserAgent->new;

	my $self= bless ({
		login => $param{_login},
		password => $param{_password},
		ua => $param{ua},
	}, ref ($class) || $class);

	return $self;
}

=head2 send_sms

Send SMS mesage method. See SYNOPSIS.

=cut

sub send_sms {
	my $self= shift;
	my %param= (
		_type => "text",
		_price => "0.00DKK",
		_appnr => "1231", # default for Danish Unwire customers
		_smsc => "dk.tdc", # required according to the docs
		@_
	);

	croak "text and to are mandatory" unless $param{text} && $param{to};

	my %form;
	while(my($k,$v)= each %param) {
		local $_= $k;
		s/^_//;
		if(/udh/) {
			$form{$_}= $param{$k};
		} else {
			# required according to the unwire docs
			$form{$_}= encode("iso-8859-1", $param{$k}, FB_CROAK);
		}
	}
	$form{user} ||= $self->{login};
	$form{password} ||= $self->{password};
	$form{to}=~ s/^\+//;

	$form{sessionid} ||= $self->_sessionid( $form{to} );

	my $ua= $self->{ua};
	my $response= $ua->post( "https://messaging.unwire.com/smspush", \%form );
	croak "HTTP (https) request failed (".$response->status_line.")" unless $response->is_success;

	my $content= $response->content;
	if($content=~ s/^Processing://) {
		return $content || 1;
	}

	"";
}

sub _sessionid {
	my $self= shift;
	my @time= localtime(time);
	return sprintf("%s:%04d%02d%02d%02d%02d%02d",
		$_[0],
		$time[5]+1900,
		@time[4,3,2,1,0]
	);
}

=head1 ATTRIBUTES

=head2 unwire_status

The meaning and description of return codes from Unwire. Lifted from the Unwire
documentation. These codes are submitted via the callback url. See Unwire
documentation

	# Example
	my $status = $SMS::Send::DK::Unwire::unwire_status[1];

	# $status is assigned this object:
	# {
	#   "status_code" => 1,
	#   "meaning" => "Message successfully delivered",
	#   "description" => "The message was delivered to the mobile and the charging (if any) completed."
	# }

=cut

my @unwire_status = (
	{
		"status_code" => "undef",
		"meaning" => "Codes start with (index) 1."
	},
	{
		"status_code" => 1,
		"meaning" => "Message successfully delivered",
		"description" => "The message was delivered to the mobile and the charging (if any) completed."
	},
	{
		"status_code" => 2,
		"meaning" => "Pre-paid account insufficient",
		"description" => "The subscriber's pre-paid card didn't hold the amount necessary to complete the content charging and the message was not delivered."
	},
	{
		"status_code" => 3,
		"meaning" => "Subscriber blacklisted",
		"description" => "The subscriber has been blacklisted by the operator."
	},
	{
		"status_code" => 4,
		"meaning" => "Not a subscriber",
		"description" => "The msisdn is not recognized by the operator and content charging and/or message delivery can not be completed."
	},
	{
		"status_code" => 5,
		"meaning" => "Unknown SMSC error",
		"description" => "The content charging and message delivery failed because of an error at the SMSC."
	},
	{
		"status_code" => 6,
		"meaning" => "Message validity period timed out",
		"description" => "The message's validity period expired before it was possible to deliver it to the mobile phone."
	},
	{
		"status_code" => 7,
		"meaning" => "Message is undeliverable",
		"description" => "The message contains undeliverable content (usually due to illegal binary values)."
	},
	{
		"status_code" => 8,
		"meaning" => "Message cancelled",
		"description" => "This covers statuscodes 2, 3 and 4 and is used whenever operators only return limited information when rejecting a content charged message."
	},
	{
		"status_code" => 9,
		"meaning" => "Message has been deleted",
		"description" => "The message was deleted and not delivered."
	},
	{
		"status_code" => 10,
		"meaning" => "Communication error",
		"description" => "Communication error between Unwire and the SMSC, the message was not successfully delivered."
	},
	{
		"status_code" => 11,
		"meaning" => "Temporary operator error",
		"description" => "The operator could not deliver the message to the end user because of a temporary error. When receiving this statuscode the CP can try pushing the message again, but do not do this in an infinite loop."
	}
);


=head1 BUGS

None known. This module has been used in production from 2007 without incidents.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

		perldoc SMS::Send::DK::Unwire


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SMS-Send-DK-Unwire>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SMS-Send-DK-Unwire>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SMS-Send-DK-Unwire>

=item * Search CPAN

L<http://search.cpan.org/dist/SMS-Send-DK-Unwire/>

=back

=head1 AUTHOR

		Christian Borup
		CPAN ID: borup
		Adapt A/S


=head1 SEE ALSO

SMS::Send

perl(1).

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
# The preceding line will help the module return a true value
