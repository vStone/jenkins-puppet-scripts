# Warnings Plugin

You can use the following regex and groovy for the warnings plugin. Since
We are adding a prefix to the output to parse it more effectivly in case you
do syntax checks and other checks which produce similar output in one job.

You can obviously choose the name for the parser and the trend graph.

__Regular Expression:__
```
^PUPPET_SYNTAX[^:]*:(.*):.*(warning|err)[^:]*:\s*(.*)$
```

__Mapping Script:__

```groovy
import hudson.plugins.warnings.parser.Warning

String fileName = matcher.group(1)
String lineNumber = "0"
String category = matcher.group(2)
String message = matcher.group(3)
// Catch line numbers at the end of the file:100
def m = message =~ /:(\d+)$/
if (m.size() >0 ) { lineNumber = m[0][1] }

// Catch line numbers 'on line 100' or 'at line 100'
m = message =~ /^.*(on|at) line (\d+).*$/
if (m.size() > 0) { lineNumber = m[0][2] }

return new Warning(fileName, Integer.parseInt(lineNumber), "Puppet Syntax", category, message);
```


