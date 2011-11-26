#!/usr/bin/env perl
package HTTP::Server::Simple::WebDAO;
use strict;
use warnings;
use base qw/HTTP::Server::Simple::CGI/;
use v5.10;
use WebDAO;
use WebDAO::Engine;
use WebDAO::Session;
use WebDAO::Store::Abstract;
use vars qw($VERSION);
$VERSION = '0.01';

=head1 NAME

HTTP::Server::Simple::WebDAO - WebDAO handler for HTTP::Server::Simple

=head1 SYNOPSIS

    HTTP::Server::Simple::WebDAO;

    my $srv = new HTTP::Server::Simple::WebDAO::($port);
    $srv->set_config( wdEngine => "Plosurin::HTTP", wdDebug => 3 );
    $srv->run();

=head1 DESCRIPTION

HTTP::Server::Simple::WebDAO is a HTTP::Server::Simple based HTTP server
that can run WebDAO applications. This module only depends on
L<HTTP::Server::Simple>, which itself doesn't depend on any non-core
modules so it's best to be used as an embedded web server.

=head1 SEE ALSO

L<HTTP::Server::Simple>, L<WebDAO>


=head1 AUTHOR

Zahatski Aliaksandr

=head1 LICENSE

Copyright 2011 by Zahatski Aliaksandr

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->set_config;
    return $self;
}

sub auto_load_class {
    my $self = shift;
    my $class = shift || return;

    #check non loaded mods
    my ( $main, $module ) = $class =~ m/(.*\:\:)?(\S+)$/;
    $main ||= 'main::';
    $module .= '::';
    no strict 'refs';
    unless ( exists $$main{$module} ) {
        warn "Try use $class";
        eval "use $class";
        if ($@) {
            die "Error register class :$class with $@ ";
        }
    }
    use strict 'refs';
}

sub _parse_str_to_hash {
    my $str = shift;
    return unless $str;
    my %hash = map { split( /=/, $_ ) } split( /;/, $str );
    foreach ( values %hash ) {
        s/^\s+//;
        s/\s+^//;
    }
    \%hash;
}

sub set_config {
    my $self = shift;
    my %args = @_;
    while ( my ( $k, $v ) = each %args ) {
        $self->{$k} = $v;
    }
    my ( $store_class, $session_class, $eng_class ) = map {
        $self->auto_load_class($_);
        $_
      } (
        $ENV{wdStore}   || $args{wdStore}   || 'WebDAO::Store::Abstract',
        $ENV{wdSession} || $args{wdSession} || 'WebDAO::Session',
        $ENV{wdEngine}  || $args{wdEngine}  || 'WebDAO::Engine'
      );
    @{$self}{qw/ store_class session_class eng_class/} =
      ( $store_class, $session_class, $eng_class );
    $self;
}

sub handle_request {
    my ( $self, $cgi ) = @_;
    my ( $store_class, $session_class, $eng_class ) =
      @{$self}{qw/ store_class session_class eng_class/};

    #Make Session object
    my $store_obj = $store_class->new(
        %{
            &_parse_str_to_hash( $self->{wdStorePar} || $ENV{wdStorePar} ) || {}
          }
    );
    my $sess = $session_class->new(
        %{
            &_parse_str_to_hash( $self->{wdSessionPar} || $ENV{wdSessionPar} )
              || {}
          },
        store => $store_obj,
        cv    => HTTP::Server::Simple::WebDAO::CVcgi->new($cgi)
    );
    $sess->set_header( -type => 'text/html; charset=utf-8' );
    my $eng = $eng_class->new(
        %{
            &_parse_str_to_hash( $self->{wdEnginePar} || $ENV{wdEnginePar} )
              || {}
          },
        session => $sess,
    );
    $ENV{wdDebug} = $self->{wdDebug} if exists $self->{wdDebug};
    $sess->ExecEngine($eng);
    $sess->destroy;

    #... do something, print output to default
    # selected filehandle...
    #    print "200 OK\r\n";
    #    print STDERR $cgi->header;

}
package HTTP::Server::Simple::WebDAO::CVcgi;
use strict;
use warnings;
use WebDAO::CVcgi;
use base qw/WebDAO::CVcgi/;
sub response {
    my $self        = shift;
    my $res         = shift || return;
    my $status = $res->{'headers'}->{'-STATUS'} || "200 OK" ; 
    $self->print("HTTP/1.0 $status\r\n");
    $self->SUPER::response($res);
}
package HTTP::Server::Simple::WebDAO;
1;
