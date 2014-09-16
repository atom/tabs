{$, View} = require 'atom'
_ = require 'underscore-plus'
path = require 'path'

module.exports =
class TabView extends View
  @content: ->
    @li class: 'tab sortable', =>
      @div class: 'title', outlet: 'title'
      @div class: 'close-icon'

  initialize: (@item, @pane) ->
    @item.on? 'title-changed', =>
      @updateDataAttributes()
      @updateTitle()
      @updateTooltip()

    @item.on? 'icon-changed', =>
      @updateIcon()

    @item.on? 'modified-status-changed', =>
      @updateModifiedStatus()

    @subscribe atom.config.observe 'tabs.showIcons', => @updateIconVisibility()

    @updateDataAttributes()
    @updateTitle()
    @updateIcon()
    @updateModifiedStatus()

    # Defer creating the tooltip until the tab is moused over
    @one 'mouseenter', =>
      @hasBeenMousedOver = true
      @updateTooltip()
      @trigger 'mouseenter' # Trigger again so the tooltip shows

  updateTooltip: ->
    return unless @hasBeenMousedOver

    @destroyTooltip()

    if itemPath = @item.getPath?()
      @setTooltip
        title: _.escape(itemPath)
        delay:
          show: 2000
          hide: 100
        placement: 'bottom'

  beforeRemove: ->
    @destroyTooltip()

  updateDataAttributes: ->
    if itemPath = @item.getPath?()
      @title.element.dataset.name = path.basename(itemPath)
      @title.element.dataset.path = itemPath

  updateTitle: ({updateSiblings, useLongTitle}={}) ->
    return if @updatingTitle
    @updatingTitle = true

    if updateSiblings is false
      title = @item.getTitle()
      title = @item.getLongTitle?() ? title if useLongTitle
      @title.text(title)
    else
      title = @item.getTitle()
      useLongTitle = false
      for tab in @getSiblingTabs()
        if tab.item.getTitle() is title
          tab.updateTitle(updateSiblings: false, useLongTitle: true)
          useLongTitle = true
      title = @item.getLongTitle?() ? title if useLongTitle

      @title.text(title)

    @updatingTitle = false

  updateIcon: ->
    if @iconName
      @title.element.classList.remove('icon', "icon-#{@iconName}")

    if @iconName = @item.getIconName?()
      @title.element.classList.add('icon', "icon-#{@iconName}")

  getSiblingTabs: ->
    @siblings('.tab').views()

  updateIconVisibility: ->
    if atom.config.get 'tabs.showIcons'
      @title.element.classList.remove('hide-icon')
    else
      @title.element.classList.add('hide-icon')

  updateModifiedStatus: ->
    if @item.isModified?()
      @element.classList.add('modified') unless @isModified
      @isModified = true
    else
      @element.classList.remove('modified') if @isModified
      @isModified = false
