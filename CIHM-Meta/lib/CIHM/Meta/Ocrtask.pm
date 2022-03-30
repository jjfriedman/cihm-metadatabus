package CIHM::Meta::Ocrtask;

use strict;
use Carp;
use Config::General;
use Log::Log4perl;
use CIHM::Swift::Client;

use Try::Tiny;
use JSON;
use Data::Dumper;
use Switch;
use URI::Escape;

=head1 NAME

CIHM::Meta::Ocrtask - Process image exports from, and OCR data imports to, the Access platform databases and object storage.


=head1 SYNOPSIS

    my $ocrtask = CIHM::Meta::Omdtask->new($args);
      where $args is a hash of arguments.


=cut

our $self;

sub new {
    my ( $class, $args ) = @_;
    our $self = bless {}, $class;

    if ( ref($args) ne "HASH" ) {
        die "Argument to CIHM::Meta::Ocrtask->new() not a hash\n";
    }
    $self->{args} = $args;

    my %swiftopt = ( furl_options => { timeout => 3600 } );
    foreach ( "server", "user", "password", "account" ) {
        if ( exists $args->{ "swift_" . $_ } ) {
            $swiftopt{$_} = $args->{ "swift_" . $_ };
        }
    }
    $self->{swift} = CIHM::Swift::Client->new(%swiftopt);

    my $test = $self->swift->container_head( $self->access_metadata );
    if ( !$test || $test->code != 204 ) {
        die "Problem connecting to Swift container. Check configuration\n";
    }

    $self->{ocrtaskdb} = new restclient(
        server      => $args->{couchdb_ocrtask},
        type        => 'application/json',
        clientattrs => { timeout => 3600 },
    );
    $self->ocrtaskdb->set_persistent_header( 'Accept' => 'application/json' );
    $test = $self->ocrtaskdb->head("/");
    if ( !$test || $test->code != 200 ) {
        die "Problem connecting to Couchdb database. Check configuration\n";
    }

    return $self;
}

# Simple accessors for now -- Do I want to Moo?
sub args {
    my $self = shift;
    return $self->{args};
}

sub log {
    my $self = shift;
    return $self->args->{logger};
}

sub access_metadata {
    my $self = shift;
    return $self->args->{swift_access_metadata};
}

sub swift {
    my $self = shift;
    return $self->{swift};
}

sub ocrtaskdb {
    my $self = shift;
    return $self->{ocrtaskdb};
}

sub maxprocs {
    my $self = shift;
    return $self->args->{maxprocs};
}

sub task {
    my $self = shift;
    return $self->{task};
}

sub taskid {
    my $self = shift;
    return $self->task->{'_id'} if $self->task;
}

sub todo {
    my $self = shift;
    return $self->{todo};
}

sub clear_warnings {
    my $self = shift;
    $self->{warnings} = "";
}

sub warnings {
    my $self = shift;
    return $self->{warnings};
}

sub collect_warnings {
    my $warning = shift;
    our $self;
    my $taskid = "unknown";

    # Strip wide characters before  trying to log
    ( my $stripped = $warning ) =~ s/[^\x00-\x7f]//g;

    if ($self) {
        $self->{warnings} .= $warning;
        $self->log->warn( $self->taskid . ": $stripped" );
    }
    else {
        say STDERR "$warning\n";
    }
}

sub ocrtask {
    my ($self) = @_;

    $self->clear_warnings();

    # Capture warnings
    local $SIG{__WARN__} = sub { &collect_warnings };

    $self->log->info( "Ocrtask maxprocs=" . $self->maxprocs );

    $self->ocrtaskdb->type("application/json");
    my $url =
"/_design/access/_view/ocrQueue?reduce=false&descending=true&include_docs=true";
    my $res =
      $self->ocrtaskdb->get( $url, {}, { deserializer => 'application/json' } );
    if ( $res->code == 200 ) {
        if ( exists $res->data->{rows} ) {
            foreach my $task ( @{ $res->data->{rows} } ) {
                my $status;
                $self->clear_warnings();

                my $todo = shift @{ $task->{key} };
                $self->{todo} = $todo;
                $self->{task} = $task->{doc};

                # Handle and record any errors
                try {
                    $status = JSON::true;

                    if ( $todo eq 'export' ) {
                        $self->ocrExport();
                    }
                    else {
                        $self->ocrImport();
                    }
                }
                catch {
                    $status = JSON::false;
                    $self->log->error( $self->taskid . ": $_" );
                    $self->{warnings} .= "Caught: " . $_;
                };
                $self->postResults( $status, $self->warnings );
            }
        }
    }
    else {
        $self->log->error(
            "ocrtaskdb $url GET return code: " . $res->code . "\n" );
    }
}

sub ocrExport {
    my ($self) = @_;

    switch ( int( rand(3) ) ) {
        case 0 {
            return;
        }
        case 1 {
            warn "Just a little export warning.\n";
        }
        case 2 {
            die "Why this export failed.\n";
        }
    }
}

sub ocrImport {
    my ($self) = @_;

    switch ( int( rand(3) ) ) {
        case 0 {
            return;
        }
        case 1 {
            warn "Just a little import warning.\n";
        }
        case 2 {
            die "Why this import failed.\n";
        }
    }
}

sub postResults {
    my ( $self, $succeeded, $message ) = @_;

    my $which = ( $self->todo eq "export" ) ? "Export" : "Import";
    my $taskid = $self->taskid;

    my $url =
      "/_design/access/_update/updateOCR${which}/" . uri_escape_utf8($taskid);
    my $updatedoc = { succeeded => $succeeded, message => $message };

    my $res =
      $self->ocrtaskdb->post( $url, $updatedoc,
        { deserializer => 'application/json' } );

    if ( $res->code != 201 && $res->code != 200 ) {
        die "$url POST return code: " . $res->code . "\n";
    }
    if ( $res->data ) {
        if ( exists $res->data->{message} ) {
            $self->log->info( $taskid . ": " . $res->data->{message} );
        }
        if ( exists $res->data->{error} ) {
            $self->log->error( $taskid . ": " . $res->data->{error} );
        }
    }
}

{

    package restclient;

    use Moo;
    with 'Role::REST::Client';
}

1;
