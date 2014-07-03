_ = require 'underscore-plus'
TabBarView = require './tab-bar-view'

module.exports =
  configDefaults:
    showIcons: true
    tabScrolling: if process.platform == 'linux' then true else false
    tabScrollingDelay: 75

  activate: ->
    @paneSubscription = atom.workspaceView.eachPaneView (paneView) =>
      tabBarView = new TabBarView(paneView)
      @tabBarViews ?= []
      @tabBarViews.push(tabBarView)
      onPaneViewRemoved = (event, removedPaneView) =>
        return unless paneView is removedPaneView
        _.remove(@tabBarViews, tabBarView)
        atom.workspaceView.off('pane:removed', onPaneViewRemoved)
      atom.workspaceView.on('pane:removed', onPaneViewRemoved)
      tabBarView

  deactivate: ->
    @paneSubscription?.off()
    tabBarView.remove() for tabBarView in @tabBarViews ? []
