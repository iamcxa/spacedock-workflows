# Selector Grammar Fixture

This pitch defines a selector grammar for internal agent lookups.

The decision is whether callers should express lookup targets as:

- `find role button --name Save`
- `{ role: "button", name: "Save" }`
- `role=button name=Save`

The plan needs a canonical grammar for role and name selectors before implementation chooses parser behavior.
