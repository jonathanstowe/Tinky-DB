use v6;


module Tinky::DB {

    use Tinky;
    use Red;

    model Workflow is Tinky::Workflow  {
        has Int $.id            is serial;
        has Str $.name          is column(:unique);
        has     @.states        is relationship({ .workflow-id }, model => 'State' );
        has     @.transitions   is relationship({ .workflow-id }. model => 'Transition' );
    }

    model State is Tinky::State {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Workflow', column => 'id');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Workflow');
    }

    model Transition is Tinky::Transition {
        has Int $.id            is serial;
        has Str $.name          is column;
        has Int $.workflow-id   is referencing(model => 'Workflow', column => 'id');
        has     $.workflow      is relationship({ .workflow-id }, model => 'Workflow');
        has Int $.from-id       is referencing(model => 'State', column => 'id');
        has     $.from          is relationship({  .from-id }, model => 'State' );
        has Int $.to-id         is referencing(model => 'State', column => 'id');
        has     $.to            is relationship({  .to-id }, model => 'State' );

    }

}

# vim: ft=perl6

