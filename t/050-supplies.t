#!raku

use v6;

use Test;

use Tinky::DB;
use Red::Database;
use Red::Operators;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);
my $*RED-COMMENT-SQL = True;

Tinky::DB::Workflow.^create-table;
Tinky::DB::State.^create-table;
Tinky::DB::Transition.^create-table;
Tinky::DB::Item.^create-table;


my $workflow = Tinky::DB::Workflow.^create( name => "test_worflow");

my @states = <one two three four>.map({ $workflow.states.create(name => $_) });

$workflow.initial-state = @states[0];
$workflow.^save;

for @states -> $state {
    $state.enter-supply.tap({does-ok $_, Tinky::DB::Object, "got an Object from enter supply"; });
    $state.leave-supply.tap({ does-ok $_, Tinky::DB::Object, "got an Object from leave supply" });
}

my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; $workflow.transitions.create(:$from, :$to, :$name) });

model FooTest does Tinky::DB::Object {
    has Int $.id is serial;
}

FooTest.^create-table;

throws-like { Tinky::Workflow.new.states }, Tinky::X::NoTransitions, ".states throws if there aren't any transitions";

my Int $applied = 0;

lives-ok { $workflow.applied-supply.act(-> $obj { does-ok $obj, Tinky::DB::Object, "applied-supply got a Tinky::Object"; $applied++ }) }, "tap the workflow applied-supply";


my @enter;
my @leave;
my @trans-events;
my Bool $final = False;

my $obj = FooTest.^create();
$obj.apply-workflow($workflow);

lives-ok { $workflow.enter-supply.act( -> $ ( $state, $object) { @enter.push($state.name); }) }, "set up tap on enter-supply";
lives-ok { $workflow.enter-supply.act( -> $ ( $state, $object) {isa-ok $state, Tinky::State }) }, "set up tap on enter-supply";
lives-ok { $workflow.leave-supply.act( -> $ ( $state, $object) { @leave.push($state.name); }) }, "set up tap on leave-supply";
lives-ok { $workflow.leave-supply.act(-> $ ( $state, $obj ) { isa-ok $state, Tinky::State } ) }, "set up tap on leave-supply";
lives-ok { $workflow.transition-supply.act( -> $ ( $transition, $object ) { isa-ok $transition, Tinky::Transition; does-ok $object, Tinky::DB::Object; @trans-events.push($transition.name) } ) }, "set up tap on transition-supply";
lives-ok { $workflow.final-supply.act( -> $ ( $state, $object ) { isa-ok $state, Tinky::State; does-ok $object, Tinky::DB::Object; is $workflow.transitions-for-state($state).elems, 0, "really is a final state"; $final = True } ) }, "set up tap on final-supply";

for @states -> $state {
    my $old-state = $obj.state;
    lives-ok { $obj.state = $state }, "set state to '{ $state.name }' by assigning to current-state";
    ok $obj.state ~~ $state , "and it is the expected state";
}

is-deeply @enter, [<two three four>], "got the right enter events";
is-deeply @leave, [<one two three>], "got the right leave events";
is-deeply @trans-events, [ <one-two two-three three-four> ], "got the right transition events";

ok $final, "and got the final event";
is $applied, 1, "and we saw the application of the workflow";

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
