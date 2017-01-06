fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

describe 'MRU List', ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage("tabs")

  describe ".activate()", ->
    it "has exactly one modal panel per pane", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1

      pane = atom.workspace.getActivePane()
      pane.splitRight()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 2

      pane = atom.workspace.getActivePane()
      pane.splitDown()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 3

      pane = atom.workspace.getActivePane()
      pane.close()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 2

      pane = atom.workspace.getActivePane()
      pane.close()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1

    it "Doesn't build list until activated for the first time", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

    it "Doesn't activate when a single pane item is open", ->
      pane = atom.workspace.getActivePane()
      atom.commands.dispatch(pane, 'pane:show-next-recently-used-item')
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

  describe "contents", ->
    pane = null

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open("sample.png")
      pane = atom.workspace.getActivePane()

    it "has one item per tab", ->
      if pane.onChooseNextMRUItem?
        expect(pane.getItems().length).toBe 2
        atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
        expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 2

    it "switches between two items", ->
      firstActiveItem = pane.getActiveItem()
      atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      secondActiveItem = pane.getActiveItem()
      expect(secondActiveItem).toNotBe(firstActiveItem)
      atom.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      thirdActiveItem = pane.getActiveItem()
      expect(thirdActiveItem).toBe(secondActiveItem)
      atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      atom.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      fourthActiveItem = pane.getActiveItem()
      expect(fourthActiveItem).toBe(firstActiveItem)

  describe "config", ->
    configKey = 'tabs.enableMruTabSwitching'
    dotAtomPath = null

    beforeEach ->
      dotAtomPath = temp.path('tabs-spec-mru-config')
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      atom.keymaps.configDirPath = dotAtomPath

    afterEach ->
      fs.removeSync(dotAtomPath)

    it "defaults on", ->
      expect(atom.config.get(configKey)).toBe(true)

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:show-next-recently-used-item')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab ^ctrl')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:move-active-item-to-top-of-stack')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:show-previous-recently-used-item')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab ^ctrl')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:move-active-item-to-top-of-stack')

    it "alters keybindings when disabled", ->
      atom.config.set(configKey, false)
      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('pane:show-next-item')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab ^ctrl')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('unset!')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('pane:show-previous-item')

      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab ^ctrl')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('unset!')
