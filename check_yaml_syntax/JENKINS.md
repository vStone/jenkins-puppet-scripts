# Warnings Plugin

You can use the following regex and groovy for the warnings plugin. Since
We are adding a prefix to the output to parse it more effectivly in case you
do syntax checks and other checks which produce similar output in one job.

You can obviously choose the name for the parser and the trend graph.

__Regular Expression:__
```
^YAML_SYNTAX:([^:]*):(ERROR):([0-9]+):(.*)$
```

__Mapping Script:__

```groovy
import hudson.plugins.warnings.parser.Warning
import hudson.plugins.analysis.util.model.Priority

String fileName = matcher.group(1)
String lineNumber = matcher.group(3)
String category = matcher.group(2)
String message = matcher.group(4)
Priority prio = Priority.HIGH

return new Warning(fileName, Integer.parseInt(lineNumber), "YAML Syntax", category, message, prio);
```


