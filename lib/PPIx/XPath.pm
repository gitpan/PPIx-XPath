package PPIx::XPath;

$VERSION = '1.0.0';

use strict;

use PPI::Document;

use Class::XPath (
  get_name       => sub { substr(ref($_), 5) },
  get_parent     => 'parent',
  get_root       => sub { ${ +shift } },
  get_children   => sub {
    my $m = UNIVERSAL::can($_[0], 'schildren');
    $m ? goto &$m : ()
  },
  get_content    => 'content',
  ## don't really supports these so well presently
  get_attr_names => sub { keys %{$_[0]} },
  get_attr_value => sub { values %{$_[0]} },
);

use Carp 'croak';
use Scalar::Util 'reftype';

sub new {
  my($class, $code) = @_;
  my $doc   = UNIVERSAL::isa($code, 'PPI::Node')
            ? $code
            : -f $code || reftype($code) eq 'SCALAR'
              ? PPI::Document->new($code)
              : croak("PPIx::XPath expects either a PPI::Node or a file" .
                      " got a: [" .( ref($code) || $code ). ']');

  return bless \$doc, $class;
}

1;

=pod

=head1 NAME

PPIx::XPath - an XPath implementation for the PDOM

=head1 SYNOPSIS

  use PPIx::XPath;

  my $pxp  = PPIx::XPath->new("some_code.pl");
  my @subs = $pxp->match("//Statement::Sub");
  my $vars = $pxp->match("//Token::Symbol");

=head1 DESCRIPTION

This module simply provides an XPath implementation for the L<PDOM|PPI> using
Sam Tregar's nifty L<Class::XPath>.

=head1 METHODS

=over 4

=item new

This expects a single argument which is either a filename or something which
inherits from L<PPI::Node>.

=item match

Given a XPath query string return a list of the nodes which matched.

=item xpath

Returns an equivalent XPath query string of the current object.

=back

=head1 TODO

=over 4

=item *

An actual test suite.

=back

=head1 BUGS

No known bugs yet, but if you find any, please report them at:

http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPIx::XPath

=head1 SEE. ALSO

L<PPI>

L<Class::XPath>

=head1 AUTHOR

Dan Brook C<< C<cpan@broquaint.com> >>

=cut
