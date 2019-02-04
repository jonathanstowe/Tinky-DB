use v6;

use Tinky;
use Red;

module Tinky::DB {

    model State { ... }

    role Object does Tinky::Object {
    }

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

        multi method find-transition(State:D $from, State:D $to) {
            self.transitions-for-state($from).first( { $_.to-id == $to.id });
        }

    }

    model State is Tinky::State is table('tinky_state') is rw {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Tinky::DB::Workflow', column => 'id', require => 'Tinky::DB');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Tinky::DB::Workflow', require => 'Tinky::DB');

        multi method ACCEPTS(State:D $state --> Bool ) {
            self.id == $state.id
        }

        my Supplier $enter-supplier;

        method !enter-supplier(--> Supplier ) {
            $enter-supplier //= Supplier.new;
        }

        method enter-supply( --> Supply ) {
            self!enter-supplier.Supply.grep( -> $ ( $s, $o ) { $s.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method enter(Object:D $object) {
            self!enter-supplier.emit([self, $object]);
        }

        my Supplier $leave-supplier;

        method !leave-supplier( --> Supplier ) {
            $leave-supplier //= Supplier.new;
        }

        method leave-supply( --> Supply ) {
            self!leave-supplier.Supply.grep( -> $ ( $s, $o ) { $s.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method leave(Object:D $object) {
            self!leave-supplier.emit([self, $object]);
        }
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

        my Supplier $supplier;

        method !supplier( --> Supplier ) {
            $supplier //= Supplier.new;
        }

        method supply( --> Supply ) {
            self!supplier.Supply.grep( -> $ ( $t, $o ) { $t.id == self.id } ).map( -> $ ($, $o) { $o } );
        }

        method applied(Object:D $object) {
            self.from.leave($object);
            self.to.enter($object);
            self!supplier.emit([ self, $object ]);
        }
    }

}

# vim: ft=perl6

