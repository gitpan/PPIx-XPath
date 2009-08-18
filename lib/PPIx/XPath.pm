package PPIx::XPath;
use strict;
use warnings;
use PPI;
use Carp;
use Scalar::Util qw(reftype blessed);
use Tree::XPathEngine;
use 5.006;

our $VERSION='2.01';

sub new {
    my ($class,$source) = @_;

    croak "PPIx::XPath->new needs a source document" unless defined($source);

    my $doc;
    if (blessed($source) && $source->isa('PPI::Node')) {
        $doc = $source;
    }
    elsif (reftype($source) eq 'SCALAR'
       or (!ref($source) && -f $source)) {
        $doc = PPI::Document->new($source);
    }
    else {
        croak "PPIx::XPath expects either a PPI::Node or a file" .
            " got a: [" .( ref($source) || $source ). ']';
    }

    return bless {doc=>$doc},$class;
}

# PPIx::XPath 1.0.0 allowed the use of partial package names as node names;
# this collides with the axis specification of proper XPath.
# Here we change the "old-style" node names into the new names
{
my $legacy_names_rx;my %new_name_for;
sub clean_xpath_expr {
    my (undef,$expr)=@_;

    $expr =~ s{$legacy_names_rx}{$new_name_for{$1}}ge;

    return $expr;
}

    my @PPI_Packs;
    # taken from Devel::Symdump
    my @packages=('PPI');
    while (my $pack=shift(@packages)) {
        no strict 'refs';
        while (my ($key,$val)=each(%{*{"$pack\::"}})) {
            local *ENTRY=$val;
            if (defined $val && defined *ENTRY{HASH} && $key=~/::$/
                    && $key !~ /^::/
                    && $key ne 'main::' && $key ne '<none>::') {

                my $p = "$pack\::$key";$p =~ s{::$}{}; #}{};
                push @packages,$p;
                $p =~ s{^PPI::}{};

                next unless $p=~/::/;

                my $newname=$p;
                $newname =~ s{::}{-}g;
                push @PPI_Packs,$p;
                $new_name_for{$p}=$newname;
            }
        }
    }
    $legacy_names_rx='\b('.join('|',
                            sort {length($b) <=> length($a)} @PPI_Packs
                            ).')\b';
    $legacy_names_rx=qr{$legacy_names_rx};
}

sub match {
    my ($self,$expr) = @_;

    $expr=$self->clean_xpath_expr($expr);

    Tree::XPathEngine->new()->findnodes($expr,$self->{doc});
}

package PPI::Element;
use strict;
use warnings;

sub xpath_get_name              { my $pack_name=substr($_[0]->class,5);
                                  $pack_name =~ s/::/-/g;
                                  $pack_name }
sub xpath_get_next_sibling      { $_[0]->snext_sibling }
sub xpath_get_previous_sibling  { $_[0]->sprevious_sibling }
sub xpath_get_root_node         { $_[0]->top }
sub xpath_get_parent_node       { $_[0]->parent }
sub xpath_is_element_node       { 1 }
sub xpath_is_attribute_node     { 0 }
sub xpath_is_document_node      { 0 }
sub xpath_get_attributes        {
    return
        PPIx::XPath::Attr->new($_[0],'significant'),
        PPIx::XPath::Attr->new($_[0],'content'),
}
sub xpath_to_literal            { "$_[0]" }
sub xpath_get_value             { "$_[0]" }
sub xpath_string_value          { "$_[0]" }

sub xpath_cmp {
    my( $a, $b)= @_;
    if ( UNIVERSAL::isa( $b, 'PPIx::XPath::Attr')) {
        # elt <=> att, compare the elt to the att->{elt}
        # if the elt is the att->{elt} (cmp return 0) then -1, elt is before att
        return ($a->_xpath_elt_cmp( $b->{parent}) ) || -1 ;
    }
    elsif ( UNIVERSAL::isa( $b, 'PPI::Document')) {
        # elt <=> document, elt is after document
        return 1;
    } else {
        # 2 elts, compare them
        return $a->_xpath_elt_cmp( $b);
    }
}

