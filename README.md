# Tabs package
[![OS X Build Status](https://travis-ci.org/atom/tabs.svg?branch=master)](https://travis-ci.org/atom/tabs) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/nf4hdmuk4i9xkfmb/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/tabs/branch/master) [![Dependency Status](https://david-dm.org/atom/tabs.svg)](https://david-dm.org/atom/tabs)

Display selectable tabs above the editor.

![](https://cloud.githubusercontent.com/assets/18362/10862852/c6de2de0-800d-11e5-8158-284f30aaf5d2.png)

## API

Tabs can display icons next to file names. These icons are customizable by installing a package that provides an `atom.file-icons` service.

The `atom.file-icons` service must provide the following methods:

* `iconClassForPath(path)` - Returns a CSS class name to add to the tab view
