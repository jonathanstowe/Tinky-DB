#!raku

use v6;

use Test;

use Tinky::DB;
use Red::Database;
use Red::Operators;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Tinky::DB::Workflow.^create-table }, "create workflow table";
lives-ok { Tinky::DB::State.^create-table    }, "create state table";;
lives-ok { Tinky::DB::Transition.^create-table }, "create transition table";
lives-ok { Tinky::DB::Item.^create-table }, "create item table";


my Tinky::DB::Workflow $wf = Tinky::DB::Workflow.^create(name => "test-workflow");

my @states = <one two three four>.map({ $wf.states.create(name => $_) });

my @transitions = @states.rotor(2 => -1).map(-> ($from, $to) { my $name = $from.name ~ '-' ~ $to.name; $wf.transitions.create(:$from, :$to, :$name) });

$wf.initial-state = @states[0];
$wf.^save;

model FooTest does Tinky::DB::Object {
    has Int $.id is serial;
    has Str $.blob is column = 'Blob';
}

FooTest.^create-table;


is $wf.transitions.elems, @transitions.elems, "and got the right number of transitions";
is $wf.states.elems, @states.elems, "and calculated the right number of states";

for @states[0 .. 2] -> $state {
    is $wf.transitions-for-state($state).elems, 1, "got a transition for State '{ $state.name }'";
    ok $wf.transitions-for-state($state)[0].from ~~ $state, "and it is the the transition we expected";
}

for @states.rotor(2 => -1) -> ($from, $to) {
    ok $wf.find-transition($from, $to), "find-transition '{ $from.name }' -> '{ $to.name }'";
}

my $obj = FooTest.^create;

throws-like { $obj.transitions }, Tinky::X::NoWorkflow, "'transitions' throws without workflow";
throws-like { $obj.transition-for-state(@states[0]) }, Tinky::X::NoWorkflow, "'transition-for-state' throws without workflow";

lives-ok { $obj.apply-workflow($wf) }, "apply workflow";

ok my $item = Tinky::DB::Item.^load(workflow-id => $wf.id, object-id => $obj.id, object-class => 'FooTest'), 'get the item for the object';

is $obj.transitions.elems, 1, "got one transition for current state";
ok $obj.transition-for-state(@states[1]).defined, "and there is a transition for the next state";
nok $obj.transition-for-state(@states[2]).defined, "and there is no transition for the another state";
nok $obj.transition-for-state(@states[3]).defined, "and there is no transition for the another another state";

for @transitions -> $trans {
    can-ok $obj, $trans.name, "Object has '{ $trans.name }' method";
    for @transitions.grep({ $_.name ne $trans.name }) -> $no-trans {
        throws-like { $obj."{ $no-trans.name }"() }, Tinky::X::InvalidTransition, "'{ $no-trans.name }' method throws";
    }
    lives-ok { $obj."{ $trans.name }"() }, "'{ $trans.name }' method works";
    is $obj.state, $trans.to, "and it got changed to the '{ $trans.to.name }' state";
}

$obj = FooTest.^create();
$obj.apply-workflow($wf);

for @states.grep( -> $s { $s.id != $obj.state.id }) -> $state {
    lives-ok { $obj.state = $state }, "set state to '{ $state.name }' by assigning to current-state";
    ok $obj.state ~~ $state , "and it is the expected state";
    ok my $item = Tinky::DB::Item.^load(workflow-id => $wf.id, object-id => $obj.id, object-class => 'FooTest'), 'get the item for the object';
    is $item.state-id, $state.id, "and the item got updated";
    ok my $saved-obj = FooTest.^load(id => $obj.id), "retrieve the object from the DB";
    lives-ok {
        $saved-obj.apply-workflow($wf);
    }, "apply workflow to the retrieved object";
    is $saved-obj.state.id, $state.id, "and the state is as expected";
}

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