sub _xpath_elt_cmp {
    my ($a,$b)=@_;

    # easy cases
    return  0 if( $a == $b);
    return  1 if( $a->_xpath_in($b)); # a starts after b
    return -1 if( $b->_xpath_in($a)); # a starts before b

    # ancestors does not include the element itself
    my @a_pile= ($a, $a->_xpath_ancestors);
    my @b_pile= ($b, $b->_xpath_ancestors);

    # the 2 elements are not in the same twig
    return undef unless( $a_pile[-1] == $b_pile[-1]);

    # find the first non common ancestors (they are siblings)
    my $a_anc= pop @a_pile;
    my $b_anc= pop @b_pile;

    while( $a_anc == $b_anc) {
        $a_anc= pop @a_pile;
        $b_anc= pop @b_pile;
    }

    # from there move left and right and figure out the order
    my( $a_prev, $a_next, $b_prev, $b_next)= ($a_anc, $a_anc, $b_anc, $b_anc);
    while () {
        $a_prev= $a_prev->sprevious_sibling || return( -1);
        return 1 if( $a_prev == $b_next);
        $a_next= $a_next->snext_sibling || return( 1);
        return -1 if( $a_next == $b_prev);
        $b_prev= $b_prev->sprevious_sibling || return( 1);
        return -1 if( $b_prev == $a_next);
        $b_next= $b_next->snext_sibling || return( -1);
        return 1 if( $b_next == $a_prev);
    }
}

sub _xpath_in {
    my ($self, $ancestor)= @_;
    while ( $self= $self->parent) {
        return $self if ( $self ==  $ancestor);
    }
}

sub _xpath_ancestors {
    my( $self)= @_;
    my @ancestors;
    while ( $self= $self->parent) {
        push @ancestors, $self;
    }
    return @ancestors;
}

package PPI::Token;
use strict;
use warnings;

sub xpath_get_child_nodes       { return }

package PPI::Token::Quote::Double;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'interpolations'),
}

package PPI::Token::Number;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'base'),
}

package PPI::Token::Word;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'method-call'),
}

package PPI::Token::Comment;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'line'),
}

package PPI::Token::HereDoc;
use strict;
use warnings;

# TODO: add access to the contents of the heredoc (->heredoc method)

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'terminator'),
}

package PPI::Token::Prototype;
use strict;
use warnings;

sub xpath_to_literal            { $_[0]->prototype }
sub xpath_get_value             { $_[0]->prototype }
sub xpath_string_value          { $_[0]->prototype }

package PPI::Node;
use strict;
use warnings;

sub xpath_get_child_nodes       { $_[0]->schildren }
sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'scope'),
}

package PPI::Token::Attribute;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'identifier'),
        PPIx::XPath::Attr->new($_[0],'parameters'),
}

package PPI::Token::Symbol;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'symbol'),
        PPIx::XPath::Attr->new($_[0],'canonical'),
        PPIx::XPath::Attr->new($_[0],'raw_type'),
        PPIx::XPath::Attr->new($_[0],'symbol_typel'),
}

package PPI::Statement;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'label'),
        PPIx::XPath::Attr->new($_[0],'stable'),
        PPIx::XPath::Attr->new($_[0],'type'),
}

package PPI::Statement::Sub;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'name'),
        PPIx::XPath::Attr->new($_[0],'prototype'),
        PPIx::XPath::Attr->new($_[0],'forward'),
        PPIx::XPath::Attr->new($_[0],'reserved'),
}

package PPI::Statement::Package;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'namespace'),
        PPIx::XPath::Attr->new($_[0],'file-scoped'),
}

package PPI::Statement::Include;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'module'),
        PPIx::XPath::Attr->new($_[0],'module-version'),
        PPIx::XPath::Attr->new($_[0],'version'),
        PPIx::XPath::Attr->new($_[0],'version-literal'),
        PPIx::XPath::Attr->new($_[0],'pragma'),
}

package PPI::Structure;
use strict;
use warnings;

sub xpath_get_attributes        {
    return $_[0]->SUPER::xpath_get_attributes,
        PPIx::XPath::Attr->new($_[0],'start'),
        PPIx::XPath::Attr->new($_[0],'finish'),
        PPIx::XPath::Attr->new($_[0],'braces'),
}

