package Class::Data::Reloadable;
use warnings;
use strict;
use Carp;

use Class::ISA;
use NEXT;

our ( $VERSION, $AUTOLOAD );

sub _debug { 0 }

=head1 NAME

Class::Data::Reloadable - inheritable, overridable class data that survive reloads

=head1 VERSION

Version 0.01

=cut

$VERSION = '0.01';

=head1 SYNOPSIS

    package Stuff;
    use base qw(Class::Data::Inheritable);

    # Set up DataFile as inheritable class data.
    Stuff->mk_classdata('DataFile');

    # Declare the location of the data file for this class.
    Stuff->DataFile('/etc/stuff/data');

    # ... reload Stuff within same interpreter

    print Stuff->DataFile;   # /etc/stuff/data

=head1 DESCRIPTION

A drop-in replacement for L<Class::Data::Inheritable|Class::Data::Inheritable>,
but subclasses can be reloaded without losing their class data. This is useful
in mod_perl development, and may be useful elsewhere.

In mod_perl, L<Apache::Reload|Apache::Reload>
conveniently reloads modules that have been modified, rather than having to
restart Apache. This works well unless the module stores class data that are
not re-created during the reload. In this situation, you still need to restart the
server, in order to rebuild the class data.

Saves many (if your code starts out buggy like mine) Apache restarts.

But only if you're strict about storing B<all> class data using this mechanism.

See L<Class::Data::Inheritable|Class::Data::Inheritable> for more examples.

=head1 METHODS

=over

=item mk_classdata

Creates a classdata slot, optionally setting a value into it.

    $client->mk_classdata( 'foo' );
    $client->classdata->foo( 'bar' );
    # same thing:
    $client->mk_classdata( foo => 'bar' );

Note that during a reload, this method may be called again for an existing
attribute. If so, any value passed with the method is silently ignored, in
favour of whatever value was in the slot before the reload.

This also provides a C<_foo_accessor> alias.

=cut

=item AUTOLOAD

If the class has been reloaded, and if before the reload, other classes have
called C<mk_classdata> on this class, then some accessors will be missing after
the reload. AUTOLOAD replaces these methods the first time they are called.

Redispatches (via L<NEXT|NEXT>) to any C<AUTOLOAD> method further up the
chain if no attribute is found.

=back

=cut

sub mk_classdata {
    my ( $proto, $attribute ) = ( shift, shift );

    # During a reload, this method will often be called again. In that case,
    # do _not_ set any value being passed in this call - discard it and return
    # whatever was last stored there before the reload.
    return $proto->$attribute if $proto->__has( $attribute ) && $proto->can( $attribute );

    $proto->__mk_accessor( $attribute, @_ );
}

sub AUTOLOAD {
    my $proto = shift;

    my ( $attribute ) = $AUTOLOAD =~ /([^:]+)$/;

    warn "AUTOLOADING $attribute in $proto\n" if $proto->_debug;

    if ( my $owner = $proto->__has( $attribute ) )
    {
        # put it back where it came from
        $owner->__mk_accessor( $attribute );
        return $proto->$attribute( @_ );
    }
    else
    {
        # maybe it was intended for somewhere else
        $proto->NEXT::ACTUAL::DISTINCT::AUTOLOAD( @_ );
    }
}

sub DESTROY { $_[0]->NEXT::DISTINCT::DESTROY() }

sub __mk_accessor {
    my ( $proto, $attribute ) = ( shift, shift );

    my $client = ref( $proto ) || $proto;

    warn "making '$attribute' accessor in $client\n" if $proto->_debug;

    my $accessor = sub { shift->__classdata( $attribute, @_ ) };

    my $alias = "_${attribute}_accessor";

    no strict 'refs';
    *{"$client\::$attribute"} = $accessor;
    *{"$client\::$alias"}     = $accessor;

    $proto->$attribute( $_[0] ) if @_;
}

my $ClassData;

sub __classdata {
    my ( $proto, $attribute ) = ( shift, shift );

    my $client = ref( $proto ) || $proto;

    # if there's data to set, put it in the client slot
    return( $ClassData->{ $client }{ $attribute } = $_[0] ) if @_;

    # if there's no data to set, search for a previous value
    foreach my $ima ( Class::ISA::self_and_super_path( $client ) )
    {
        return $ClassData->{ $ima }{ $attribute } if
        exists $ClassData->{ $ima }{ $attribute };
    }

    return undef; # should always at least return undef (i.e. not an empty list)
}

sub __has {
    my ( $proto, $attribute ) = @_;

    my $client = ref( $proto ) || $proto;

    my $owner;

    foreach my $ima ( Class::ISA::self_and_super_path( $client ) )
    {
        $owner = $ima if exists $ClassData->{ $ima }{ $attribute };
        last if $owner;
    }

    return $owner;
}

=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-class-data-separated@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2004 David Baird, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Class::Data::Separated
