module.exports =
  config:
    showIcons:
      type: 'boolean'
      default: true
    alwaysShowTabBar:
      type: 'boolean'
      default: true
      description: "Shows the Tab Bar when only 1 tab is open"
    tabScrolling:
      type: 'boolean'
      default: process.platform is 'linux'
    tabScrollingThreshold:
      type: 'integer'
      default: 120
    usePreviewTabs:
      type: 'boolean'
      default: false
      description: 'Tabs will only stay open if they are modified or double-clicked'
    enableVcsColoring:
      title: "Enable VCS Coloring"
      type: 'boolean'
      default: false

  activate: (state) ->
    state = [] unless Array.isArray(state)
    @tabBarViews = []

    TabBarView = require './tab-bar-view'
    _ = require 'underscore-plus'

    @paneSubscription = atom.workspace.observePanes (pane) =>
      tabBarView = new TabBarView
      tabBarView.initialize(pane, state.shift())

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)

    state = [] # Reset state so it only affects the initial panes observed

  deactivate: ->
    @paneSubscription.dispose()
    tabBarView.remove() for tabBarView in @tabBarViews
    return

  serialize: ->
    @tabBarViews.map (tabBarView) ->
      previewTabURI: tabBarView.getPreviewTabURI()
