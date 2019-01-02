use v6;

use Tinky;
use Red;

module Tinky::DB {

    model State { ... }
    model Workflow is Tinky::Workflow is table('tinky_workflow') is rw {
        has Int $.id                is serial;
        has Str $.name              is column(:unique);
        has Int $.initial-state-id  is referencing(column => 'id', model => 'Tinky::DB::State', require => 'Tinky::DB');
        has     $.initial-state     is relationship({ .initial-state-id }, model => 'Tinky::DB::State', require => 'Tinky::DB');
        has     @.states            is relationship({ .workflow-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );
        has     @.transitions       is relationship({ .workflow-id }, model => 'Tinky::DB::Transition', require => 'Tinky::DB' );

        method transitions-for-state(State:D $state ) {
            self.transitions.grep(*.from-id == $state.id);
        }
    }

    model State is Tinky::State is table('tinky_state') is rw {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Tinky::DB::Workflow', column => 'id', require => 'Tinky::DB');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Tinky::DB::Workflow', require => 'Tinky::DB');
    }

    model Transition is Tinky::Transition is table('tinky_transition') is rw {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Tinky::DB::Workflow', column => 'id', require => 'Tinky::DB');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Tinky::DB::Workflow', require => 'Tinky::DB');
        has Int $.from-id       is referencing(model => 'Tinky::DB::State', column => 'id', require => 'Tinky::DB');
        has     $.from          is relationship({  .from-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );
        has Int $.to-id         is referencing(model => 'Tinky::DB::State', column => 'id', require => 'Tinky::DB');
        has     $.to            is relationship({  .to-id }, model => 'Tinky::DB::State', require => 'Tinky::DB' );

        multi method ACCEPTS(Transition:D $transition --> Bool ) {
            self.id == $transition.id
        }

    }

    role Object does Tinky::Object {

    }
}

# vim: ft=perl6

