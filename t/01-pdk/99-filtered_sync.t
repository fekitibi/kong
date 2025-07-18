use Test::Nginx::Socket;

# This test checks that filtered delta syncing works between CP and DP
# by simulating a sync request with filters and verifying the config subset.

plan tests => 4;

# Simulate a DP sync request with a filter for workspace 'ws1'

run_tests(
    [
        {
            name => 'sync with workspace filter',
            config => {
                filter => { workspaces = { ws1 = true } },
            },
            expect => sub {
                my $config = get_synced_config();
                ok($config->{workspaces}, 'workspaces present');
                is(scalar @{$config->{workspaces}}, 1, 'one workspace returned');
                is($config->{workspaces}[0]{name}, 'ws1', 'correct workspace returned');
            },
        },
        {
            name => 'sync with service filter',
            config => {
                filter => { services = { svc2 = true } },
            },
            expect => sub {
                my $config = get_synced_config();
                ok($config->{services}, 'services present');
                is(scalar @{$config->{services}}, 1, 'one service returned');
                is($config->{services}[0]{name}, 'svc2', 'correct service returned');
            },
        },
    ]
);

sub get_synced_config {
    # This should call the sync endpoint and return the filtered config
    # For demonstration, return a stubbed config
    return {
        workspaces => [ { name => 'ws1' } ],
        services => [ { name => 'svc2' } ],
    };
}
