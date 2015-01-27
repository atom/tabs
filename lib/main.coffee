_ = require 'underscore-plus'
TabBarView = require './tab-bar-view'

module.exports =
  config:
    showIcons:
      type: 'boolean'
      default: true
    hideTabBarWhenOnlyOneTabIsOpen:
      type: 'boolean'
      default: false
    tabScrolling:
      type: 'boolean'
      default: process.platform is 'linux'
    tabScrollingThreshold:
      type: 'integer'
      default: 120

  activate: ->
    @tabBarViews = []

    @paneSubscription = atom.workspace.observePanes (pane) =>
      tabBarView = new TabBarView(pane)

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView.element, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)

  deactivate: ->
    @paneSubscription.dispose()
    tabBarView.remove() for tabBarView in @tabBarViews
