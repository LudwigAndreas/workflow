## Purpose
<!-- NEW capabilities only: one or two sentences (50+ characters) on what this
     capability is for. DELETE this section entirely for an existing
     capability - a delta's Purpose is ignored there. -->

## ADDED Requirements

### Requirement: <!-- requirement name -->
<!-- The system SHALL ... Use SHALL/MUST. Avoid should/may - a tester cannot
     verify a "may". Stay at business altitude: rules a user, a customer or
     another organisation can observe, and rules more than one repository must
     agree on. Never a class, function, library or file. -->

#### Scenario: <!-- happy path name -->
- **WHEN** <!-- a concrete, externally triggerable event -->
- **THEN** <!-- something observable from outside the system -->

#### Scenario: <!-- unhappy path name -->
<!-- Cover invalid input, expired/missing credentials, absent permissions,
     empty collections, duplicate submissions, dependency down. An intent whose
     scenarios are all happy-path is not ready for review. -->
- **WHEN** <!-- condition -->
- **THEN** <!-- observable outcome -->

<!-- Use exactly four hashtags for scenarios. Three, or a bullet list, parses
     as nothing at all and fails silently. -->

<!-- For MODIFIED Requirements: copy the ENTIRE existing requirement block from
     openspec/specs/<capability>/spec.md, including every scenario, then edit.
     A partial copy silently deletes the scenarios you left out at archive time.

## MODIFIED Requirements

### Requirement: <existing name, matching exactly>
...

     For REMOVED Requirements, include **Reason** and **Migration**. -->
