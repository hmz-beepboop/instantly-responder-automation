# Local Runtime Suppression-Metadata Fix

The local runtime acceptance script iterated every property under
`config.suppression_action_enablement` and cast each value to Boolean.

That object also contains a descriptive `note` string. In PowerShell, a
non-empty string casts to `True`, so the script incorrectly reported the
metadata field as an enabled suppression action.

The corrected validation:

- checks only the four required suppression controls;
- requires each control to exist;
- requires each value to be a real Boolean;
- requires each value to be `false`;
- ignores descriptive metadata such as `note`.

No workflow, credential, configuration value, API contract, or runtime
behaviour was changed.
