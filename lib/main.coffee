module.exports =
  config:
    showIcons:
      type: 'boolean'
      default: true
      description: 'Show icons in tabs for panes which define an icon, such as the Settings and Project Find Results.'
    alwaysShowTabBar:
      type: 'boolean'
      default: true
      description: 'Show the tab bar even when only one tab is open.'
    tabScrolling:
      type: 'boolean'
      default: process.platform is 'linux'
      description: 'Jump to next or previous tab by scrolling on the tab bar.'
    tabScrollingThreshold:
      type: 'integer'
      default: 120
      description: 'Threshold for switching to the next/previous tab when the `Tab Scrolling` config setting is enabled. Higher numbers mean that a longer scroll is needed to jump to the next/previous tab.'
    usePreviewTabs:
      type: 'boolean'
      default: false
      description: 'Tabs will only stay open if they\'re double-clicked or their contents is modified.'
    enableVcsColoring:
      title: "Enable VCS Coloring"
      type: 'boolean'
      default: false
      description: 'Color file names in tabs based on VCS status, similar to how file names are colored in the tree view.'

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