package PPI::Document;
use strict;
use warnings;

sub xpath_get_root_node         { $_[0] }
sub xpath_get_parent_node       { return }
sub xpath_is_attribute_node     { 0 }
sub xpath_is_document_node      { 1 }

package PPIx::XPath::Attr;
use strict;
use warnings;

sub new {
    my ($class,$parent,$name)=@_;

    my $meth=$parent->can($name);
    return unless $meth;

    my $value;
    eval {$value=$meth->($parent);1} or return;

    return unless defined $value;

    return bless {parent=>$parent,name=>$name,value=>$value},$class;
}

sub xpath_get_name              { $_[0]->{name} }
sub xpath_get_root_node         { $_[0]->{parent}->top }
sub xpath_get_parent_node       { $_[0]->{parent} }
sub xpath_is_element_node       { 0 }
sub xpath_is_attribute_node     { 1 }
sub xpath_is_document_node      { 0 }
sub xpath_to_literal            { $_[0]->{value} }
sub xpath_get_value             { $_[0]->{value} }
sub xpath_string_value          { $_[0]->{value} }
sub xpath_to_number             { Tree::XPathEngine::Number->new($_[0]->{value}) }

sub xpath_cmp($$) {
    my( $a, $b)= @_;
    if ( UNIVERSAL::isa( $b, 'PPIx::XPath::Attr')) {
        # 2 attributes, compare their elements, then their name
        return ($a->{parent}->_xpath_elt_cmp( $b->{parent}) ) 
            || ($a->{name} cmp $b->{name});
    }
    elsif ( UNIVERSAL::isa( $b, 'PPI::Document')) {
        # att <=> document, att is after document
        return 1;
    }
    else {
        # att <=> elt : compare the att->elt and the elt
        # if att->elt is the elt (cmp returns 0) then 1 (elt is before att)
        return ($a->{parent}->_xpath_elt_cmp( $b) ) || 1 ;
    }
}

1;
__END__

=head1 NAME

PPIx::XPath - an XPath implementation for the PDOM

=head1 SYNOPSIS

  use PPI;
  use PPI::XPath;
  use Tree::XPathEngine;

  my $pdom = PPI::Document->new('some_code.pl');
  my $xpath = Tree::XPathEngine->new();
  my @subs = $xpath->findnodes('//Statement-Sub',$pdom);
  my @vars = $xpath->findnodes('//Token-Symbol',$pdom);

Deprecated interface, backward-compatible with C<PPIx::XPath> version
1:

  use PPIx::XPath;

  my $pxp  = PPIx::XPath->new("some_code.pl");
  my @subs = $pxp->match("//Statement::Sub");
  my $vars = $pxp->match("//Token::Symbol");

=head1 DESCRIPTION

This module augments L<PPI>'s classes with the methods required by
L<Tree::XPathEngine>, allowing you to perform complex XPath matches
against any PDOM tree.

See L<Tree::XPathEngine> for details about its methods.

=head2 Mapping the PDOM to the XPath data model

=over 4

=item *

Each node in the PDOM is an element as seen by XPath

=item *

The name of the element is the class name of the node, minus the
initial C<PPI::>, with C<::> replaced by C<->. That is:

  ($xpath_name = substr($pdom_node->class,5)) =~ s/::/-/g;

=item *

Only "significant" nodes are seen by XPath

=item *

all scalar-valued accessors of PDOM nodes are visible as attributes

=item *

"here-docs" contents are I<not> mapped

=back

=head1 BUGS and LIMITATIONS

=over 4

=item *

"here-docs" contents are I<not> mapped

=item *

node ordering is slow, because I could not find a way in PPI to
compare two nodes for document order; suggestions are most welcome

=back

=head1 SEE ALSO

L<PPI>

L<Tree::XPathEngine>

L<http://www.w3.org/TR/xpath> (the XPath specification)

=head1 AUTHOR

Dan Brook <cpan@broquaint.com> original author

Gianni Ceccarelli <dakkar@thenautilus.net> Tree::XPathEngine-based re-implementation

=cut
