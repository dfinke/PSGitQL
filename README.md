# PSGitQL

A PowerShell git query language.

Inspired by [gitql](https://github.com/cloudson/gitql).

## Example Commands
* `Invoke-GitQuery 'select hash, author, message from commits limit 3'`
* `psgitql "select hash, message, authorEmail from commits where author = 'cloudson'"`
* `psgitql "select date, message from commits where date < '2014-04-10'"`

**Notes**:
* `PSGitQL` doesn't want to _replace_ `git log` - it was created for fun! :sweat_smile:
* It's read-only - no deleting, inserting, or updating tables or commits. :stuck_out_tongue_closed_eyes: