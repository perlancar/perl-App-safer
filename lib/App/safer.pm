package App::safer;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

sub _list_encodings {
    require Module::List::Tiny;

    my %args = @_;
    my $detail = $args{detail};

    my $modules = Module::List::Tiny::list_modules("Text::Safer::", {list_modules => 1, recurse=>1});
    my @res;
    my $resmeta = $detail ? {"table.fields" => [qw/encoding summary args/]} : {};
    for my $e (sort keys %$modules) {
        $e =~ s/^Text::Safer:://;
        if ($detail) {
            my $mod = "Text::Safer::$e";
            (my $mod_pm = "$mod.pm") =~ s!::!/!g;
            require $mod_pm;
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            my $meta = \%{"$mod\::META"};
            push @res, {
                encoding => $e,
                summary => $meta->{summary},
                args => join(", ", sort keys %{ $meta->{args} // {} }),
            };
        } else {
            push @res, $e;
        }
    }
    return [200, "OK", \@res, $resmeta];
}

my $num_l_specified = 0;

$SPEC{app} = {
    v => 1.1,
    summary => 'CLI for Text::Safer',
    args => {
        action => {
            schema => ['str*', in=>[qw/list-encodings encode/]],
            default => 'encode',
            cmdline_aliases => {
                a => {},
                l => {
                    is_flag => 1,
                    summary => 'Shortcut for --action=list-encodings, specify another -l for --detail listing',
                    code => sub {
                        $_[0]{action} = 'list-encodings';
                        if ($num_l_specified++) {
                            $_[0]{detail} = 1;
                        }
                    },
                },
            },
        },
        detail => {
            schema => 'bool*',
            summary => 'Show detail information in list',
        },
        encoding => {
            schema => 'str*',
            default => 'alphanum_kebab_nodashend_lc',
            cmdline_aliases => {e=>{}},
            completion => sub {
                require Complete::Util;

                my %args = @_;

                my $encres = _list_encodings(detail => 1);
                Complete::Util::complete_array_elem(
                    array     => [map { $_->{encoding} } @{ $encres->[2] }],
                    summaries => [map { $_->{summary}  } @{ $encres->[2] }],
                    word      => $args{word},
                );
            },
        },
        # TODO: encoding_args
        text => {
            schema => 'str*',
            pos => 0,
        },
    },
};
sub app {
    my %args = @_;

    my $action = $args{action} // 'encode';
    my $text = $args{text};
    my $encoding = $args{encoding} // 'alphanum_kebab_nodashend_lc';
    my $detail = $args{detail};

    if ($action eq 'list-encodings') {
        return _list_encodings(detail => $detail);
    }

    $text = do { local $/; scalar <> } unless defined $text;
    $text //= "";
    require Text::Safer;
    [200, "OK", Text::Safer::encode_safer($text, $encoding)];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

See L<safer> script.

=cut
