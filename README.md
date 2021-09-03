# 🚨 This repo has been archived 🚨 

This is no longer being used in production and hasn't been updated in quite some time. Please don't use it for anything real.

## Rakefile

Rake commands for command line deployment.  Basic usage:

``` 
# SVN/jenkins deploys

rake deploy APP=<app name> # defaults to trunk
rake deploy APP=<app name> BRANCH=<branch name>
rake deploy APP=<app name> TAG=<tag>

# Github/Travis-CI deploys
rake gdeploy APP=<app name> # defaults to master
rake gdeploy APP=<app name> BRANCH=<branch name>
rake gdeploy APP=<app name> TAG=<tag>

# Restarting
rake restart APP=<app name>
```

## ucb\_rails\_ci.rake

Automatically included in any project that wants to be deployed via
Github/Travis.  Basic tasks for prepping and precompiling a rails project.

Examples:

```bash
rake ci:setup   # any preliminary setup
rake ci:war     # Build a war file for JRuby deployment
```

## ci.rb

Simple scripts to supplement CI build.  This applies to jenkins only -- Travis
uses a different mechanism.

Usage:

```
ci.rb APP_NAME [--run-specs-false] [--compile-assets-flag]

--run-specs-flag        (defaults is true)
--compile-assets-flag   (defaults is true)
```

