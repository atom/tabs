# Tabs package [![Build Status](https://travis-ci.org/atom/tabs.svg?branch=master)](https://travis-ci.org/atom/tabs)

Display selectable tabs above the editor.

![](https://cloud.githubusercontent.com/assets/18362/10862852/c6de2de0-800d-11e5-8158-284f30aaf5d2.png)

## API

Tabs can display icons next to file names. These icons are customizable by installing a package that provides an `atom.file-icons` service.

The `atom.file-icons` service must provide the following methods:

* `iconClassForPath(path)` - Returns a CSS class name to add to the tab view
* `onWillDeactivate` - An event that lets the tabs return to their default icon strategy
