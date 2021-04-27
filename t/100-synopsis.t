#!raku

use Test;

use Tinky::DB;
use Red::Database;
use Red::Operators;
use Red;

# This is basically the synopsis code instrumented to
# function as a test

lives-ok {
    my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
    my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);
    my $*RED-COMMENT-SQL = True;

    Tinky::DB::Workflow.^create-table;
    Tinky::DB::State.^create-table;
    Tinky::DB::Transition.^create-table;
    Tinky::DB::Item.^create-table;


    model Ticket does Tinky::DB::Object {
        has Int $.id is serial;
        has Str $.ticket-number is unique = (^100000).pick.fmt("%08d");
        has Str $.owner is column;
    }

    Ticket.^create-table;

    my $workflow = Tinky::DB::Workflow.^create(name => 'ticket-workflow');

    my $state-new         = $workflow.states.create(name => 'new');
    my $state-open        = $workflow.states.create(name => 'open');
    my $state-rejected    = $workflow.states.create(name => 'rejected');
    my $state-in-progress = $workflow.states.create(name => 'in-progress');
    my $state-stalled     = $workflow.states.create(name => 'stalled');
    my $state-complete    = $workflow.states.create(name => 'complete');

    $workflow.initial-state = $state-new;
    $workflow.^save;

    my Bool $seen-entered = False;
    $state-rejected.enter-supply.act( -> $object { $seen-entered = True });

    my $open              = $workflow.transitions.create(name => 'open', from => $state-new, to => $state-open);
    my $reject-new        = $workflow.transitions.create(name => 'reject', from => $state-new, to => $state-rejected);
    my $reject-open       = $workflow.transitions.create(name => 'reject', from => $state-open, to => $state-rejected);
    my $reject-stalled    = $workflow.transitions.create(name => 'reject', from => $state-stalled, to => $state-rejected);
    my $stall-open        = $workflow.transitions.create(name => 'stall', from => $state-open, to => $state-stalled);
    my $stall-progress    = $workflow.transitions.create(name => 'stall', from => $state-in-progress, to => $state-stalled);

    my Bool $seen-transition-supply = False;

    $stall-progress.supply.act( -> $object { $seen-transition-supply = True });

    my $unstall           = $workflow.transitions.create(name => 'unstall', from-id => $state-stalled.id, to-id => $state-in-progress.id);

    my $take              = $workflow.transitions.create(name => 'take', from-id => $state-open.id, to-id => $state-in-progress.id);

    my $complete-open     = $workflow.transitions.create(name => 'complete', from-id => $state-open.id, to-id => $state-complete.id);
    my $complete-progress = $workflow.transitions.create(name => 'complete', from-id => $state-in-progress.id, to-id => $state-complete.id);

    my Int $transition-count = 0;

    $workflow.transition-supply.act(-> ($trans, $object) { isa-ok $trans, Tinky::Transition, "got a Transition"; isa-ok $object, Ticket, "got a Ticket"; ok $trans.to ~~ $object.state, "and the state is what we expected"; $transition-count++;  });

    my Bool $seen-final = False;

    $workflow.final-supply.act(-> ( $state, $object) { $seen-final = True });


    my $ticket-a = Ticket.^create(owner => "Operator A");

    $ticket-a.apply-workflow($workflow);

    $ticket-a.open;

    is $ticket-a.state, $state-open, "In state 'open'";

    $ticket-a.take;

    is $ticket-a.state, $state-in-progress, "In progress";

    is-deeply $ticket-a.next-states, [ $state-stalled, $state-complete ], "Next-states gives what expected";

    $ticket-a.state = $state-stalled;

    is $ticket-a.state, $state-stalled, "Stalled";

    $ticket-a.reject;

    is $ticket-a.state, $state-rejected, "Rejected";

    is $transition-count, 4, "saw the right number of transitions";
    ok $seen-transition-supply, "saw the event on stall transition";
    ok $seen-entered, "Saw an event on the entered supply";
    ok $seen-final, "Saw an event on the final supply";

}, "synopsis code runs ok";

done-testing;

# vim: expandtab shiftwidth=4 ft=raku
