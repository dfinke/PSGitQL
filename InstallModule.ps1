$fullPath = 'C:\Program Files\WindowsPowerShell\Modules\PSGitQL'

Robocopy . $fullPath /mir /XD .vscode .git examples /XF appveyor.yml .gitattributes .gitignore