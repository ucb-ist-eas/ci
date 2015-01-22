Rakefile
========

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

ci.rake
=======

To be included in any project that wants to be deployed via Github/Travis.  Basic
tasks for prepping and precompiling a rails project.

ci.rb
=====

Simple scripts to supplement CI build.  This applies to jenkins only -- Travis
uses a different mechanism.

Usage:

```
ci.rb APP_NAME [--run-specs-false] [--compile-assets-flag]

--run-specs-flag        (defaults is true)
--compile-assets-flag   (defaults is true)
```

